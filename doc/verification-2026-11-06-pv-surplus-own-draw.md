# The controller adds its own draw back to the PV surplus at 74

2026-11-06. With the heating store charged on a surplus written to 74, the
run held at full speed past the compressor's minimum runtime with 1.7 kW
written against a draw of 3.9 kW, and again with 0 written; with -0.5
written it ramped down within 30 s and stopped after 72 s. The controller
weighs 74 plus its own draw against that draw, as a surplus measured at the
grid needs: 0 means the PV covers exactly what the pump draws and keeps a
running charge running, and only a negative value, import, ends it. Before
that, 1.0 written for 12 minutes did not start the pump from standstill;
1.7 did.

## What was set

As on 2026-11-05 (`doc/verification-2026-11-05-pv-surplus.md`): `PV008` at
`N2_GLTSF`, `PV001` Yes, `PV002` No, `PV013` Always, `PV011` 2.0 min.
The capture after the run shows one more, read at Fachmann level and in no
capture before: `N2_PV_HEATING_HYSTERESIS`, setting 13300, 4 K.
`PV006` `N2_HEATING_BUFFER_MAX_TEMP`, a Kunde setting, was changed by hand at
the display, at one EEPROM cycle each, to leave the run room before the store's maximum
ended it:

| Time          | `PV006`     |
| ------------- | ----------- |
| before 11:02  | 35 to 40 °C |
| 11:29:33      | 40 to 45 °C |
| after the run | 45 to 40 °C |

The web interface was at Fachmann level from 11:04:38, entered by `idm-web`
(`captures/navigator-10-level-20.24-2608-2026-11-06-1104.log`), for the
speed. Nothing but 74 was written to a register.

## What was recorded

Every 10 s from 11:02 over Modbus 74, 1008, 1090, 1091, 1100, 1074, 4122,
1004 and 1098, 3168 reads to 12:00 and none failed
(`captures/navigator-10-watch-20.24-2608-2026-11-06-1102.jsonl`). Every
10 s from 11:04 to 11:48 over the web 6245 `N2_MODULATION_OVERVIEW`, for the
compressor's speed and motor power, and 10263 `N2_PV_POWER`, the PV page,
522 requests and none failed
(`captures/navigator-10-webwatch-20.24-2608-2026-11-06-1104.jsonl`). The
writes, by `idm-write` once a minute and at each change of value, 38 and
none failed (`captures/navigator-10-write-20.24-2608-2026-11-06-1102.log`).
The web backend after the run, at Fachmann level, with `PV006` back at
40 °C (`captures/navigator-10-webapi-20.24-2608-2026-11-06-1148.json`).

## The run

At 11:02, 1090 read `Standby`, 1091 `Keine Anforderung`, 1100 `Aus`, 1098
`nicht gesperrt`, 74 0.0, B38 29.85 °C at 7.3 °C outdoors. A hot water
charge had ended shortly before.

| Time     | 74   | What happened                                                    |
| -------- | ---- | ---------------------------------------------------------------- |
| 11:02:48 | 1.0  | written every minute; the PV page's `Überschuss` reads 1.0 kW    |
| 11:15:23 | 1.7  | no request in 12.5 min at 1.0                                    |
| 11:16:35 |      | 1090 `Heizbetrieb`, 1091 `Anforderung`                           |
| 11:17:25 |      | 1100 `Ein`; the start program, 50.4 rps, 4122 1.15 kW on average |
| 11:21:32 |      | the speed climbs, 120 rps by 11:22:34                            |
| 11:22:34 |      | 4122 3.6 to 4.1 kW, 3.87 on average, until 11:31:30              |
| 11:27:25 |      | `WP010`'s 10 min of runtime passed; the run holds                |
| 11:28:06 | 0.0  | the run holds at 120 rps                                         |
| 11:31:12 | -0.5 |                                                                  |
| 11:31:32 |      | 119.1 rps, then 112, 106, 93, 81; 4122 down to 2.19 kW           |
| 11:32:24 |      | 1090 `Standby`, 1091 `Keine Anforderung`, 1100 `Aus`, 4122 0.0   |
| 11:37:15 | -0.5 | the last write                                                   |

B38 rose from 29.8 to 37.2 °C and peaked at 37.8 °C after the stop, short
of `PV006` throughout. 4122 summed over the run is 0.74 kWh. 1004 read 0
throughout.

The PV page printed 74 as written as `Überschuss`, -0.5 included, never 74
plus the draw. `Wärmepumpe Aufnahmeleistung` followed 4122 and 6245's motor
power. `mom./prog. Leistung Heizen` read 0.8 kW, 0.9 from 11:27 on, and did
not follow the draw; `mom./prog. Leistung Vorrang` read 1.6 kW throughout.

## What it shows

- **The controller adds its own draw back.** 812184 has a store charge stop
  once the compressor's minimum runtime has passed and the surplus is below
  the draw. Weighed as written, 1.7 and 0 are both far below 3.9 kW, and
  the run held past `WP010` on both, at 1.7 for 41 s and at 0 for 3 min;
  on 2026-11-05, at 3.0 against 3.8 kW, it held 9 min past it.
  Weighed as 74 plus the draw, 1.7 is above it, 0 equals it, and -0.5 is
  below it, and the run ended on -0.5 alone.
- **74 stops a running charge.** On 2026-11-05 the run ended at `PV006`
  with the draw cut from 3.74 kW to 0 between two reads. On -0.5 the speed
  fell from 120 to 81 rps over 50 s first; the controller acts on 74 while
  it runs.
- **0 is not "no surplus".** To a running charge it reads as a surplus
  exactly covering the draw. A consumer writes the meter's export as it is,
  negative for import, and a value below 0 to end a charge.
- **A constant surplus does not cap the speed.** With 1.7 written, the run
  went from its start program to 120 rps, as with 3.0 on 2026-11-05: 74 plus
  the draw always exceeds the draw, so the controller climbs.
- **1.0 does not start a charge from standstill; 1.7 does.** The PV page's
  `mom./prog. Leistung Heizen`, 0.8 kW, is not the whole threshold. Its
  `Vorrang`, 1.6 kW, lies between the two; so might 0.8 plus `PV015`'s
  shift, which 812184 names and no user level shows.

Seen at the display by eye and not captured: the hot water charge that
ended before 11:02 left the pump in standby with 74 at 0 and B38 below
`PV006`. 0 did not carry it over into a store charge.

## What the run does not settle

- **The start threshold.** Between 1.0 and 1.7 kW, at 7.3 °C outdoors and
  B38 near 30 °C.
- **Whether the controller holds a run at a surplus.** Writing the target
  minus 4122 every minute would show whether the draw settles near the
  target; step 2 of `does-a-low-surplus-at-74-cap-the-speed`, not run.
- **What happens when the writes stop.** 74 stands at -0.5 since 11:37:15.

## Reproducing

With `PV008` and the PV menu as above, at Kunde level for Modbus:

    cabal run idm-dump -- HOST --watch 10 74 1008 1090 1091 1100 1074 4122 1004 1098 > watch.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
    IDM_PIN=... cabal run idm-web -- HOST --watch 10 6245 10263 > webwatch.jsonl
    cabal run idm-write -- HOST 74 1.7     # every minute, until 10 min past the compressor's start
    cabal run idm-write -- HOST 74 0       # every minute, 3 min
    cabal run idm-write -- HOST 74 -0.5    # every minute, until it stops
    IDM_PIN=... cabal run idm-web -- HOST --leave-fachmann
