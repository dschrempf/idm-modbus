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

## Step 2 on the evening of 2026-11-06

Run, with 1.0 minus 4122 every 20 s from 3.5 min after the compressor
started: no. The speed climbed to 117 rps while the values written were
already negative, fell to the floor, and the run stopped after 8 min 10 s,
before the minimum runtime. The speed followed the sign of the two-minute
mean of 74, not the value written last
(`doc/verification-2026-11-06-pv-surplus-loop.md`). A second start on 1.7,
for the hold-and-step test, never came.

Writing the meter's export does not hold a run near a target. The
candidates left are the target at 88, which the controller may regulate the
mean of 74 toward, `IV002` and 4108. `doc/pv-control.md` lists what to
watch before the next write: 12763's internal value of 74 and 88, and the
reason for a request in `heatpump.info`.

## Next, from 2026-11-07

The speed is a PI controller's, on the mean of 74 less a target, 0 so far
(`doc/pv-control.md`). A constant 74 never closes that error, so it caps
nothing; a meter-style 74 can, and the evening's overshoot came partly from
a mean still full of the start's 1.7. The low-power charge this note asks
for is, under that reading, 88 at a negative target with 74 the meter's
export. `does-88-set-the-export-the-pv-controller-holds` runs both: the
meter from the first write, then steps of 88.

## Closed on 2026-11-09

Answered: no value written to 74 caps the speed. A constant 74 drives the
speed to the top, and 74 written as a meter's export overshoots and stops
early (`doc/pv-control.md`). The low-power run it asked for went to
`pv-control-of-74-and-88`, where 4108 at 1.5 held a run near 1.4 kW to
`PV006` (`doc/verification-2026-11-08-power-limit-cap.md`); the lower
limits, and the meter-style run with `PV011` at 0.5 min, are its steps.
