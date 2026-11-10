-- |
-- Module      :  IDM.Navigator.Rounds
-- Description :  Reading what every part of a program needs, round after round
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- A part of a program names its 'Need', the registers it reads. A round reads
-- the union of the needs once, in one session, and hands each part the reads
-- it named, so the controller has one client however many parts there are.
--
-- A round holds reads only, each with its own time and session. A lost
-- connection ends the session: the rest of the round's reads are not asked,
-- and the next round opens a new session, which reads the software anew.
--
-- Nothing here prints. What a round does as it goes, a read, an opening, a
-- loss, is a 'RoundEvent', handed to a callback as it happens.
module IDM.Navigator.Rounds
  ( -- * A round
    AskedOn (..),
    Asked,
    RoundOn (..),
    Round,
    roundSample,
    RoundEventOn (..),
    RoundEvent,

    -- * Reading one round
    RoundRequests (..),
    sessionRequests,
    readRound,

    -- * Round after round
    Period (..),
    Need,
    need,
    needed,
    rounds,
  )
where

import Control.Concurrent (threadDelay)
import Control.Exception (IOException, finally, try)
import Data.Bifunctor (first)
import Data.Function (on)
import Data.IORef (newIORef, readIORef, writeIORef)
import Data.List (find, nubBy)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (ZonedTime, getZonedTime)
import GHC.Clock (getMonotonicTime)
import IDM.Modbus.TCP (Address, Ending, Failure (..))
import IDM.Navigator.Client (Poll (..), Sample (..), Session, close, readOne, sessionPoll)
import IDM.Navigator.Register (Register (..))

-- | One read of a round: what was asked, when, on which session, and what
-- came back. The session is a parameter so that the test suite can read a
-- round off a fake controller; a program reads it on a 'Session'.
data AskedOn s = Asked
  { askedRegister :: Register,
    -- | the local time the read was asked: the stamp of its capture line
    askedAt :: ZonedTime,
    -- | the same moment on the monotonic clock, in seconds, for durations
    askedMonotonic :: Double,
    -- | 'Nothing' where no session was open
    askedSession :: Maybe s,
    -- | 'Nothing' where no session was open, so nothing was sent
    askedSample :: Maybe Sample
  }

type Asked = AskedOn Session

data RoundOn s = Round
  { -- | every register asked, each once, in the order given
    roundReads :: [AskedOn s],
    -- | the session still open at the round's end; 'Nothing' if it was lost
    -- or none could be opened
    roundSession :: Maybe s
  }

type Round = RoundOn Session

-- | The sample of an address, where the round asked it on a session: an
-- answer or a failure.
roundSample :: RoundOn s -> Address -> Maybe Sample
roundSample r a = find ((== a) . registerAddress . askedRegister) (roundReads r) >>= askedSample

-- | What a round reports as it goes, so that a capture can print each read
-- when it is made, and a session's opening and loss are in the stream.
data RoundEventOn s
  = ReadDone (AskedOn s)
  | -- | a session was opened, and read the software
    Opened s
  | -- | why no session could be opened; the round asks nothing
    NotOpened Text
  | -- | why the session ended; it is closed, and the round asks nothing more
    Dropped Ending

type RoundEvent = RoundEventOn Session

-- | The requests a round is made of.
data RoundRequests m s = RoundRequests
  { -- | a new session, or why there is none
    openSession :: m (Either Text s),
    readSample :: s -> Register -> m Sample,
    closeSession :: s -> m (),
    -- | after a request, so as not to stall the controller
    pauseAfter :: s -> m (),
    localClock :: m ZonedTime,
    -- | seconds
    monotonicClock :: m Double
  }

-- | The requests of a round on the controller, a session made by the action
-- given. An opening that throws an 'IOException' opens none, and says why.
sessionRequests :: IO Session -> RoundRequests IO Session
sessionRequests opening =
  RoundRequests
    { openSession = first (T.pack . show) <$> (try opening :: IO (Either IOException Session)),
      readSample = readOne,
      closeSession = close,
      pauseAfter = threadDelay . pollIntervalMicroseconds . sessionPoll,
      localClock = getZonedTime,
      monotonicClock = getMonotonicTime
    }

-- | One round: open a session where none is given, read every register
-- given in order, and report each read as it is made.
--
-- A read whose failure ended the connection closes the session, and the
-- reads after it are not asked. The session the round ends with is the
-- caller's, to give to the next round or to close.
readRound :: (Monad m) => RoundRequests m s -> (RoundEventOn s -> m ()) -> Maybe s -> [Register] -> m (RoundOn s)
readRound requests report held regs = do
  session <- maybe opening (pure . Just) held
  go session regs []
  where
    opening =
      openSession requests >>= \opened -> case opened of
        Right s -> Just s <$ report (Opened s)
        Left why -> Nothing <$ report (NotOpened why)
    go session [] done = pure (Round (reverse done) session)
    go Nothing (r : rs) done = do
      a <- asked r Nothing (pure Nothing)
      go Nothing rs (a : done)
    go (Just s) (r : rs) done = do
      a <- asked r (Just s) (Just <$> readSample requests s r)
      case sampleResult <$> askedSample a of
        Just (Left (Ended why)) -> lose why a
        Just (Left (Unsent why)) -> lose why a
        _ -> pauseAfter requests s >> go (Just s) rs (a : done)
      where
        lose why a = do
          report (Dropped why)
          closeSession requests s
          go Nothing rs (a : done)
    asked r session reading = do
      t <- localClock requests
      m <- monotonicClock requests
      a <- Asked r t m session <$> reading
      a <$ report (ReadDone a)

-- | Seconds from the start of one round to the start of the next.
newtype Period = Period Int

-- | A part of a program: the registers it reads each round, and what it does
-- with them.
data Need = Need [Register] (Round -> IO ())

-- | A need of the registers given, which a round hands the reads of those
-- registers, and of no others.
need :: [Register] -> (Round -> IO ()) -> Need
need = Need

-- | The registers a round of the needs reads: every one some need names,
-- each once, in the order of first mention.
needed :: [Need] -> [Register]
needed needs = nubBy ((==) `on` registerAddress) (concat [regs | Need regs _ <- needs])

-- | Round after round, every period, until an exception, which closes the
-- session open at the time.
--
-- The first round begins at once. A round that overran its period starts the
-- next at once, without catching up.
rounds :: IO Session -> (RoundEvent -> IO ()) -> Period -> [Need] -> IO a
rounds opening report (Period seconds) needs = do
  held <- newIORef Nothing
  let tracked e = do
        case e of
          Opened s -> writeIORef held (Just s)
          Dropped _ -> writeIORef held Nothing
          _ -> pure ()
        report e
      go session due = do
        now <- getMonotonicTime
        threadDelay (round (max 0 (due - now) * 1e6))
        r <- readRound (sessionRequests opening) tracked session regs
        mapM_ (handOver r) needs
        getMonotonicTime >>= go (roundSession r) . max (due + fromIntegral seconds)
  (getMonotonicTime >>= go Nothing) `finally` (readIORef held >>= mapM_ close)
  where
    regs = needed needs
    handOver r (Need named handle) =
      handle r {roundReads = filter ((`elem` map registerAddress named) . registerAddress . askedRegister) (roundReads r)}
