# A heating run on 20.24-2608 shows what it showed on 20.24-1574

2026-11-09, afternoon. A heating run watched read only, to re-check on
20.24-2608 what was measured of a run on 20.24-1574
(`recheck-control-behavior-on-20-24-2608`). Each finding holds: 1074 follows
the charge pump's signal M73, 1104 reads `ffff` while the pump is driven,
4122 follows the inverter's motor power, and the compressor starts 50 s
after the request, the pump first. The controller named the request circuit
C's, whose flow had stood 1 K below its set flow for the add-on time; A's
had not. The Fachmann level held sixty minutes from the entry under a 10 s
watch, as on 20.24-1574.

## What was recorded

|             |                                                                                                                                                                    |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Registers   | `captures/navigator-10-watch-20.24-2608-2026-11-09-1450.jsonl`: 74, 4108, 1008, 1090, 1091, 1100, 1004, 1098, 1072, 1074, 1104, 4122, 4126, 1746, 1748, 1750, 1754 |
| Web backend | `captures/navigator-10-webwatch-20.24-2608-2026-11-09-1450.jsonl`: the `system` overview, 4782 `N2_ANALOGUE_OUTPUTS`, 10263 `N2_PV_POWER`                          |
| Web backend | `captures/navigator-10-webwatch-20.24-2608-2026-11-09-1451.jsonl`: 6245 `N2_MODULATION_OVERVIEW`, on a second websocket session                                    |
| Walk        | `captures/navigator-10-webapi-20.24-2608-2026-11-09-1629.json`, 16:29 to 16:33, after the watches                                                                  |
| Interval    | 10 s, all three                                                                                                                                                    |
| User level  | Fachmann, entered at 14:51:05 (`captures/navigator-10-level-20.24-2608-2026-11-09-1451.log`, its write time), not renewed                                          |
| Span        | 14:50:52 to 16:29:04; 6245 from 14:51:12 to 15:51:22                                                                                                               |

Times are the laptop's. 590 rounds, 10030 register reads, none failed. 1770
requests of the first web watch, none failed. 363 of the second: 360
answered, the last three refused, as the level had fallen back. Software
20.24-2608 on both channels throughout. Nothing was set but the user level;
74 and 4108 stood at -0.5 and -1.0 throughout, as the noon run left them
(`doc/verification/2026-11-09-power-limit-floor.md`). The watches were
stopped at 16:29 while the compressor still ran.

| Time              | 1090             | 1091 | 1100                     |
| ----------------- | ---------------- | ---- | ------------------------ |
| 14:50:52–15:15:34 | 0, `Standby`     | 0    | 0                        |
| 15:15:44–15:42:44 | 1, `Heizbetrieb` | 1    | 1 from 15:16:34          |
| 15:42:54–15:50:04 | 8, `Abtauung`    | 0    | 0, 1 from 15:43:54       |
| 15:50:14–16:29:04 | 1                | 1    | 0, 1 again from 15:53:34 |

## The start

| Time              | 1090 | 1074   | 1104   | 1072, l/min | 1100 | 4122, kW  |
| ----------------- | ---- | ------ | ------ | ----------- | ---- | --------- |
| 14:50:52–15:15:34 | 0    | `ffff` | `ffff` | 0           | 0    | 0         |
| 15:15:44–15:16:24 | 1    | 100    | `ffff` | 32.8–33.3   | 0    | 0         |
| 15:16:34          | 1    | 60     | `ffff` | 33.0        | 1    | 0.13      |
| 15:16:44–15:17:04 | 1    | 60     | `ffff` | 23.0–23.3   | 1    | 0.30–0.82 |
| 15:17:14 on       | 1    | 64–100 | `ffff` | rising      | 1    | rising    |

As on 2026-10-16 (`doc/verification/2026-10-16-charge-pump.md`): the pump's
signal rises to 100 in the round 1090 turns to `Heizbetrieb`, the
compressor starts 50 s later, and the signal drops to 60 with it. Here the
flow came in the same round as the signal, not one later. The restart after
the defrost went the same way, from 100 to 60 at 15:53:34.

## 1074 is still M73, and 1104 still does not follow it

4782 printed M73 589 times beside a 1074 read before it. 456 readings equal
the read before, 120 the read after, and 3 lie between the two in a ramp.
The other 10 differ by one point from equal reads on either side, 70
against 71 or 100 against 99: the signal moved and moved back within a
round. Every -1.0 on the page, 148 of them, stands beside `ffff` on 1074,
and no other value does.

1104 answered all 590 reads with `ffff`, at rest and while M73 stood at 60
to 100. So the table still decodes it as `DriveSignal NotDriven` while the
pump is driven, on both softwares.

## 4122 is still the inverter's figure

Each of the 195 readings of 6245 with the drive at `run` is set against the
nearer 4122 read. They differ by 0.009 kW on average, by at most 0.05 kW in
90 % of the readings and 0.15 kW in 96 %, the page printing one decimal.
The four that differ by more, at most 0.23 kW, fall where the power moved
within a round: 15:21:22 in the ramp, 15:40:32, and 15:48:22 and 15:49:42
in the defrost.

| Phase                      | Speed, rps  | `motor power`, kW | 4122, kW  |
| -------------------------- | ----------- | ----------------- | --------- |
| Heating, 15:16:52–15:17:22 | 16.0–40.8   | 0.3–0.9           | 0.30–1.09 |
| Start program, to 15:20:32 | 50.4        | 1.1               | 1.06–1.15 |
| Heating, 15:23:22–15:42:44 | 114.9–119.9 | 3.4–3.5           | 3.39–3.56 |
| Defrost, 15:44:02–15:50:04 | 7.1–78.0    | 0.3–2.2           | 0.29–2.22 |

The start program held 50.4 rps for three minutes, as on 20.24-1574. The
run then rose to about 120 rps, where the run of 2026-10-16 held 101 to 113
rps. The two days differ in more than the software, so this says nothing
of a change in the control. In the defrost 4126 fell to -7.12 kW, as it
fell to -7.79 then.

10263 `N2_PV_POWER` printed `Wärmepumpe Aufnahmeleistung` within 0.05 kW of
the nearer 4122 read in 95 % of 590 readings. Its `mom./prog. Leistung
Heizen`, the draw the PV control expects of a heating run, read 0.8 kW to
about 15:00 and 0.7 kW after, while the run drew 3.5.

## The request reason outside a PV run

The `system` overview's `heatpump` read `operationMode` 1 and `info` 513,
bits 1 and 512, `RD_REQ_HK_C`, from the round 1090 turned to `Heizbetrieb`.
The web interface printed "Anforderung HK C", read by hand by 15:18. In the
defrost it read `operationMode` 8 and had no `info`, the way it has none at
rest; back in heating, 513 again. The overview is asked about 2 s before
the registers in a round, and its mode changed in the same round as 1090
each time.

| From     | `operationMode` | `info` | Circuit A, `activeMode`, pump | Circuit C, `activeMode`, pump |
| -------- | --------------- | ------ | ----------------------------- | ----------------------------- |
| 14:51:02 | 0               | none   | 0, off                        | 1, off                        |
| 14:59:32 | 0               | none   | 1, on                         | 1, on                         |
| 15:15:42 | 1               | 513    | 1, on                         | 1, on                         |
| 15:42:52 | 8               | none   | 1, off                        | 1, off                        |
| 15:50:12 | 1               | 513    | 1, off                        | 1, off                        |
| 15:53:12 | 1               | 513    | 1, on                         | 1, on                         |

Circuit A had `activeMode` 1 and its pump on from 14:59:32, yet `info` never
carried its bit, 128. A circuit requests heat once its flow has stood 1 K or
more below its set flow for its add-on time, `HKA59` and `HKC59`
`N2_HC_ADD_ON_TIME_HEATING`, 15 min for both in the walk; the 1 K is the
operator's account, and the Kunde walk shows no setting of it. Both
circuits' time program starts at 15:00. C's flow, in the overview, stood so
from 14:59:32 on, 19.9 against 34.2 °C then and 32.3 against 34.2 at
15:15:32, and the request came at 15:15:42, 16 minutes later. A's flow came
within 1 K at 15:05:22, after less than six minutes, and stood 0.5 K above
its set at the request. From 15:16:32, with the heat pump running, A's flow
stood more than 1 K below again, to the end of the watch, 73 minutes, and
its bit still did not appear: either a circuit does not request while the
heat pump runs, or `info` holds only the request that started it.

## The Fachmann level held sixty minutes

Entered at 14:51:05 and not entered again, the level answered 6245 every
10 s until 15:51:02 and refused it from 15:51:12: sixty minutes, as on
20.24-1574. On 20.24-2608 it fell back after 8 and 10 minutes on
2026-11-05 and held 73 minutes on 2026-11-06, left by hand
(`doc/verification/2026-11-05-software-update.md`), so sixty minutes is not a fixed timeout there
either. Nothing was set at the display meanwhile; the web interface was
only looked at.

## What this does not re-check

- **Graph channels 112 and 365**, `N2_THERMAL_PERFORMANCE_POLY` and
  `…_FLOWSENSOR` since the update. No graph the controller offers holds
  them: the walk's graphs 1, 100 and 101 hold channels 1, 5, 7, 363, 183,
  184 and 10000 to 10004, and 112 and 365 appear only in the `traverse`
  group `N2_HEATQUANTITIES`. Plotting them takes a new graph, which is a
  `save`.
- **The display.** The request reason was read off the web interface, not
  the display.
- **The stop.** The run went on past the watches; the stop's order, the
  compressor first and the pump's signal one round later, was measured on
  2026-10-16 only.
- **The floor** (`doc/verification/2026-11-05-floor.md`) and a hot water
  charge (`doc/verification/2026-10-01-charge.md`).

## Reproducing

    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
    cabal run idm-dump -- HOST --watch 10 1090 1091 1100 1072 1074 1104 4122 4126 > watch.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --watch 10 --reason 4782 10263 > webwatch.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --watch 10 6245 > webwatch-6245.jsonl

across the start of a heating run.
