-- |
-- Module      :  IDM.Navigator.Schedule
-- Description :  A schedule of writes to 74, 88 and 4108, fixed before a run
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- What @idm-drive@ runs: phases that write the PV surplus 74, its target 88
-- and the power limit 4108, each until a time or until the compressor
-- starts or stops, and the values all three get on every exit. A schedule
-- is a measurement, not a strategy, so it lives in a private sublibrary and
-- the package does not expose it. @IDM.Navigator.Schedule.Parse@ reads one
-- from a file, @IDM.Navigator.Schedule.Step@ runs it round by round.
module IDM.Navigator.Schedule
  ( Schedule (..),
    Period (..),
    Seconds (..),
    Finals (..),
    Phase (..),
    Surplus (..),
    Bounds (..),
    End (..),
  )
where

import Data.List.NonEmpty (NonEmpty)
import IDM.Navigator.Register (Register)
import IDM.Navigator.Rounds (Period (..))

data Schedule = Schedule
  { -- | the period of the rounds, shared by the watch and the driver
    scheduleRound :: Period,
    -- | the registers recorded each round, beside those the driver reads
    -- itself, 1100 and 4122
    scheduleWatch :: [Register],
    scheduleFinal :: Finals,
    schedulePhases :: NonEmpty Phase
  }
  deriving (Show, Eq)

-- | A span of whole seconds, positive.
newtype Seconds = Seconds Int
  deriving (Show, Eq, Ord)

-- | The values written on every exit, in the order of
-- @IDM.Navigator.Schedule.Step.finalCommands@.
data Finals = Finals
  { -- | to 74, in kW
    finalSurplus :: Double,
    -- | to 88, in kW
    finalTarget :: Double,
    -- | to 4108, in kW
    finalLimit :: Double
  }
  deriving (Show, Eq)

data Phase = Phase
  { -- | what goes to 74
    phaseSurplus :: Surplus,
    -- | the time between writes of 74; the round's where absent
    phaseEvery :: Maybe Seconds,
    -- | to 88 once, in the phase's first round, in kW; absent, 88 is left as
    -- it stands
    phaseTarget :: Maybe Double,
    -- | to 4108 before every write of 74, in kW; absent, 4108 is not written
    phaseLimit :: Maybe Double,
    phaseEnd :: End
  }
  deriving (Show, Eq)

data Surplus
  = -- | the same value every time, in kW
    Constant Double
  | -- | the export a meter would see with this PV and the pump as the only
    -- load: 'exportPv' less the round's 4122, rounded to 0.01 kW and then
    -- bounded, so a bound holds exactly
    Export
      { -- | in kW
        exportPv :: Double,
        exportBounds :: Bounds
      }
  deriving (Show, Eq)

-- | Bounds of an export, in kW; @min = 0@ alone is evcc's @max(0, ·)@.
data Bounds = Bounds
  { boundMin :: Maybe Double,
    boundMax :: Maybe Double
  }
  deriving (Show, Eq)

-- | When a phase ends.
data End
  = -- | in the round the compressor starts, or at once after it has
    AtStart
  | -- | with the run, when the compressor stops; only the last phase
    AtStop
  | -- | so long after the run's start
    AfterStart Seconds
  | -- | so long after the phase's first round
    For Seconds
  deriving (Show, Eq)
