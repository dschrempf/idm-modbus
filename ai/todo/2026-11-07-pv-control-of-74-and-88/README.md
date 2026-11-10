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

Settled on the machine, 2026-11-05 to 2026-11-09:

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
- 4108 at 1.2 from before the start capped the run at 1.19 kW past the
  minimum runtime, after a start program drawing 1.24 to 1.30; lowered
  under the run to 1.0 it held 0.98 kW; at 0.9 it ended the run within 8 s
  (noon of 2026-11-09, `doc/verification-2026-11-09-power-limit-floor.md`).
- The controller names a PV run's request `RD_REQ_PV`, in `system`
  `overview` and `home` `detail` alike (same run).
- 4108 at 1.0 from before the start let the start program through at up to
  1.43 kW and then held 1.01 kW, 38 to 40 rps, for 26 minutes; the
  controller withdrew the request 30 min 50 s after the start, B38 2.1 K
  below `PV006`, for no reason a capture shows: not a defrost, an error or
  a lock (evening of 2026-11-09,
  `doc/verification-2026-11-09-power-limit-held-at-1-0.md`).
- With `PV011` at 0.1 min, set at the display and kept, a meter-fed run
  did not settle: the speed swung between about 35 and 95 rps, 0.9 to 2.6
  kW, some 90 s from peak to peak, rather than running to the top as at
  2.0 min. It ended 8 minutes after the start with the mean at -0.18,
  negative for at most 10 s; a negative stretch of 40 s down to -1.02 at 6
  minutes had not ended it. The third stop at about 8 minutes on a mean at
  or below zero (evening of 2026-11-10,
  `doc/verification-2026-11-10-pv-loop-at-0-1-min-swings.md`).

So 4108 holds a run past the minimum runtime at 1.0 to 1.5 kW, and ends it
below 1.0: about 1.0 kW is the lowest run it gives, not the floor's 0.6 to
0.74. Open: what ended the run at 1.0 before `PV006`, what decides at the
minimum runtime, whether 88 weighs in a start or a stop, what sets the 30
minutes, and what the controller does with a value no one renews.

## Next, in order

1. The clamp run: 74 as the export, clamped to ±0.1 kW, every 10 s, with
   `PV011` at 0.1 min. A clamp adds no lag, unlike a smoothing of the
   export, and bounds how fast the integral moves the speed: whether that
   damps the swing, and whether the run passes 8 minutes. The PV the meter
   simulates holds longer between steps than on 2026-11-10. Needs a clamp
   form of a phase in `tools/drivepv.py`, and 4768 and 5888 in the web
   watch (`does-88-set-the-export-the-pv-controller-holds.md`, "Next").
2. Lower gains, `IV017` to `IV019`, if the clamp leaves a swing: an
   EEPROM cycle at the display each way.
3. The overnight test of 74, `does-the-control-act-on-a-74-no-one-renews.md`.
   A restart from the display is measured; a power cycle at the mains
   switch is not, and is not needed for it.
4. A PV hot water charge.

4108 as a cap, the former step 1, is done
(`power-limit-4108-semantics-unknown`, closed): 1.0 to 1.5 caps a run, 0.9
ends it, and 1.0 from the start held 30 minutes and then ended before
`PV006`. Why it ended is open in
`what-ended-the-run-capped-at-1-0-before-pv006.md`, with the run that would
tell, not ranked among the steps.

Every run watches the request reason beside its settings,
`idm-web HOST --watch 10 --reason SETTING...`
(`watch-the-request-reason-pv-in-idm-web`, done), so a start or stop reads
as PV's or a circuit's. The settings always include 4768 `N2_SENSORS`,
5888 `N2_EVR_OVERVIEW` and 6245 `N2_MODULATION_OVERVIEW`, the refrigerant
circuit and the inverter, 5888 and 6245 at Fachmann level only: a run
reads them live, not from a graph, since a graph is edited by hand and can change.

## Files

- `what-ended-the-run-capped-at-1-0-before-pv006.md`: the run at 1.0 of
  2026-11-09 ended 2.1 K below `PV006`; B45, the flow or a time of 30
  minutes, and the run that tells them apart.
- `does-88-set-the-export-the-pv-controller-holds.md`: the runs of
  2026-11-07 on 88, answered no for the speed, and step 1 with its
  schedule.
- `does-the-control-act-on-a-74-no-one-renews.md`: 74 keeps its value past
  `SSYSPV030`'s five hours; whether the control acts on it is step 2.
- `pv-hot-water-charge-on-74-untested.md`: hot water rather than the store,
  once the store charge is settled.
- `what-evcc-writes-to-74.md`: stock evcc writes the draw plus the surplus,
  so counts the draw twice here; the Lambda workaround writes the export,
  clamped at 0. Nothing on 4108.

## Outside this folder

- `controller-behavior-when-glt-values-stop-unknown`: the same question for
  every register a building management system writes.
- `watch-the-request-reason-pv-in-idm-web`, done: `idm-web --watch --reason`
  reads whether a start or stop was PV's.
- `todo/README.md`: where this folder stands among the other todos.
- `does-a-low-surplus-at-74-cap-the-speed`, done: the question that led
  here, answered no for every value written to 74.
- `power-limit-4108-semantics-unknown`, done: 4108 from the first reads to
  the cap and the run at 1.0.
- `what-a-power-cycle-does-to-74-and-the-controller`, an idea since
  2026-11-09: answered for `System Neustart`, open for a power cycle and an
  update; no run here needs it.
- `power-limit-4108-outside-pv-and-locks-4110-to-4114`, an idea: 4108 for a
  grid operator's dimming, and the locks.
- `create-the-fachmann-level-graphs`, done: the refrigerant circuit's
  channels in a graph, at Fachmann level only, for a person reading the web interface; a run reads them from
  the web watch.
