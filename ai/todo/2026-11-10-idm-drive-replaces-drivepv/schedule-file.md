# The schedule file

## Running it

    idm-drive HOST SCHEDULE > captures/navigator-10-drive-SOFTWARE-YYYY-MM-DD-HHMM.jsonl
    idm-drive --check SCHEDULE        # parse, print the phases, connect to nothing

Schedules are tracked in `schedules/`, named for what they measure. A
doc's "Reproducing" names the file. A schedule holds no house data: its
values are the test's, not the house's. The runs made with `drivepv.py`
are not translated into schedules (`README.md`, R7).

## The format: TOML

The clamp run of `pv-control-of-74-and-88`, step 1, as the example:

```toml
# 74 as the export of a simulated PV, clamped to ±0.1 kW, PV011 at 0.1 min.
round = 10
watch = [74, 88, 4108, 1008, 1066, 1070, 1090, 1091, 1100, 1074, 4122, 1004, 1098]

[final]
surplus = -0.5
target = 0.0
limit = -1.0

[[phase]]
surplus = 2.0
target = 0.0
until = "start"

[[phase]]
pv = 2.0
min = -0.1
max = 0.1
after-start = 720

[[phase]]
pv = 1.5
min = -0.1
max = 0.1
for = 360

[[phase]]
pv = 1.2
min = -0.1
max = 0.1
for = 360

[[phase]]
pv = 1.0
min = -0.1
max = 0.1
until = "stop"
```

Keys, all values in kW or seconds:

- `round`: the period, in seconds, a positive whole number, shared by the
  watch and the driver (`rounds-and-needs.md`, "Periods"). It is required.
- `watch`: the addresses recorded each round, beside what the driver itself
  needs (1100, 4122). Each must be a readable address of the parameter
  list.
- `[final]`: `surplus` for 74, `target` for 88 and `limit` for 4108, all
  three required. They are written in the order 88, 4108, 74:
  - 88 first: a negative target left standing beside the final 74 could
    keep the pump drawing from the grid.
  - 4108 before 74: a limit left standing caps every run until the
    controller restarts, and -1 is its default.

  These reasons are `drivepv.py`'s docstring today, which session 5
  deletes; session 4 states them in the Haddock of the finals' order.

- `[[phase]]`, in order. Each phase has:
  - **What goes to 74:** exactly one of `surplus`, a constant, and `pv`,
    which writes `pv` less the round's 4122, the export a meter would see
    with that PV and the pump as the only load. The export is rounded to
    0.01 kW, as `drivepv.py` rounds it, and then bounded, so a bound holds
    exactly.
  - **Bounds:** `min` and `max`, each optional, and only with `pv`. They
    bound the export; `min = 0` alone is evcc's `max(0, ·)`. With both,
    `min` must not exceed `max`.
  - `every`: the seconds between writes of 74, `round` if absent, and not
    below `round`. A write goes at the first round at or after it is due,
    and a phase writes in its first round. A write skipped for want of
    4122 stays due, and goes at the next round that has it.
  - `target`: written to 88 once, in the phase's first round, before its
    first 74, and whether or not that 74 is skipped. Absent, 88 is left as
    it stands.
  - `limit`: written to 4108 before every write of 74 in the phase, and
    not where the 74 is skipped. Absent, 4108 is not written.
  - **When the phase ends:** exactly one of `until = "start"`,
    `until = "stop"`, `after-start = S` and `for = S`, `S` a positive
    whole number. `after-start` counts from the run's start, `for` from
    the phase's first round. A phase with `until = "stop"` must be the
    last: the stop ends the run.
- **The run's start and stop:** the start is the first round in which 1100
  reads Ein, whether or not one read Aus before it, so a drive started
  under a running compressor starts in its first round, as `drivepv.py`
  does; `doc/verification/2026-11-09-power-limit-floor.md` relies on that.
  The stop is the first round after the start in which 1100 reads Aus. A
  round in which 1100 gave no value changes neither.
- **The run's end:** the stop ends the schedule, whatever phase runs, and
  so does the end of the last phase.

A key the format does not name is an error, and so is an end or a bound
given twice. The parser refuses rather than ignores, as the table's
parser does. `toml-parser` 2's table matchers report leftover keys as
warnings in a successful result, if I read its API right; session 2
checks that, and the parser turns any warning into a failure.

The check that an address is readable is `registerArg`'s in
`app/dump/Main.hs` today. Session 2 moves it into `IDM.Navigator.Table`, beside
`byAddress`, without touching `app/dump/Main.hs`; session 4 points
`registerArg` at it.

## Types, in the private sublibrary `schedule`

`idm-drive` and `test/Main.hs` use these types; the library does not export
them:

```haskell
data Schedule = Schedule
  { scheduleRound :: Period,
    scheduleWatch :: [Register],
    scheduleFinal :: Finals,
    schedulePhases :: NonEmpty Phase
  }

data Finals = Finals {finalSurplus, finalTarget, finalLimit :: Double}

data Phase = Phase
  { phaseSurplus :: Surplus,
    phaseEvery :: Maybe Seconds,
    phaseTarget :: Maybe Double,
    phaseLimit :: Maybe Double,
    phaseEnd :: End
  }

data Surplus = Constant Double | Export {exportPv :: Double, exportBounds :: Bounds}

data Bounds = Bounds {boundMin, boundMax :: Maybe Double}

data End = AtStart | AtStop | AfterStart Seconds | For Seconds
```

## The step: pure, and tested without a machine

```haskell
data Observation = Observation
  { -- | monotonic, since the drive began: the time 1100 was asked
    observedAt :: Seconds,
    -- | 1100, where it gave a value this round
    observedCompressor :: Maybe Bool,
    -- | 4122, where it gave a value this round
    observedDraw :: Maybe Double
  }

-- | Why the schedule ended: its last phase did, or the compressor stopped.
data Done = ScheduleDone | Stopped

step :: Schedule -> State -> Observation -> (State, [Event], Either Done [Command])
```

`idm-drive` turns a `Round` into an `Observation`, and `step`'s commands
into `drive`'s; `Done` is the `r` of `Drive r`. The rounds are fresh by
construction, so the `FRESH_SECONDS` of `drivepv.py` is gone.

**From a round to an observation.** 1100 is a `UCHAR` of codes 0 and 1:
`Measured (Code 1)` is Ein, `Measured (Code 0)` Aus. 4122 is a `FLOAT` with
no documented range: `Measured x` is a draw of `x`. Anything else is
`Nothing`: a failure, a read not asked, a `NoValue`, and a `NoValueOr`,
which at 4122 is the sentinel -1.0 and would otherwise read as -1 kW and
put the export 1 kW too high.

**Within a round**, in this order:

1. 1100 updates the start and the stop, as above, each an event.
2. A stop ends the schedule.
3. Phases end: the current phase's end is checked, and if it is reached
   the next phase begins, with a `phase` event, and is checked in turn, so
   several phases can end in one round. The last phase's end ends the
   schedule.
4. The current phase's commands: 88 in its first round; then, if 74 is
   due, 4108 and 74, or a `skip` where a `pv` phase has no draw.

Entries for `checks` in `test/Main.hs`, one each:

- the phases advance on each kind of end, and several in one round;
- the start in a first round that reads Ein; a round without 1100 changes
  nothing;
- 88 goes before the phase's first 74, only once, and also when that 74 is
  skipped;
- 4108 goes before each 74, and not with a skipped one;
- the bounds clamp the export, after it is rounded to 0.01 kW;
- a round without 4122, or with -1.0 there, writes no 74 in a `pv` phase,
  and the write stays due;
- an Aus after an Ein ends the drive, and one before an Ein does not;
- the parser refuses an unknown key, two ends, a bound beside `surplus`,
  `min` above `max`, `every` below `round`, and a phase after
  `until = "stop"`;
- every file in `schedules/` parses.
