# The schedule file

## Running it

    idm-drive HOST SCHEDULE > captures/navigator-10-drive-SOFTWARE-YYYY-MM-DD-HHMM.jsonl
    idm-drive --check SCHEDULE        # parse, print the phases, connect to nothing

Schedules are tracked in `schedules/`, named for what they measure . A doc's "Reproducing" names the file. A schedule holds no house
data: its values are the test's, not the house's.

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

- `round`: the period, in seconds, shared by the watch and the driver
  (`rounds-and-needs.md`, "Periods"). It is required.
- `watch`: the addresses recorded each round, beside what the driver itself
  needs (1100, 4122).
- `[final]`: `surplus` for 74, `target` for 88 and `limit` for 4108, all
  three required. They are written in the order 88, 4108, 74, as
  `drivepv.py` does, for its reasons.
- `[[phase]]`, in order. Each phase has:
  - **What goes to 74:** exactly one of `surplus`, a constant, and `pv`,
    which writes `pv` less the round's 4122, the export a meter would see
    with that PV and the pump as the only load.
  - **Bounds:** `min` and `max`, each optional, and only with `pv`. They
    bound the export; `min = 0` alone is evcc's `max(0, ·)`.
  - `every`: the seconds between writes of 74, `round` if absent. A write
    goes at the first round at or after it is due, and a phase writes in
    its first round.
  - `target`: written to 88 once, in the phase's first round, before its
    first 74. Absent, 88 is left as it stands.
  - `limit`: written to 4108 before every write of 74 in the phase.
    Absent, 4108 is not written.
  - **When the phase ends:** exactly one of `until = "start"`,
    `until = "stop"`, `after-start = S` and `for = S`. A start or a stop is
    1100 changing to Ein or to Aus. `after-start` counts from the first Ein
    of the run.
- **The run's end:** once 1100 has read Ein, an Aus ends the schedule,
  whatever phase runs, and so does the end of the last phase.

A key the format does not name is an error, and so is an end or a bound
given twice. The parser refuses rather than ignores, as the table's
parser does.

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
  { -- | monotonic, since the drive began
    observedAt :: Seconds,
    -- | 1100, if it answered this round
    observedCompressor :: Maybe Bool,
    -- | 4122, if it answered this round
    observedDraw :: Maybe Double
  }

step :: Schedule -> State -> Observation -> (State, [Event], Either Ending [Command])
```

`idm-drive` turns a `Round` into an `Observation`, and `step`'s commands
into `drive`'s. The rounds are fresh by construction, so the
`FRESH_SECONDS` of `drivepv.py` is gone. A `pv` phase in a round without
4122 writes nothing and logs a `skip`.

Entries for `checks` in `test/Main.hs`, one each:

- the phases advance on each kind of end;
- 88 goes before the phase's first 74, and only once;
- 4108 goes before each 74;
- the bounds clamp the export;
- a round without 4122 writes nothing in a `pv` phase;
- an Aus after an Ein ends the drive, and one before an Ein does not;
- every file in `schedules/` parses.
