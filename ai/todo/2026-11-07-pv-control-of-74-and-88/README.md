# PV control through 74 and 88

The runs left to do on how a consumer drives the heat pump on a PV surplus
through 74, the surplus, 88, the target, and 4108, the power limit. What is
settled, and the open questions, are in `doc/pv-control.md`.

The aim: a PV run held at low power, near the heating floor of 24 rps and
0.6 to 0.74 kW, for as long as the store takes, rather than a short run at
up to 4 kW. 4108 gives about 1.0 kW at the lowest; below that it ends the
run.

## Next, in order

1. The clamp run: 74 as the export, clamped to ±0.1 kW, every 10 s, with
   `PV011` at 0.1 min, to see whether the clamp damps the swing of
   2026-11-10 and the run passes 8 minutes
   (`the-clamp-run-with-pv011-at-0-1-min.md`).
2. Lower gains, `IV017` to `IV019`, if the clamp leaves a swing: an
   EEPROM cycle at the display each way.
3. The overnight test of 74, `does-the-control-act-on-a-74-no-one-renews.md`.
4. A PV hot water charge, `pv-hot-water-charge-on-74-untested.md`.

Unranked: `what-ended-the-run-capped-at-1-0-before-pv006.md`.

Every run watches the request reason beside its settings,
`idm-web HOST --watch 10 --reason --fachmann SETTING...`, so a start or
stop reads as PV's or a circuit's. The settings always include 4768
`N2_SENSORS`, 5888 `N2_EVR_OVERVIEW` and 6245 `N2_MODULATION_OVERVIEW`, the
refrigerant circuit and the inverter, 5888 and 6245 at Fachmann level only:
a run reads them live, not from a graph, since a graph is edited by hand and
can change.

## Files

- `the-clamp-run-with-pv011-at-0-1-min.md`: step 1 with its schedule, and
  the checks before each run.
- `does-the-control-act-on-a-74-no-one-renews.md`: step 3.
- `pv-hot-water-charge-on-74-untested.md`: step 4.
- `what-ended-the-run-capped-at-1-0-before-pv006.md`: the run at 1.0 of
  2026-11-09 ended 2.1 K below `PV006`; B45, the flow or a time of 30
  minutes, and the run that tells them apart.

## Outside this folder

- `what-evcc-writes-to-74`, done: stock evcc counts the draw twice here,
  reported in evcc-io/evcc#19002.
- `todo/README.md`: where this folder stands among the other todos.
- `idm-drive-replaces-drivepv`, done: `idm-drive` drives every run.
- `controller-behavior-when-glt-values-stop-unknown`: the question of step
  3 for every register a building management system writes.
- `what-a-power-cycle-does-to-74-and-the-controller`, an idea: open for a
  power cycle and an update; no run here needs it.
- `power-limit-4108-outside-pv-and-locks-4110-to-4114`, an idea: 4108 for a
  grid operator's dimming, and the locks.
