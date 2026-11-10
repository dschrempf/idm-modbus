{-# LANGUAGE DataKinds #-}

-- |
-- Module      :  IDM.Navigator.Schedule.Step
-- Description :  One round of a schedule: what it writes, and whether it ends
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- 'step' is pure, so the test suite runs a schedule without a machine. It
-- sees of a round only what the schedule reads, the 'Observation', and
-- answers with the commands to send after the round, or why the schedule
-- ended.
module IDM.Navigator.Schedule.Step
  ( -- * A round as the schedule sees it
    Observation (..),
    Instant (..),
    Compressor (..),
    compressorOf,
    drawOf,

    -- * The step
    Progress,
    notBegun,
    step,
    Command (..),
    Event (..),
    Computation (..),
    Done (..),
  )
where

import Data.Bifunctor (first)
import qualified Data.List.NonEmpty as NE
import Data.Maybe (fromMaybe, isJust)
import IDM.Navigator.Register (Cost (..), Reading (..), Value (..))
import IDM.Navigator.Schedule
import IDM.Navigator.Target (Target (..))

-- | What a round read of the two registers the schedule follows.
data Observation = Observation
  { -- | the time 1100 was asked
    observedAt :: Instant,
    -- | 1100, where it gave a value this round
    observedCompressor :: Maybe Compressor,
    -- | 4122, in kW, where it gave a value this round
    observedDraw :: Maybe Double
  }
  deriving (Show, Eq)

-- | Seconds on the monotonic clock.
newtype Instant = Instant Double
  deriving (Show, Eq, Ord)

-- | 1100, @Status Verdichter 1@, by the labels of its codes.
data Compressor = Ein | Aus
  deriving (Show, Eq)

-- | 1100's reading: code 1 is Ein, code 0 Aus, anything else no value.
compressorOf :: Reading Value -> Maybe Compressor
compressorOf r = case r of
  Measured (Code 1) -> Just Ein
  Measured (Code 0) -> Just Aus
  _ -> Nothing

-- | 4122's reading, in kW. A 'NoValueOr' is no value: at 4122 it is the
-- sentinel -1.0, which would put the export 1 kW too high.
drawOf :: Reading Value -> Maybe Double
drawOf r = case r of
  Measured (Real x) -> Just x
  _ -> Nothing

-- | Where a schedule stands between rounds.
data Progress = Progress
  { -- | the run's start: the round in which 1100 first read Ein
    progressStart :: Maybe Instant,
    -- | Nothing before the first round
    progressPhase :: Maybe Current
  }

data Current = Current
  { -- | from 0, in the file's order
    currentIndex :: Int,
    currentPhase :: Phase,
    currentLater :: [Phase],
    -- | the phase's first round
    currentBegan :: Instant,
    -- | the last round that wrote 74 in this phase
    currentWrote :: Maybe Instant
  }

-- | Before the first round.
notBegun :: Progress
notBegun = Progress Nothing Nothing

-- | A write to a target. @IDM.Navigator.Drive@'s will take its place.
data Command = Command (Target 'Free) Value
  deriving (Show, Eq)

-- | What a round did, besides its commands.
data Event
  = -- | the phase of this index began
    BeganPhase Int Phase
  | -- | the run's start: 1100 read Ein, for the first time
    CompressorStarted
  | -- | the run's stop: 1100 read Aus, after the start
    CompressorStopped
  | -- | an export, and the value that goes to 74
    Exported Computation
  | -- | the target is due but not written: 4122 gave no value
    NoDraw (Target 'Free)
  deriving (Show, Eq)

-- | An export and the value it comes to, in kW.
data Computation = Computation
  { computationPv :: Double,
    -- | 4122
    computationDraw :: Double,
    -- | 'computationPv' less 'computationDraw'
    computationExport :: Double,
    -- | the export rounded to 0.01 kW, then bounded
    computationWritten :: Double
  }
  deriving (Show, Eq)

-- | Why the schedule ended: its last phase did, or the compressor stopped.
data Done = ScheduleDone | Stopped
  deriving (Show, Eq)

-- | One round, in this order:
--
-- 1. 1100 updates the run's start and stop. The start is the first round in
--    which 1100 reads Ein, whether or not it read Aus before; the stop is
--    the first round after the start in which it reads Aus. A round without
--    1100 changes neither.
-- 2. The stop ends the schedule.
-- 3. The current phase's end is checked; where it is reached, the next
--    phase begins and is checked in turn, so several can end in one round.
--    The end of the last ends the schedule. The first phase begins in the
--    first round.
-- 4. The current phase's commands: 88 in its first round, then, where 74
--    is due, 4108 and 74, or a 'NoDraw' where a @pv@ phase has no draw. A
--    phase writes 74 in its first round; a 74 not written stays due.
--
-- A span, @every@, @for@ or @after-start@, passes at the first round at or
-- after its end, so it rounds up to whole periods. The rounds do not come
-- exactly a period apart, as 1100 is asked a moment earlier or later in
-- each, so the span counts as passed half a period before those whole
-- periods are up: otherwise an @every@ of one period would write in every
-- other round whenever 1100 came a moment early.
--
-- After a 'Left' the schedule is over, and the step is not called again.
step :: Schedule -> Progress -> Observation -> (Progress, [Event], Either Done [Command])
step s p o = case (progressStart p, observedCompressor o) of
  (Just _, Just Aus) -> (p, [CompressorStopped], Left Stopped)
  (Nothing, Just Ein) -> prepend CompressorStarted (phases (Just now))
  (start, _) -> phases start
  where
    now = observedAt o
    prepend e (p', es, r) = (p', e : es, r)
    phases start =
      let (begun, c0) = case progressPhase p of
            Just c -> ([], c)
            Nothing ->
              let ps = schedulePhases s
               in ([BeganPhase 0 (NE.head ps)], Current 0 (NE.head ps) (NE.tail ps) now Nothing)
          (advanced, current) = advance (scheduleRound s) start now c0
       in case current of
            Nothing -> (Progress start Nothing, begun <> advanced, Left ScheduleDone)
            Just c ->
              let fresh = maybe True ((/= currentIndex c) . currentIndex) (progressPhase p)
                  (c', es, cs) = commands (scheduleRound s) o fresh c
               in (Progress start (Just c'), begun <> advanced <> es, Right cs)

-- | Ends phases until one runs on; Nothing where the last ended.
advance :: Period -> Maybe Instant -> Instant -> Current -> ([Event], Maybe Current)
advance r start now c
  | ended = case currentLater c of
      next : later ->
        let i = currentIndex c + 1
         in first (BeganPhase i next :) (advance r start now (Current i next later now Nothing))
      [] -> ([], Nothing)
  | otherwise = ([], Just c)
  where
    ended = case phaseEnd (currentPhase c) of
      AtStart -> isJust start
      AtStop -> False
      AfterStart span' -> maybe False (\t -> passed r span' t now) start
      For span' -> passed r span' (currentBegan c) now

-- | The current phase's commands, in the order they go out.
commands :: Period -> Observation -> Bool -> Current -> (Current, [Event], [Command])
commands r o fresh c = (c', es, target <> surplus)
  where
    ph = currentPhase c
    now = observedAt o
    target = [Command PvTarget (Real t) | fresh, Just t <- [phaseTarget ph]]
    limit = [Command HeatPumpPowerLimit (Real l) | Just l <- [phaseLimit ph]]
    every = fromMaybe (let Period n = r in Seconds n) (phaseEvery ph)
    due = maybe True (\t -> passed r every t now) (currentWrote c)
    wrote = c {currentWrote = Just now}
    (c', es, surplus)
      | not due = (c, [], [])
      | otherwise = case phaseSurplus ph of
          Constant x -> (wrote, [], limit <> [Command PvSurplus (Real x)])
          Export pv bounds -> case observedDraw o of
            Nothing -> (c, [NoDraw PvSurplus], [])
            Just d ->
              let w = bounded bounds (hundredths (pv - d))
               in (wrote, [Exported (Computation pv d (pv - d) w)], limit <> [Command PvSurplus (Real w)])

-- | Whether a span from one round has passed by another; see 'step'.
passed :: Period -> Seconds -> Instant -> Instant -> Bool
passed (Period p) (Seconds n) (Instant from) (Instant to) =
  to - from >= (fromIntegral periods - 0.5) * fromIntegral p
  where
    periods = (n + p - 1) `div` p

hundredths :: Double -> Double
hundredths x = fromInteger (round (x * 100)) / 100

bounded :: Bounds -> Double -> Double
bounded (Bounds lo hi) = maybe id min hi . maybe id max lo
