# The statistics page's heat exceeds the Wärmemenge registers by about 1.19

## The question

The registers are settled. 1754, `Wärmemenge Warmwasser`, is the running
integral of 4126, the flow sensor's thermal power, to within 0.6 %. 4126 is
flow (1072) × spread (1068 to 1070) × the specific heat of water
(`doc/verification-2026-10-01-charge.md`,
`doc/verification-2026-10-15-heat-sink.md`). The statistics page of the
controller's web backend books more heat than this:

- 1.19 between the lifetime totals
- 1.21 for the single charge of 2026-09-20
- 1.17 for the day of 2026-10-01

Its runtime and electrical energy for that day match the registers to 1 %
(`doc/verification-2026-09-20-webapi.md`). One day of 31 books hot water heat
with zero runtime and zero electricity.

What quantity does the page compute as heat? Until that's known, a reader of
the registers can't say which of the two figures for heat, and so for COP, is
the one the manufacturer means.

## Hypotheses, and what tells them apart

1. **A fixed factor on the same integral.** For example a different specific
   heat, or a nominal flow instead of the measured one. Then the ratio is
   the same every day and in every mode.
2. **A model, not a measurement.** For example electricity × a modelled COP,
   like the polynomial `N2_GLTMON` says 4122 falls back to ("falls kein Wert
   vom Inverter vorhanden ist, wird jener vom Polynom verwendet"). Then page
   heat ÷ page electricity follows the outdoor and flow temperatures, and the
   ratio to the registers drifts with them.
3. **Something added.** For example heat from the electric heater, or from
   defrosting, booked as heat. Then page minus registers tracks that source
   rather than the registers.

## How we might solve it

- Heating has started, so heating days now give a second mode. If 1748,
  `Wärmemenge Heizen`, against the page's heating heat gives the same ratio
  as hot water, that is evidence for 1.
- Data: a webapi capture, which holds the page's last 31 days, plus the
  counters 1748, 1750, 1754, 1746 and 1100 read at each midnight. A
  long-running `idm-dump --watch 600` gives that. With some days of both,
  each hypothesis is a regression on the daily rows, which I can do from the
  captures.
- Then record the outcome in a dated `doc/`, and close the open question in
  `doc/research.md`.

## Beside other runs

The watch runs for days, so it overlaps the watches and writes of other
runs. A write beside one polling watch stalled nothing on 2026-11-05
(`doc/verification-2026-11-05-pv-surplus.md`); two Modbus clients polling at
once, and a write while both poll, are untested against the stall. Start it
on a day without a run, and note in the run's `doc/` if one overlaps it.
