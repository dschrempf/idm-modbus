{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}

-- |
-- Module      :  Main
-- Description :  Run a schedule of writes to 74, 88 and 4108, and record what the controller did
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
module Main (main) where

import Control.Concurrent (ThreadId, myThreadId, throwTo)
import Control.Concurrent.MVar (newMVar, withMVar)
import Control.Exception (Exception, IOException, displayException, fromException, try)
import Control.Monad (void)
import qualified Data.ByteString as B
import Data.Char (isAscii, isControl, ord)
import Data.IORef (atomicModifyIORef', newIORef, readIORef, writeIORef)
import Data.List (find, intercalate)
import qualified Data.List.NonEmpty as NE
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (ZonedTime, getZonedTime)
import Data.Word (Word16)
import GHC.Clock (getMonotonicTime)
import IDM.Modbus.TCP
import IDM.Navigator.Capture
import IDM.Navigator.Client (Answer (..), Sample (..), defaultPoll, open, sessionSoftware, writable)
import IDM.Navigator.Drive (Command (..), DriveEvent, DriveEventOn (RoundEvent, Skipped, Wrote), DriveOn (..), Finish (..), SkipReason (..), drive)
import qualified IDM.Navigator.Drive as Drive
import IDM.Navigator.Register
import IDM.Navigator.Rounds
import IDM.Navigator.Schedule
import IDM.Navigator.Schedule.Parse (parseSchedule)
import IDM.Navigator.Schedule.Step
import qualified IDM.Navigator.Table as Table
import IDM.Navigator.Target (Target, targetRegister)
import IDM.Navigator.Write (Confirmation (..), Outcome (..))
import Numeric (showHex)
import System.Environment (getArgs, getProgName)
import System.Exit (ExitCode (..), exitFailure, exitWith)
import System.IO (BufferMode (..), hPutStrLn, hSetBuffering, stderr, stdout)
import System.Posix.Process (getProcessID)
import System.Posix.Signals (Handler (..), Signal, installHandler, sigINT, sigTERM)

main :: IO ()
main = do
  args <- getArgs
  case args of
    ["--check", path] -> readSchedule path >>= check . snd
    [host, path] | take 1 host /= "-" -> readSchedule path >>= run host path
    _ -> usage

usage :: IO ()
usage = do
  name <- getProgName
  putStrLn $ "usage: " <> name <> " HOST SCHEDULE"
  putStrLn $ "       " <> name <> " --check SCHEDULE"
  putStrLn ""
  putStrLn "  Runs the schedule, a TOML file such as those in schedules/, on"
  putStrLn "  the controller at HOST: every round it reads the registers the"
  putStrLn "  schedule watches and 1100 and 4122, and writes what the current"
  putStrLn "  phase says to 74, 88 and 4108. On every exit, the end of the"
  putStrLn "  schedule, the compressor's stop, SIGINT, SIGTERM or an error, it"
  putStrLn "  writes the schedule's final values, to 88, 4108 and 74 in this"
  putStrLn "  order. It writes nothing unless the controller runs the software"
  putStrLn "  the table describes, data/navigator-10-software.tsv."
  putStrLn "  It prints one JSONL stream: a line per read, as idm-dump --watch"
  putStrLn "  prints it, and a line per event, with an \"event\" field. The"
  putStrLn "  first event names the pid to send SIGTERM to."
  putStrLn "  --check reads the schedule and prints its phases, and connects"
  putStrLn "  to nothing."
  exitFailure

-- | The file as read, and the schedule it holds; or the reasons it holds
-- none, on stderr, and exit.
readSchedule :: FilePath -> IO (T.Text, Schedule)
readSchedule path = do
  bytes <- B.readFile path
  text <- either (const (failWith [path <> ": not UTF-8"])) pure (TE.decodeUtf8' bytes)
  either (failWith . map ((path <> ": ") <>)) (pure . (,) text) (parseSchedule text)
  where
    failWith es = mapM_ (hPutStrLn stderr) es >> exitFailure

check :: Schedule -> IO ()
check s = do
  let Period r = scheduleRound s
  putStrLn ("round = " <> show r)
  putStrLn ("watch = " <> unwords [show a | Address a <- map registerAddress (scheduleWatch s)])
  putStrLn ("final, in this order: " <> intercalate ", " [address t <> " = " <> value v | Command t v <- finalCommands (scheduleFinal s)])
  mapM_
    (\(i, p) -> putStrLn ("phase " <> show i <> ": " <> intercalate ", " [k <> " = " <> v | (k, v) <- phaseKeys p]))
    (zip [0 :: Int ..] (NE.toList (schedulePhases s)))

-- | A phase's keys, as the file names them, and their values, each written
-- as TOML and JSON both write it.
phaseKeys :: Phase -> [(String, String)]
phaseKeys p =
  surplus
    <> [("every", show n) | Just (Seconds n) <- [phaseEvery p]]
    <> [("target", number x) | Just x <- [phaseTarget p]]
    <> [("limit", number x) | Just x <- [phaseLimit p]]
    <> [end]
  where
    surplus = case phaseSurplus p of
      Constant x -> [("surplus", number x)]
      Export pv (Bounds lo hi) ->
        ("pv", number pv) : [("min", number x) | Just x <- [lo]] <> [("max", number x) | Just x <- [hi]]
    end = case phaseEnd p of
      AtStart -> ("until", quote "start")
      AtStop -> ("until", quote "stop")
      AfterStart (Seconds n) -> ("after-start", show n)
      For (Seconds n) -> ("for", show n)

-- | The signal that interrupted a drive.
newtype Interruption = Interruption Signal
  deriving (Show)

instance Exception Interruption

-- | An event line, at the time given.
type Emit = ZonedTime -> String -> [(String, String)] -> IO ()

run :: String -> FilePath -> (T.Text, Schedule) -> IO ()
run host path (text, s) = do
  hSetBuffering stdout LineBuffering
  lock <- newMVar ()
  let line l = withMVar lock (const (putStrLn l))
      emitAt t name fields = line (eventLine t name fields)
      emit name fields = getZonedTime >>= \t -> emitAt t name fields
  driver <- either (\e -> hPutStrLn stderr e >> exitFailure) pure (traverse readable [1100, 4122])
  pid <- getProcessID
  myThreadId >>= interruptOnSignals emit
  emit "begin" [("pid", show pid), ("schedule", string path), ("text", string (T.unpack text))]
  begun <- getMonotonicTime
  progress <- newIORef notBegun
  let -- A round whose commands could not go out is not stepped, so a phase's
      -- 88, which goes in its first round only, waits for one that can write.
      stepping r
        | Just session <- roundSession r,
          Right _ <- writable session = do
            o <- observation begun r
            (p', es, result) <- (\p -> step s p o) <$> readIORef progress
            writeIORef progress p'
            mapM_ (stepEvent emitAt r) es
            pure result
        | otherwise = pure (Right [])
      opening = open defaultPatience defaultPoll (Host host) (Port 502) (UnitId 1)
  finish <-
    drive
      opening
      (driveEvent line emit)
      (scheduleRound s)
      [need (scheduleWatch s) (const (pure ()))]
      (Drive driver stepping (finalCommands (scheduleFinal s)))
  emit "end" (endFields finish)
  exitWith (exitCode finish)
  where
    readable n = either (const (Left (show n <> ": not readable"))) Right (Table.readableAt n)

-- | Why a drive ended, as its last line says.
endFields :: Finish Done -> [(String, String)]
endFields f = case f of
  Finished ScheduleDone -> [("why", quote "schedule"), ("detail", "null")]
  Finished Stopped -> [("why", quote "stop"), ("detail", "null")]
  Interrupted e -> case fromException e of
    Just (Interruption _) -> [("why", quote "signal"), ("detail", "null")]
    Nothing -> [("why", quote "error"), ("detail", string (displayException e))]

-- | 0 where the schedule or the compressor ended the drive, the shell's
-- status of the signal where one did, and 1 for an error.
exitCode :: Finish r -> ExitCode
exitCode f = case f of
  Finished _ -> ExitSuccess
  Interrupted e -> case fromException e of
    Just (Interruption signal) -> ExitFailure (128 + fromIntegral signal)
    Nothing -> ExitFailure 1

-- | What the schedule sees of a round: 1100 and 4122, and the time 1100 was
-- asked, on the monotonic clock, since the drive began.
observation :: Double -> Round -> IO Observation
observation begun r = do
  now <- getMonotonicTime
  pure
    Observation
      { observedAt = Instant (maybe now askedMonotonic (askedOf r 1100) - begun),
        observedCompressor = compressorOf =<< readingAt 1100,
        observedDraw = drawOf =<< readingAt 4122
      }
  where
    readingAt a = either (const Nothing) (Just . answerReading) . sampleResult =<< roundSample r (Address a)

askedOf :: Round -> Word16 -> Maybe Asked
askedOf r a = find ((== Address a) . registerAddress . askedRegister) (roundReads r)

-- | The line of what the step did. The run's start and stop are stamped with
-- the time 1100 was asked.
stepEvent :: Emit -> Round -> Event -> IO ()
stepEvent emitAt r e = case e of
  BeganPhase i p -> now "phase" [("index", show i), ("phase", object (phaseKeys p))]
  CompressorStarted -> at1100 "start"
  CompressorStopped -> at1100 "stop"
  Exported c ->
    now
      "export"
      [ ("pv", number (computationPv c)),
        ("draw", number (computationDraw c)),
        ("export", number (computationExport c)),
        ("written", number (computationWritten c))
      ]
  NoDraw t -> now "skip" [("address", address t), ("why", quote "no-draw")]
  where
    now name fields = getZonedTime >>= \t -> emitAt t name fields
    at1100 name = maybe getZonedTime (pure . askedAt) (askedOf r 1100) >>= \t -> emitAt t name []

-- | The line of what the drive did: a read as a watch writes it, and the
-- rest as events. The finals ignore SIGINT and SIGTERM from their beginning.
driveEvent :: (String -> IO ()) -> (String -> [(String, String)] -> IO ()) -> DriveEvent -> IO ()
driveEvent line emit e = case e of
  RoundEvent (ReadDone a) -> line (watchLine a)
  RoundEvent (Opened s) ->
    emit
      "session"
      [ ("software", software (Just (sessionSoftware s))),
        ("writable", either (const "false") (const "true") (writable s))
      ]
  RoundEvent (NotOpened why) -> emit "unopened" [("why", string (T.unpack why))]
  RoundEvent (Dropped why) -> emit "lost" [("why", string (endingText why))]
  Wrote (Command t v) o ->
    emit "write" ([("address", address t), ("value", value v)] <> outcomeFields o)
  Skipped (Command t _) why ->
    emit "skip" [("address", address t), ("why", quote (skipText why))]
  Drive.Finals -> ignoreSignals >> emit "final" []
  where
    skipText why = case why of
      NoSession -> "no-session"
      SoftwareDiffers -> "not-writable"

-- | The @outcome@ and @detail@ of a write.
outcomeFields :: Outcome 'Free -> [(String, String)]
outcomeFields o = case o of
  Sent Confirmed -> plain "confirmed"
  Sent (DidNotStick bytes) -> detailed "did-not-stick" (hex bytes)
  Sent Unconfirmed -> plain "unconfirmed"
  Sent (ReadBackFailed f) -> detailed "read-back-failed" (show f)
  Refused r -> detailed "refused" (show r)
  Failed f -> detailed "failed" (show f <> sent f)
  where
    plain name = [("outcome", quote name), ("detail", "null")]
    detailed name d = [("outcome", quote name), ("detail", string d)]
    sent (Unsent _) = "; nothing was sent"
    sent _ = "; the request went out and may have taken effect"

-- | On the first SIGINT or SIGTERM, ignore both from then on, write a
-- @signal@ line, and interrupt the drive, whose finals then run under the
-- ordinary mask, so that the timeouts of their requests still work. The
-- drive is interrupted also where the line cannot be written, as when
-- stdout is a pipe whose reader the same SIGINT ended.
interruptOnSignals :: (String -> [(String, String)] -> IO ()) -> ThreadId -> IO ()
interruptOnSignals emit mainThread = do
  fired <- newIORef False
  let on signal name = void (installHandler signal (Catch (once fired signal name)) Nothing)
  on sigINT "SIGINT"
  on sigTERM "SIGTERM"
  where
    once fired signal name = do
      first <- atomicModifyIORef' fired (\f -> (True, not f))
      if first
        then do
          ignoreSignals
          void (try (emit "signal" [("name", quote name)]) :: IO (Either IOException ()))
          throwTo mainThread (Interruption signal)
        else pure ()

-- | Ignore SIGINT and SIGTERM, also for an exit that no signal began: under
-- the ordinary mask, a second interruption would arrive at the first wait
-- for an answer.
ignoreSignals :: IO ()
ignoreSignals = mapM_ (\signal -> void (installHandler signal Ignore Nothing)) [sigINT, sigTERM]

eventLine :: ZonedTime -> String -> [(String, String)] -> String
eventLine t name fields = object (("time", quote (stamp t)) : ("event", quote name) : fields)

object :: [(String, String)] -> String
object fields = "{" <> intercalate ", " (map field fields) <> "}"

-- | A target's address, as a JSON number.
address :: Target 'Free -> String
address t = let Address a = registerAddress (targetRegister t) in show a

value :: Value -> String
value v = case v of
  Real x -> number x
  Count n -> show n
  Code n -> show n
  Flag b -> if b then "true" else "false"
  DriveSignal NotDriven -> "-1"
  DriveSignal (Driven n) -> show n

-- | A number as JSON writes it; JSON has none for NaN or an infinity.
number :: Double -> String
number x
  | isNaN x || isInfinite x = "null"
  | otherwise = show x

-- | A JSON string, in ASCII.
string :: String -> String
string s = "\"" <> concatMap escape s <> "\""
  where
    escape c = case c of
      '"' -> "\\\""
      '\\' -> "\\\\"
      '\n' -> "\\n"
      '\r' -> "\\r"
      '\t' -> "\\t"
      _
        | isAscii c && not (isControl c) -> [c]
        | ord c < 0x10000 -> unit (ord c)
        | otherwise -> let n = ord c - 0x10000 in unit (0xd800 + n `div` 0x400) <> unit (0xdc00 + n `mod` 0x400)
    unit n = "\\u" <> pad (showHex n "")
    pad h = replicate (4 - length h) '0' <> h
