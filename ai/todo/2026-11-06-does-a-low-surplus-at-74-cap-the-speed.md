# Does a low surplus at 74 cap the speed?

## The question

A consumer's first use of 74 is to ask for an additional heating store
charge at low power, near the floor of 24 rps and 0.67 kW
(`doc/verification-2026-11-05-floor.md`), and otherwise to leave the
controller to its own business. With 3.0 written, the run of 2026-11-05 drew
3.5 to 4.05 kW (`doc/verification-2026-11-05-pv-surplus.md`). 812184 has
the pump start once the surplus exceeds its forecast draw and says nothing
of the speed while it runs. Whether the controller sizes a run to 74 at all
is unsettled.

How a cap would work depends on `pv-surplus-74-may-include-the-pumps-own-draw`:

- If the controller adds its draw back, a constant value caps nothing: the
  surplus it weighs grows with the draw. A consumer would write the target
  minus 4122, as a meter would read with that much PV and no other load,
  every minute, against `PV011`'s 2 min average.
- If it does not, a constant value caps the run, if the controller sizes the
  run to the surplus at all.

If neither holds a run near the floor, 74 only starts a charge, and its
speed needs another lever: `IV002` `N2_MOD_MAX_POWER_HEATING`, a setting
that caps every heating run, or 4108 (`power-limit-4108-semantics-unknown`).

## How we might solve it

Write 1.0, not 0.8: the PV page weighed a surplus against 0.7 kW at rest and
0.8 kW running, so 0.8 sits on the threshold.

1. With B38 well below `PV006`, write 1.0 every minute. Watch 4122 and the
   speed, 6245 `N2_MODULATION_OVERVIEW`, past the start program.
2. If the draw climbs to full speed and the controller adds its draw back,
   write 1.0 minus 4122, read just before, every minute, and watch whether
   the draw settles near 1.0.
3. Record it in a dated `doc/`.

Step 1 is the first phase of the session in
`run-the-open-todos-in-six-sessions`; the own-draw test follows on the same
run.

## Step 1 on 2026-11-06

Run at 1.7, since 1.0 did not start the charge in 12.5 min. The run went
from its start program to 120 rps and 3.9 kW: a constant value caps
nothing. `pv-surplus-74-may-include-the-pumps-own-draw` found that the
controller adds its draw back, so the first case above holds, and on -0.5
the speed fell from 120 to 81 rps before the stop: the controller acts on
74 while it runs (`doc/verification-2026-11-06-pv-surplus-own-draw.md`).

Step 2 is left, postponed by choice. It needs a start at 1.7 or more, the
start threshold lying between 1.0 and 1.7, and then 1.0 minus 4122 every
minute once the start program has ended. With `PV006` at 40 °C, B38 must
start well below it: the run of 2026-11-06 rose 7 K in 15 min.
