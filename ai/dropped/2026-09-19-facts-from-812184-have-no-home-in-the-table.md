# Facts from 812184 have no home in the table

Reading 812184 rev. 13 turned up a property of a register that the table cannot
express: **4122 is a model output, not a meter reading.** Running, the
controller computes it from the compressor characteristic, the evaporation and
condensation temperature, the speed and the fan power; at standstill it is a
forecast from the outside temperature, the storage or return temperature, the
minimum speed and the TWW-Erwärmer maximum. Anyone who logs it as measured
electrical power is logging a prediction, and nothing in the types says so.

The same shape of problem will recur: 812184 also says the PV block is inert
until PV008 is set, and that 74 carries a surplus only in a cascade.

## Why it is not just a new column

`tools/transcribe.py` derives the TSVs from 812170 and the machine capture. A
`computed`/`measured` column could not be derived from either — it would have
to be typed in by hand, in the one place the architecture says nothing may be
typed in by hand. Adding it there would quietly make the transcription script
no longer the single source of the table.

## The options, none of them chosen

- Leave it in prose. The fact is in `doc/research.md`; a caller who reads the
  documents is warned, a caller who does not is not.
- A second, hand-written table that the parser joins onto the generated one,
  sourced from 812184 and explicitly marked as such. Keeps the generated file
  generated; costs a join and a second file to keep true.
- A distinction in `IDM.Navigator.Register` instead of in the data — e.g. a
  reading carries how it came about. Strongest for callers, and the least
  obviously right: the manual draws the distinction for exactly one address so
  far, so the type would be near-empty.

## What it blocks

Nothing today. It becomes urgent if the library ever grows a "log this series"
convenience, because that is the moment a prediction gets filed as a
measurement.

## Dropped 2026-09-20: the first option, prose

Dominik's decision: the facts stay in `doc/research.md`, the table and the
types do not learn them. No second file to keep true, no near-empty
constructor. The cost is accepted — a caller who does not read the documents is
not warned that 4122 is a forecast.

The websocket cannot help here, which is what closes it rather than defers it.
The backend settles what the machine is doing, never how a number came about;
only 812184 draws that distinction, so no capture will ever make the fact
derivable and the generated table can never carry it.

The reopening condition stands: a convenience that logs a series. A second
inhabitant would also change the arithmetic — the Wärmemenge counters and the
page disagree per charge, and "computed" against "measured" is one of the
shapes that disagreement could have.
