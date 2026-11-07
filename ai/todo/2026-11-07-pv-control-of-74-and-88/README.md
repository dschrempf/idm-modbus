# PV control through 74 and 88

How a consumer drives the heat pump on a PV surplus: what it writes to 74,
the surplus, and 88, the target, and what the controller does with them.
The sources and the reading of the controller are in `doc/pv-control.md`;
this folder holds the runs left to do.

## Where it stands

Settled on the machine, 2026-11-05 and 2026-11-06:

- 74 is in kW, and the controller adds its own draw back: 0 keeps a running
  charge going, only a negative value ends it.
- A constant 74 caps nothing. A PI controller, gains `IV017` to `IV019`,
  sets the speed on the mean of 74 over `PV011` less a target of 0.
- 74 written as a meter's export did not hold a run; part of the overshoot
  came from a mean still holding the start's surplus.

Open: whether 88 is that target, what starts, stops and holds off a run,
and what the controller does with a value no one renews.

## Next, in order

1. The 88 run, on a day the pump stands idle and the store is cool.
2. The same run with `PV011` at 0.5 min.
3. If 88 is the target: a start on 88 alone, and 88 in the overnight test.
4. The overnight test of 74, then the power cycle that ends its watch.
5. A PV hot water charge.

## Files

- `does-88-set-the-export-the-pv-controller-holds.md`: runs 1 to 3, with
  the schedules and what each outcome means.
- `does-a-low-surplus-at-74-cap-the-speed.md`: the question that led here;
  answered no for a constant 74, the rest carried into the 88 run.
- `what-a-power-cycle-does-to-74-and-the-controller.md`: what a restart
  leaves behind, 74 among it; ends the overnight watch.
- `pv-hot-water-charge-on-74-untested.md`: hot water rather than the store,
  once the store charge is settled.

## Outside this folder

- `controller-behavior-when-glt-values-stop-unknown`: every register a
  building management system writes; its test of 74 overnight is step 4.
- `power-limit-4108-semantics-unknown`: a cap in kW, the lever left if 74
  and 88 cannot hold a run low.
- `run-the-open-todos-in-six-sessions`: the schedule of the 2026-10-15
  todos; its session 6a is this folder's work.
