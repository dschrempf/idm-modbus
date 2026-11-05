# The controller reads the PV surplus at 74 in kW

2026-11-05. With the PV signal set to building management and the PV menu
set to charge the heating store, 3.0 written to 74,
`Aktueller PV-Überschuss`, every minute started the heat pump within two
minutes, on a machine that had no request of its own. Read as watts, 3.0 is
far below the 0.7 kW the controller's PV page gave as the draw it weighs a
surplus against, so the controller reads 74 in kW, as 812170 and 812184
print. The charge ran on the compressor alone until the heating store, B38,
reached `PV006`'s 35 °C, and stopped there while 74 still held 3.0.

## What was set

By hand at the display, at Fachmann level, before the run, and left so
after it (`captures/navigator-2.0-webapi-20.24-2608-2026-11-05-2108.json`):

| Setting                                | Before    | After      |
| -------------------------------------- | --------- | ---------- |
| `PV008` `SSYSPVSIGNAL`, `N2_PV_SIGNAL` | `N2_NONE` | `N2_GLTSF` |
| `PV001` `N2_CHARGE_HEATING_BUFFER`     | –         | Yes        |
| `PV006` `N2_HEATING_BUFFER_MAX_TEMP`   | –         | 35 °C      |
| `PV002` `N2_DHW_HEATING`               | –         | No         |
| `PV013` `N2_HEATLIMIT_SKIP`            | –         | Always     |

The PV menu is hidden while `PV008` is `N2_NONE`, so the before column is
empty but for `PV008` (`captures/navigator-2.0-webapi-20.24-2608-2026-11-05-1859.json`).
The others read their defaults: `PV011` `N2_PVTIMECONST` 2.0 min, `PV003`
`N2_PV_FLOOR_HEATING` 0.0 K, `PV007` `N2_PV_PEAK_POWER` 5.0 kW. `PV010` and
`PV015` appear at no level; 812184 says `PV010` applies to the 0–10 V and
S0 signals only. `SSYSPV030` read 1.0 kW and `SSYSPV031` No, as at 18:59.

Each write cost no EEPROM cycle, 74 being volatile; the settings above cost
one each.

## What was recorded

Every 10 s from 21:04 to 21:42, over Modbus 74, 1008, 1090, 1091, 1100,
1074, 4122, 1004 and 1098, 2070 reads and none failed
(`captures/navigator-2.0-watch-20.24-2608-2026-11-05-2103.jsonl`). The
writes, by `idm-write` from a second Modbus connection while the watch
polled, 25 and none failed, each line after the laptop's time
(`captures/navigator-2.0-write-20.24-2608-2026-11-05-2114.log`). The web
backend before and after the run
(`…-2108.json`, `…-2138.json`). The PV page, `N2_PV_POWER`, setting 10263,
was read by `idm-web --show` at 21:08, 21:14 and 21:20; those reads were
printed, not kept.

## The run

At 21:04, 1090 read `Standby`, 1091 `Keine Anforderung`, 1100 `Aus`, 1098
`nicht gesperrt`, B38 27.5 °C at 4.0 °C outdoors. Circuit C called for heat
from the store; the heat pump had no request of its own.

| Time     | What happened                                                       |
| -------- | ------------------------------------------------------------------- |
| 21:14:16 | 74 written 3.0; the PV page's `Überschuss` reads 3.0 kW at once     |
| 21:15:30 | 1090 `Heizbetrieb`, 1091 `Anforderung`, 1074 to 100 %               |
| 21:16:20 | 1100 `Ein`                                                          |
| 21:16:20 | 4122 0.2 to 1.2 kW, 1.05 on average, until 21:20: the start program |
| 21:20:40 | 4122 rises past 3.0 kW within a minute                              |
| 21:22    | 4122 3.54 to 4.05 kW, 3.65 on average, until the stop               |
| 21:35:29 | B38 35.0 °C                                                         |
| 21:35:40 | 1100 `Aus`, 1090 `Standby`, 1091 `Keine Anforderung`, 4122 0.0      |
| 21:37:51 | 74 written 0.0, after three minutes off with 3.0 standing           |

B38 rose from 27.5 to 35.0 °C. 4122 summed over the run is 0.98 kWh.
`Wärmepumpe Aufnahmeleistung` on the PV page followed 4122: 1.2 kW at 21:20
against 1.25. No notice was raised, 1004 read 0 throughout, and the second
heat generator's runtime stayed at 0.0 h.

## What it shows

- **74 is in kW.** The first write was on the PV page as `Überschuss` 3.0 kW
  at once, and 74 seconds later the heat pump asked for heat. 812184 has
  the pump start once the surplus, averaged over `PV011`, exceeds the
  "momentan / prognostizierte Leistungsaufnahme", which the page printed as
  `mom./prog. Leistung Heizen` 0.7 kW, 0.8 kW once running.
- **The threshold is on the page, not at 4122.** With `PV008` set, 4122
  still read 0.0 at standstill, before the run and after it. The forecast
  the surplus is weighed against is the page's figure only.
- **The heating store's maximum ends the charge.** The compressor stopped
  eleven seconds after B38 reached `PV006`'s 35 °C, while 74 held 3.0, and
  stayed off for the two minutes the surplus stood after.
- **A volatile `FLOAT` round-trips byte for byte.** Each of the 24 writes of
  3.0 read back `00004040`, the 0.0 read back `00000000`.
- **A write beside a polling watch works.** Two Modbus connections, the
  watch's and each write's, stalled nothing.

## What the run does not settle

- **Whether 74 includes the pump's own draw.** The draw rose past the 3.0
  kW surplus to 4.05 kW and stayed there. Either the controller adds its own
  draw back to 74, which a surplus measured at the grid needs and which
  `PV010` "Überschuss" does for the 0–10 V and S0 signals, or it does not
  size the run to the surplus at all. A write between the page's threshold
  and the draw, such as 1.5 kW, tells the two apart: in the first case the
  run holds; in the second it may stop once the draw exceeds the surplus
  and the compressor's minimum runtime has passed. `T25xPV_AVAILPOWER`,
  graph channel 183, may say directly, but no graph holds it.
- **What happens when the writes stop.** 74 was set back to 0 by hand.
- **What a lower surplus does to the speed.** 3.0 kW is above anything the
  machine draws at this lift, so the run says nothing of modulating to a
  surplus.

## Reproducing

With `PV008` and the PV menu as above, at Kunde level:

    cabal run idm-dump -- HOST --watch 10 74 1008 1090 1091 1100 1074 4122 1004 1098 > watch.jsonl
    cabal run idm-write -- HOST 74 3.0     # every minute, until B38 reaches PV006
    IDM_PIN=... cabal run idm-web -- HOST --show 10263
    cabal run idm-write -- HOST 74 0
