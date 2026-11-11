# The PV control

What the controller does with a PV surplus written to 74, and with the two
registers beside it that bear on a PV run, the target at 88 and the power
limit at 4108. Every claim cites the run that measured it; a claim of a
source alone says so. All runs so far charged the heating store, on software
20.24-2608.

## The path

812184 and 812170 §4.3.10 describe it: a building management system writes
the surplus to 74, in kW, and the pump starts "sobald der PV-Überschuss höher
ist als die Aufnahmeleistung". It takes, besides Modbus TCP, `PV008` at
"Gebäudeleittechnik/Smartfox", a setting no register reaches. The PV menu,
`PV001` to `PV031`, is not on Modbus either
([sources.md](sources.md#the-supporting-documents)). The settings that
matter here:

| Setting                            | What it is                                                   | Here                              |
| ---------------------------------- | ------------------------------------------------------------ | --------------------------------- |
| `PV006`                            | the heating store's maximum for a PV charge                  | 35 to 40 °C                       |
| 13300 `N2_PV_HEATING_HYSTERESIS`   | a charge is allowed once the store is this far below `PV006` |                                   |
| `PV011` 10389                      | the interval 74 is averaged over                             | 2.0 min; 0.1 min since 2026-11-10 |
| `PV015` 10396                      | a shift of the forecast draw                                 | 0                                 |
| `IV017` to `IV019`, 10403 to 10417 | the gains, P, I and D                                        | 5.0, 10.0, 0.0                    |

The compressor's minimum runtime, 5412, and minimum standstill, 5419, are
in [heat-pump.md](heat-pump.md#a-start-and-a-stop).

The PV page, 10263 `N2_PV_POWER`, prints 74 as `Überschuss` and the forecast
the surplus is weighed against as `mom./prog. Leistung Heizen`, 0.7 to 0.8
kW at rest. 4122 reads 0.0 at standstill; the forecast is on the page alone
([2026-11-05-pv-surplus](verification/2026-11-05-pv-surplus.md)). While a PV
run stands the request reason reads `RD_REQ_PV`
([web-backend.md](web-backend.md#the-request-reason)).

## What 74 is

**A surplus in kW.** 3.0 written to a machine with no request of its own
started a store charge within two minutes, and the charge ran with 74 at 3.0
until the store reached `PV006`
([2026-11-05-pv-surplus](verification/2026-11-05-pv-surplus.md)).

**The meter's export, as it is.** The controller adds its own draw back to
74, as a surplus measured at the grid needs; the help text of `PV010` says so
for an "Excess" signal. A running charge held past the minimum runtime with
1.7 and with 0 written against a draw of 3.9 kW, and stopped within 72 s of
-0.5. So 0 is not "no surplus": to a running charge it is a surplus exactly
covering the draw. A value below 0 ends a charge
([2026-11-06-pv-surplus-own-draw](verification/2026-11-06-pv-surplus-own-draw.md)).

**Weighed as its mean over `PV011`**, for the start, the speed and the stop
alike, so a change at 74 reaches the controller as a ramp
([2026-11-06-pv-surplus-loop](verification/2026-11-06-pv-surplus-loop.md)).

## What starts a run

812184: a mean surplus above the forecast draw, shifted by `PV015`. Measured:
1.0 against a forecast of 0.8 kW started nothing in 12 minutes; a mean of
about 1.0 against 0.7 kW did, and one of about 1.2 against 0.7 kW did within
71 s. A margin of about 0.3 kW over the forecast fits all three; `PV015` is
0, so it is not that
([2026-11-06-pv-surplus-own-draw](verification/2026-11-06-pv-surplus-own-draw.md),
[2026-11-06-pv-surplus-loop](verification/2026-11-06-pv-surplus-loop.md),
[2026-11-07-pv-target](verification/2026-11-07-pv-target.md)).

The compressor and its start program follow the request as in any other
run ([heat-pump.md](heat-pump.md#a-start-and-a-stop)).

**A PV start waits 30 minutes after a PV stop.** A request came 29 min 59 s
after a PV stop, with 2.0 standing at 74 for the 20 minutes past the
standstill of 5419; on 2026-11-06 none came from 9 to 19 minutes after one
([2026-11-07-pv-target](verification/2026-11-07-pv-target.md)). No source
names the setting.

A power limit at 4108 of 1.0 to 1.5 kW written before the start does not
hold it off ([below](#the-power-limit-at-4108)).

## What sets the speed

The help texts name a PID controller per mode, `N2_CA20PV_PID_HEAT_Y`,
`…_PRIO_Y` and `…_COOL_Y`, and a target consumption, `N2_PV_POWERTARGET`.
The PV menu at Fachmann level holds one set of gains, `IV017` to `IV019`;
with D at 0 it is a PI controller. Whether `IV018` is a gain or a reset
time, and the units of either, no source states.

The runs read as such a controller on the error "mean of 74 over `PV011`",
bounded by the heating floor, 24 rps, and the top, 120 rps, which is
`IV002` at its 100 %; whether a lower `IV002` caps a PV run is untested
([heat-pump.md](heat-pump.md#the-compressors-speed-and-draw)):

- **A constant above 0 drives the speed to the top**, from the start program
  to 120 rps: 74 plus the draw always exceeds the draw
  ([2026-11-06-pv-surplus-own-draw](verification/2026-11-06-pv-surplus-own-draw.md)).
- **A mean of 0 holds the speed where it is**: the start program's 50.4 rps
  for nine minutes, or 120 rps for three
  ([2026-11-07-pv-target-ignored](verification/2026-11-07-pv-target-ignored.md)).
  The integral dominates; a proportional term alone has nothing to hold with
  at an error of 0.
- **A meter-style 74 overshoots.** Written as a meter reads it, with `PV011`
  at 2 minutes, the speed climbed from the start program to the top while
  the mean was still positive, and fell back once it turned; the run ended
  before the minimum runtime
  ([2026-11-06-pv-surplus-loop](verification/2026-11-06-pv-surplus-loop.md),
  [2026-11-07-pv-target](verification/2026-11-07-pv-target.md)). With
  `PV011` at 0.1 min it no longer ran to the top but swung between about 35
  and 95 rps, some 90 s from peak to peak: the lag left is the feed's, 74
  written every 10 s from a 4122 read every 10 s, and the gains are too high
  for it ([2026-11-10-pv-loop-at-0-1-min-swings](verification/2026-11-10-pv-loop-at-0-1-min-swings.md)).
- **How long the top holds once the mean turns is not explained**: 20 s, 10
  s and 100 s in three runs.

No value written to 74 alone holds a run at low power past the minimum
runtime. 4108 does.

## What stops a run

812184: available PV power below the requested, after the minimum runtime.
The stops measured:

| Run                                                                       | After       | Speed, rps  | 74                                     | Ended by                                  |
| ------------------------------------------------------------------------- | ----------- | ----------- | -------------------------------------- | ----------------------------------------- |
| [2026-11-05](verification/2026-11-05-pv-surplus.md)                       |             | top         | 3.0                                    | the store at `PV006`                      |
| [2026-11-06, morning](verification/2026-11-06-pv-surplus-own-draw.md)     | past 10 min | 81, falling | -0.5, mean negative 72 s               | the mean                                  |
| [2026-11-06, evening](verification/2026-11-06-pv-surplus-loop.md)         | 8 min 10 s  | floor       | meter-style, mean back to 0 from below | ?                                         |
| [2026-11-07, noon](verification/2026-11-07-pv-target.md)                  | 8 min 0 s   | 60, falling | meter-style, mean -1.23                | ?                                         |
| [2026-11-07, noon](verification/2026-11-07-pv-target.md)                  | 10 min 21 s | floor       | 0, 88 at +1.0                          | the minimum runtime                       |
| [2026-11-07, evening](verification/2026-11-07-pv-target-ignored.md)       | 10 min 10 s | 50.4        | 0                                      | the minimum runtime                       |
| [2026-11-07, late](verification/2026-11-07-power-limit.md)                | 5 min 10 s  | 112.5       | 2.0                                    | 4108 at 0.8                               |
| [2026-11-08](verification/2026-11-08-power-limit-cap.md)                  | 46 min 30 s | 52–59       | 2.0                                    | the store at `PV006`, 4108 at 1.5         |
| [2026-11-09, noon](verification/2026-11-09-power-limit-floor.md)          | 17 min 30 s | 38          | 2.0                                    | 4108 at 0.9                               |
| [2026-11-09, evening](verification/2026-11-09-power-limit-held-at-1-0.md) | 30 min 50 s | 37          | 2.0                                    | ?, 4108 at 1.0, store 2.1 K below `PV006` |
| [2026-11-10](verification/2026-11-10-pv-loop-at-0-1-min-swings.md)        | 8 min 0 s   | 82, rising  | meter-style, mean -0.18                | ?                                         |

What they show:

- **The store's maximum ends a run** that nothing else ends, with 74 still
  positive.
- **0 at 74 ends a run at the minimum runtime** from the start program's
  speed, the store 9 K below `PV006`; at the top it held one past it.
- **A meter-style run ends at about 8 minutes**, its mean at or below 0,
  three times, before the 10 minutes of 5412, whose help text excepts only a
  fault. A constant 0 at 74 held to 5412, and a negative mean of 40 s at 6
  to 7 minutes did not end a run.
- **4108 below 1.0 ends a run at once**, within 9 s, the minimum runtime
  notwithstanding.

Not settled: what "requested" is, why the minimum runtime does not hold, why
0 held one run and ended another, and what ended the run capped at 1.0
(`what-ended-the-run-capped-at-1-0-before-pv006`).

## The PV target at 88

812170 prints 88 as `PV-Zielwert (Smartfox und Solar-Log)`, a volatile
`FLOAT` in kW, default 0, beside 74; the Smartfox, for which this path was
built, has a setting "Zielwert standardmäßig „0"" for an iDM pump. The
hypothesis was that 88 is the controller's target, the export it holds the
mean of 74 at, so that a consumer writes the meter to 74 and its intent to
88: +0.5 to leave room for another load, -1.0 to charge from the grid.

It does not move the speed. With 74 at 0 and the speed steady, 88 at -1.0
for 3 minutes moved nothing, and +1.0 for 3 minutes moved nothing either; a
fall that once followed +1.0 came at the end of the minimum runtime
([2026-11-07-pv-target](verification/2026-11-07-pv-target.md),
[2026-11-07-pv-target-ignored](verification/2026-11-07-pv-target-ignored.md)).
12763 lists 88 as written, and the PV page prints nothing that follows it.
On a Navigator 2.0 a user reports no visible effect either. Whether 88
weighs in the start or the stop, or settles the loop under a meter-style 74,
is open (`pv-control-of-74-and-88`).

## The power limit at 4108

The power limit at 4108 is in
[registers.md](registers.md#4108-to-4114-the-power-limits). Beside 74 at
2.0:

| Run                                                                       | 4108 | Written          | What it did                                                                                    |
| ------------------------------------------------------------------------- | ---- | ---------------- | ---------------------------------------------------------------------------------------------- |
| [2026-11-07](verification/2026-11-07-power-limit.md)                      | 0.8  | at 3.1 kW        | ended the run within 9 s, without coming down first                                            |
| [2026-11-08](verification/2026-11-08-power-limit-cap.md)                  | 1.5  | before the start | capped the draw near 1.4 kW for 42 min, one step past the start program, to `PV006`            |
| [2026-11-09, noon](verification/2026-11-09-power-limit-floor.md)          | 1.2  | before the start | let the start program draw 1.24 to 1.30 kW, then held 1.19 on average past the minimum runtime |
|                                                                           | 1.0  | under the run    | brought the speed to 38.4 rps within 20 s and the draw to 0.98 kW                              |
|                                                                           | 0.9  | under the run    | ended the run within 8 s                                                                       |
| [2026-11-09, evening](verification/2026-11-09-power-limit-held-at-1-0.md) | 1.0  | before the start | let the start program draw up to 1.43 kW, then held 1.01 on average, 37 to 41 rps, for 26 min  |

So a limit from 1.0 to 1.5 caps a PV run after its start program and follows
a lowered value without a stop; a limit below 1.0 ends the run, however close
to the draw. The line lies between 0.9 and 1.0, above the heating floor's 0.7
kW: it is the controller's, not the compressor's. The lowest run it gives is
about 1.0 kW. A limit of 1.0 to 1.5 does not hold off a start, the request
coming about 1 min 24 s after the first write as without one; whether one
below 1.0 does is untested. The forecast on the PV page does not follow the
limit. What 4108 does outside a PV run is untested.

## A value no one renews

The register holds: 74 read -0.5 8 h 10 min after the last write
([2026-11-06-pv-surplus-own-draw](verification/2026-11-06-pv-surplus-own-draw.md)),
and a restart drops it to 0 ([modbus.md](modbus.md#a-restart)). 812184 and
the help text of `N2D_PVStaticHousepwrActive`, `SSYSPV031`, have a fallback
house consumption, `SSYSPV030`, take over "when the smart meter hasn't
delivered any new values for more than 5 hours"; here `SSYSPV031` reads No.
On a Navigator 2.0 the controller kept acting overnight on the last value
written, by an evcc user's report. What the control does with a stale 74
is open (`does-the-control-act-on-a-74-no-one-renews`).

## Sources

- **812170 rev. 12, §4.3.10**, which 812663 prints word for word, and **812184
  rev. 13, chapter 2.5**: the path, the forecast at standstill, the mean over
  `PV011`, `PV015`'s shift, and the stop rule. For Solar-Log 812184 names an
  "Aktueller Aufnahme Zielwert" the GLT path does not show.
- **The Navigator 10 sheet**: the block for the GLT path, and the Smartfox's
  own settings for an iDM pump, a target of 0 and the pump's electrical power
  at nominal speed. What the Smartfox writes to 74 is not documented.
- **The controller's help texts**
  (`captures/navigator-10-webui-20.24-2608-2026-11-05-1641/`), in its
  English: `N2D_PV_HEATING_HYSTERESIS`, `N2D_PVTIMECONST`,
  `N2D_PVCONSUMPTIONOFFSET` ("the 'Actual/Predicted Power Consumption'
  value"), `N2D_MIN_RUNTIME_COMPRESSOR` ("In the event of an error, the
  minimum running time does not apply!"), `N2D_MIN_DWELL_TIME_COMPRESSOR`,
  and `N2D_PV_SIGNAL_TYPE` ("the signal value is reduced by the electrical
  power consumption of the heat pump when it is switched on"). Names without
  a setting in any capture: the PID outputs `N2_CA20PV_PID_*_Y`,
  `N2_PV_POWERTARGET` "Target Consumption", `N2_PV_TARGET` "PV target value",
  and `N2_ELECTRIC_POWER_WITH_PVOFFSET`. iDM's other controllers name an I
  term a reset time (`N2_PID_HEAT_TN`, `N2_HC_MIXER_I`), but the cascade's
  help texts use it as a gain once.
- **The PV menu**, 10256 `N2_PV`, at Fachmann level
  (`captures/navigator-10-webapi-20.24-2608-2026-11-06-1148.json`): the gains
  `N2_MOD_POWER_CONTROL_P`, `_I` and `_D`, `float`, no unit, 0 to 1000,
  steps 0.1, 1.0 and 0.1. Their help texts are the untranslated keys.
- **The register page**, 12763: per address the controller's value and the
  last written `GLT Value`; during a run both read 74 and 88 as written.
- **The PV graph**, 101: channels 183 `T25xPV_AVAILPOWER` "akt.
  PV-Überschuss" and 184 `T25xHP_REQPOWER` "Mom/prog. Aufnahme", thinned as
  every graph is ([web-backend.md](web-backend.md#graphs)).
- **Community reports**, unverified here, in
  [sources.md](sources.md#community-work): the Home Assistant thread's 500 W
  margin and 10-minute runtime, evcc's overnight report, kodebach's on 88.

## Open

- **The loop under a clamp**, with `PV011` at 0.1 min, and lower gains if it
  still swings: whether a meter-style 74 settles at all.
- **A stale 74 overnight**: what the control does once nobody renews it.
- **A PV hot water charge on 74**, which 812184 says runs to its end however
  far the surplus falls (`pv-hot-water-charge-on-74-untested`).
- **What ended the run capped at 1.0** before `PV006`.
- **What holds a PV start off for 30 minutes**, and whether the request
  reason shows a start that waits.
- **88 under a settling loop**: a step of 88 while a meter-style 74 holds
  the run.
- **The form of `IV017` and `IV018`**, and whether the target is 88,
  `N2_PV_POWERTARGET` or both; a Fachmann walk during a run, searched for
  `CA20PV` and `POWERTARGET`, would show whether a page lists them.
