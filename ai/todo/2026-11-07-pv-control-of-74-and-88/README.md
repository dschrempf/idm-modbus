# PV control through 74 and 88

The runs left to do on how a consumer drives the heat pump on a PV surplus
through 74, the surplus, 88, the target, and 4108, the power limit. What is
settled, and the open questions, are in `doc/pv-control.md`.

The aim, a PV run held at low power near the heating floor for as long as
the store takes, is reached: 74 between 0 and +0.25 holds one at 24 rps and
0.7 kW to `PV006`, since the controller holds 74 at +0.25
(`doc/verification/2026-11-11-the-pv-control-holds-74-at-0-25.md`). What is
left is a loop fed as a meter would feed it.

## Next, in order

1. The clamp around the target: 74 as the export of a simulated PV,
   clamped to +0.15 to +0.35, every 10 s, `PV011` at 0.1 min. The clamp of
   ±0.1 around 0 never left its upper bound; around +0.25 it limits the
   integral to about 65 rps a minute either way. Whether the swing of
   2026-11-10 damps, and what PV the run holds down to. A copy of
   `schedules/pv-clamp-0-1.toml` with the bounds moved.
2. Lower gains, `IV017` to `IV019`, if it still swings: an EEPROM cycle at
   the display each way.
3. The overnight test of 74, `does-the-control-act-on-a-74-no-one-renews.md`.
4. A PV hot water charge, `pv-hot-water-charge-on-74-untested.md`.

Unranked: `what-ended-the-run-capped-at-1-0-before-pv006.md`.

## Before each run

- The pump idle, B38 at 31 °C or below: a start needs B38 below `PV006`
  less 13300, 36 °C, and the run ends at `PV006`, 40 °C.
- At least 30 minutes since the last PV stop.
- 88 reads 0.0.

At the end the driver writes its finals, 88 to 0 among them. Check that 88
reads 0.0 and stop the web watch, which leaves the Fachmann level. End a
schedule on the stop, `until = "stop"`, rather than a time, so the final
-0.5 does not end a run the controller would hold.

Every run watches the request reason beside its settings,
`idm-web HOST --watch 10 --reason --fachmann SETTING...`, so a start or
stop reads as PV's or a circuit's. The settings always include 4768
`N2_SENSORS`, 5888 `N2_EVR_OVERVIEW` and 6245 `N2_MODULATION_OVERVIEW`, the
refrigerant circuit and the inverter, 5888 and 6245 at Fachmann level only:
a run reads them live, not from a graph, since a graph is edited by hand and
can change.

## Files

- `does-the-control-act-on-a-74-no-one-renews.md`: step 3.
- `pv-hot-water-charge-on-74-untested.md`: step 4.
- `what-ended-the-run-capped-at-1-0-before-pv006.md`: the run at 1.0 of
  2026-11-09 ended 2.1 K below `PV006`; the time of 30 minutes is left,
  and the run that tells it.

## Outside this folder

- `what-evcc-writes-to-74`, done: stock evcc counts the draw twice here,
  reported in evcc-io/evcc#19002.
- `todo/README.md`: where this folder stands among the other todos.
- `idm-drive-replaces-drivepv`, done: `idm-drive` drives every run.
- `idm-drive-takes-a-new-value-without-ending-the-run`: a run steered by
  hand, as on 2026-11-11, without a drive per step.
- `controller-behavior-when-glt-values-stop-unknown`: the question of step
  3 for every register a building management system writes.
- `what-a-power-cycle-does-to-74-and-the-controller`, an idea: open for a
  power cycle and an update; no run here needs it.
- `power-limit-4108-outside-pv-and-locks-4110-to-4114`, an idea: 4108 for a
  grid operator's dimming, and the locks.
