# PV control through 74 and 88

How a consumer drives the heat pump on a PV surplus: what it writes to 74,
the surplus, and 88, the target, and what the controller does with them.
The sources and the reading of the controller are in `doc/pv-control.md`;
this folder holds the runs left to do.

The aim the runs now serve: a PV run held at low power, near the heating
floor of 24 rps and 0.6 to 0.74 kW, for as long as the store takes, rather
than a short run at up to 4 kW. A start and a stop every 10 minutes wears
the compressor, and a run at the top draws more than a small surplus
covers.

## Where it stands

Settled on the machine, 2026-11-05 to 2026-11-08:

- 74 is in kW, and the controller adds its own draw back.
- A PI controller, gains `IV017` to `IV019`, sets the speed on the mean of
  74 over `PV011` less a target of 0. A constant 74 above 0 drives it to the
  top; a mean of 0 holds the speed where it is, the start program's 50.4
  rps and 1.2 kW once that is over.
- 74 at 0 ended a run at the minimum runtime, 10 minutes, far below
  `PV006` (evening of 2026-11-07); it held one at 120 rps past it on
  2026-11-06. A negative value ends a run.
- 74 written as a meter's export did not hold a run, also from the first
  write: with `PV011` at 2.0 min the run overshoots and stops early.
- 88 at -1.0 and at +1.0, each for 3 minutes past the start program, moved
  nothing.
- A PV start waits 30 minutes after a PV stop.
- 4108 is a target, `HeatPumpPowerLimit`, and volatile: `System Neustart`
  returned it to -1, and 74 to 0 (evening of 2026-11-07).
- 4108 at 0.8 under a draw of 3.1 kW ended the run within 9 s, before the
  minimum runtime, rather than capping it (late evening of 2026-11-07,
  `doc/verification-2026-11-07-power-limit.md`).
- 4108 at 1.5 from before the start, beside 74 at 2.0, capped the run: the
  draw held near 1.4 kW for 42 minutes, past the minimum runtime, until
  `PV006` ended it (evening of 2026-11-08,
  `doc/verification-2026-11-08-power-limit-cap.md`).

So 4108 holds a run below full speed past the minimum runtime, at 1.4 kW
so far rather than the floor's 0.6 to 0.74. Open: whether a limit below the
start program's 1.2 kW caps too, what decides at the minimum runtime,
whether 88 weighs in a start or a stop, what sets the 30 minutes, and what
the controller does with a value no one renews.

## Next, in order

1. 4108, `Leistungsbegrenzung Wärmepumpe`, as a cap under a PV run: a
   constant surplus at 74, which alone drives the speed to the top, and a
   limit at 4108. 1.5 from before the start capped the run to `PV006`;
   next, the same run with the limit lower, 1.2, 1.0, then 0.8, one run
   each, never lowered under a running run. The steps are in
   `power-limit-4108-semantics-unknown.md`.
2. The meter-style run with `PV011` at 0.5 min, with the PV the meter
   simulates near the floor's draw: whether the loop settles there, and
   whether a settled loop, its mean near 0, ends at the minimum runtime as
   74 at 0 did. This is the feed evcc's Lambda workaround would give an
   iDM, but renewed every 60 s and clamped at 0; stock evcc adds the draw
   (`what-evcc-writes-to-74.md`).
3. The overnight test of 74, `does-the-control-act-on-a-74-no-one-renews.md`.
   A restart from the display is measured; a power cycle at the mains
   switch is not, and is not needed for it.
4. A PV hot water charge.

Before the next run, step 1 of `watch-the-request-reason-pv-in-idm-web`:
a `tools/webprobe.py` capture during it.

## Files

- `power-limit-4108-semantics-unknown.md`: 4108 from the first reads to the
  cap of 2026-11-08, and the runs of step 1; what of 4108 lies outside a PV
  run.
- `does-88-set-the-export-the-pv-controller-holds.md`: the runs of
  2026-11-07 on 88, answered no for the speed, and step 2 with its
  schedule.
- `does-a-low-surplus-at-74-cap-the-speed.md`: the question that led here;
  answered no for a constant 74, the rest carried into the 88 run.
- `does-the-control-act-on-a-74-no-one-renews.md`: 74 keeps its value past
  `SSYSPV030`'s five hours; whether the control acts on it is step 3.
- `what-a-power-cycle-does-to-74-and-the-controller.md`: what a restart
  leaves behind, 74 among it; answered for `System Neustart`, open for a
  power cycle and an update.
- `pv-hot-water-charge-on-74-untested.md`: hot water rather than the store,
  once the store charge is settled.
- `what-evcc-writes-to-74.md`: stock evcc writes the draw plus the surplus,
  so counts the draw twice here; the Lambda workaround writes the export,
  clamped at 0. Nothing on 4108.

## Outside this folder

- `controller-behavior-when-glt-values-stop-unknown`: the same question for
  every register a building management system writes.
- `watch-the-request-reason-pv-in-idm-web`: whether a start or stop was PV's,
  read from the web backend.
- `order-of-the-open-todos`: where this folder stands among the other todos.
