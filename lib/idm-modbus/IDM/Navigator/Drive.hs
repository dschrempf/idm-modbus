{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}

-- |
-- Module      :  IDM.Navigator.Drive
-- Description :  Writing after every round what a step decides, and final values on every exit
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- The part of a driver that every driver shares, whatever decides the
-- values. Round after round, 'drive' reads what the needs and the step name,
-- in one session, hands the step its reads, and writes the commands it
-- answers with; and on every exit, the step's own end or an exception, it
-- writes the final values, which nothing thrown once they began stops. The
-- step is where a strategy goes, so this module holds none.
--
-- A command goes to a free target only, so a loop that renews its values
-- cannot wear out an EEPROM register. It goes out on the round's session,
-- and only where that session runs the software the table describes;
-- otherwise it is skipped, and nothing is sent. Other software comes with an
-- update, which restarts the controller and resets 74 to 0 and 4108 to -1
-- (@doc\/verification\/2026-11-07-restart.md@).
--
-- Nothing here prints, and nothing installs a signal handler: a signal
-- reaches a drive as the exception its handler throws, and the program that
-- installs the handler decides which.
module IDM.Navigator.Drive
  ( -- * What a drive writes
    Command (..),
    DriveOn (..),
    Drive,

    -- * What it reports
    DriveEventOn (..),
    DriveEvent,
    SkipReason (..),
    Finish (..),

    -- * Driving
    DriveRequests (..),
    sessionDriveRequests,
    driveWith,
    drive,
  )
where

import Control.Concurrent (threadDelay)
import Control.Exception (SomeException, displayException, mask, throwIO, try)
import Control.Monad (void)
import Data.IORef (modifyIORef', newIORef, readIORef, writeIORef)
import qualified Data.Text as T
import IDM.Modbus.TCP (Ending (..), Failure (..))
import IDM.Navigator.Client (Session, writable)
import IDM.Navigator.Register (Cost (..), Register, Value)
import IDM.Navigator.Rounds
import IDM.Navigator.Target (Target)
import IDM.Navigator.Write (Confirmation (..), Outcome (..), write)

-- | A write the loop may repeat.
data Command = Command (Target 'Free) Value
  deriving (Show, Eq)

-- | A driver, on sessions of type @s@, whose step ends for reasons of type
-- @r@.
data DriveOn s r = Drive
  { -- | read every round, beside what the needs name
    driveRegisters :: [Register],
    -- | what to write after a round, handed the reads of 'driveRegisters'
    -- only; 'Left' ends the drive, for the step's own reason
    driveStep :: RoundOn s -> IO (Either r [Command]),
    -- | written in this order on every exit
    driveFinal :: [Command]
  }

type Drive r = DriveOn Session r

-- | What a drive reports as it goes.
data DriveEventOn s
  = -- | a read, or a session's opening, failed opening or loss; also those
    -- of the finals, which open a session where none is
    RoundEvent (RoundEventOn s)
  | Wrote Command (Outcome 'Free)
  | -- | nothing was sent
    Skipped Command SkipReason
  | -- | the finals begin; their writes follow as 'Wrote' or 'Skipped'
    Finals

type DriveEvent = DriveEventOn Session

-- | Why a command was not sent.
data SkipReason
  = -- | none was open, or the write before it ended the one there was
    NoSession
  | -- | the session runs other software than the table describes
    SoftwareDiffers
  deriving (Show, Eq)

-- | How a drive ended: its step's reason, or an exception, a signal's among
-- them. The finals have gone out either way.
data Finish r
  = Finished r
  | -- | thrown before the finals, or, where the step had ended the drive,
    -- the first exception thrown in them
    Interrupted SomeException
  deriving (Show)

-- | The requests a drive is made of, beside a round's.
data DriveRequests s = DriveRequests
  { driveRoundRequests :: RoundRequests IO s,
    -- | the write on a session that runs the software the table describes,
    -- and 'Nothing' on one that runs other software
    writerOn :: s -> Maybe (Command -> IO (Outcome 'Free)),
    -- | seconds
    sleepFor :: Double -> IO ()
  }

-- | The requests of a drive on the controller, a session made by the action
-- given: a write through 'write', where 'writable' gives a
-- 'IDM.Navigator.Client.Writable'.
sessionDriveRequests :: IO Session -> DriveRequests Session
sessionDriveRequests opening =
  DriveRequests
    { driveRoundRequests = sessionRequests opening,
      writerOn = \s -> either (const Nothing) (\w -> Just (\(Command t v) -> write w t v)) (writable s),
      sleepFor = \t -> threadDelay (round (t * 1e6))
    }

-- | 'driveWith' on the controller.
drive :: IO Session -> (DriveEvent -> IO ()) -> Period -> [Need] -> Drive r -> IO (Finish r)
drive = driveWith . sessionDriveRequests

-- | Round after round, every period, read the union of what the needs and
-- the step name, hand each its reads, and write what the step answers, in
-- the order it answers, on the session the round ended with. The first round
-- begins at once; a round that overran its period starts the next at once.
--
-- A write whose failure ended the connection closes the session, as a read
-- does, and the commands after it are skipped; the next round opens a new
-- one.
--
-- The finals go out on every exit, as in 'Control.Exception.finally': under
-- the ordinary mask, which an operation that blocks still interrupts, so
-- that the timeout of every request still works. Where no session is open,
-- the finals open one, up to three times, 10 s apart. A final whose write
-- ended the connection goes again on the next session, within those three.
-- The session open at the end is closed.
--
-- Once begun, the finals go on whatever is thrown in them. A write, an
-- opening, a pause or a close that throws, as where a signal's exception
-- lands in a wait for an answer, counts as the session lost: it is
-- 'Dropped' as 'Abandoned' and closed, and the final goes again, within the
-- three openings. An opening that throws is a failed one. A 'report' that
-- throws is passed over. After the finals, the first exception a 'report'
-- threw is thrown again; otherwise the first other one turns a 'Finished'
-- into 'Interrupted'. An exception thrown to the drive while a 'report'
-- blocks, as a signal's where stdout is a full pipe, is the report's
-- failure: it is thrown again rather than returned.
driveWith :: DriveRequests s -> (DriveEventOn s -> IO ()) -> Period -> [NeedOn s] -> DriveOn s r -> IO (Finish r)
driveWith rq report (Period seconds) needs d = do
  held <- newIORef Nothing
  reportFailed <- newIORef (Nothing :: Maybe SomeException)
  thrown <- newIORef Nothing
  let track e = case e of
        Opened s -> writeIORef held (Just s)
        Dropped _ -> writeIORef held Nothing
        _ -> pure ()
      roundReport e = track e >> report (RoundEvent e)
      skip why c = report (Skipped c why)
      lose s why = roundReport (Dropped why) >> closeSession rr s
      go due = do
        now <- monotonicClock rr
        sleepFor rq (max 0 (due - now))
        r <- readIORef held >>= \s -> readRound rr roundReport s regs
        mapM_ (handOver r) needs
        stepped <- driveStep d (restrict (driveRegisters d) r)
        case stepped of
          Left why -> pure why
          Right cs -> do
            readIORef held >>= commands cs
            next <- monotonicClock rr
            go (max (due + fromIntegral seconds) next)
      commands cs held' = case held' of
        Nothing -> mapM_ (skip NoSession) cs
        Just s -> case writerOn rq s of
          Nothing -> mapM_ (skip SoftwareDiffers) cs
          Just w -> sending s w cs
      sending _ _ [] = pure ()
      sending s w (c : cs) = do
        o <- w c
        report (Wrote c o)
        case ending o of
          Just why -> lose s why >> mapM_ (skip NoSession) cs
          Nothing -> pauseAfter rr s >> sending s w cs
      -- In the finals: what is thrown is kept, the first of each kind, and
      -- not let through.
      keepFirst ref e = modifyIORef' ref (maybe (Just e) Just)
      guarded :: IO a -> IO (Either SomeException a)
      guarded act = try act >>= \r -> r <$ either (keepFirst thrown) (const (pure ())) r
      told e = try (report e) >>= either (keepFirst reportFailed) pure
      toldRound e = track e >> told (RoundEvent e)
      abandon s why = toldRound (Dropped why) >> void (guarded (closeSession rr s))
      finals = do
        told Finals
        final tries (driveFinal d)
        readIORef held >>= mapM_ (\s -> guarded (closeSession rr s) >> writeIORef held Nothing)
      final _ [] = pure ()
      final left cs@(c : rest) =
        readIORef held >>= \held' -> case held' of
          Just s -> case writerOn rq s of
            Nothing -> mapM_ (told . (`Skipped` SoftwareDiffers)) cs
            Just w ->
              guarded (w c) >>= \written -> case written of
                Left _ -> abandon s Abandoned >> final left cs
                Right o -> do
                  told (Wrote c o)
                  case ending o of
                    Just why -> abandon s why >> final left cs
                    Nothing ->
                      guarded (pauseAfter rr s) >>= \paused -> case paused of
                        Left _ -> abandon s Abandoned >> final left rest
                        Right () -> final left rest
          Nothing
            | left <= 0 -> mapM_ (told . (`Skipped` NoSession)) cs
            | otherwise -> reopen left True >>= \left' -> final left' cs
      -- the tries left after opening one, or after the last failed
      reopen left firstTry
        | left <= 0 = pure 0
        | otherwise = do
            if firstTry then pure () else void (guarded (sleepFor rq apart))
            guarded (openSession rr) >>= \opened -> case opened of
              Right (Right s) -> (left - 1) <$ toldRound (Opened s)
              Right (Left why) -> toldRound (NotOpened why) >> reopen (left - 1) False
              Left e -> toldRound (NotOpened (T.pack (displayException e))) >> reopen (left - 1) False
  mask $ \restore -> do
    ended <- try (restore (monotonicClock rr >>= go))
    finals
    readIORef reportFailed >>= mapM_ throwIO
    inFinals <- readIORef thrown
    pure $ case (ended, inFinals) of
      (Left e, _) -> Interrupted e
      (Right _, Just e) -> Interrupted e
      (Right r, Nothing) -> Finished r
  where
    rr = driveRoundRequests rq
    regs = needed (needs <> [need (driveRegisters d) (const (pure ()))])
    tries = 3 :: Int
    apart = 10

-- | Why the connection ended, where a write's failure ended it.
ending :: Outcome 'Free -> Maybe Ending
ending o = case o of
  Failed f -> lost f
  Sent (ReadBackFailed f) -> lost f
  _ -> Nothing
  where
    lost f = case f of
      Ended why -> Just why
      Unsent why -> Just why
      _ -> Nothing
