# 4108 does not survive a restart; what a restart leaves behind

2026-11-07, evening. One write to 4108 `Leistungsbegrenzung Wärmepumpe`, then a
restart of the controller from its display, `System Neustart`, to learn whether
4108 is held in EEPROM. Revision 12 of 812170 prints 4108 without the star that
marks an EEPROM register, which is all the table's `volatile` rested on
(`power-limit-4108-semantics-unknown`).

3.0 written to 4108 read back, held without renewal for six minutes, and read
-1.0, the default, from the first read after the restart on. The controller
loads what it holds in EEPROM when it starts, so 4108 is not held there: the
table's `volatile`, and the cost `'Free` of the target `HeatPumpPowerLimit`,
stand. A consumer that wants a limit must write it again after a restart.

## What was recorded

Every 10 s from 21:20:50 to 21:53:01 over Modbus 74, 88, 4108, 1008, 1090, 1091,
1100, 1074, 4122, 1004 and 1098, 2134 reads, of which the 11 in the restart
failed (`captures/navigator-2.0-watch-20.24-2608-2026-11-07-2120.jsonl`). Every
10 s over the same span over the web 6245 `N2_MODULATION_OVERVIEW`, 10263
`N2_PV_POWER` and 12763 `N2_GLTMON`, 582 requests, of which the 3 in the restart
failed (`captures/navigator-2.0-webwatch-20.24-2608-2026-11-07-2120.jsonl`). The
one write read back
(`captures/navigator-2.0-write-20.24-2608-2026-11-07-2133.log`). A walk of the
web interface at Fachmann level before the restart, from 21:22 to 21:33, and one
after it, from 21:41 to 21:52
(`captures/navigator-2.0-webapi-20.24-2608-2026-11-07-2122.json`,
`…-2026-11-07-2140.json`). The web interface was at Fachmann level from 21:21:27
to the restart and from 21:40:48 to 21:52:51
(`captures/navigator-2.0-level-20.24-2608-2026-11-07-2120.log`). Software
20.24-2608 on both channels throughout, before and after the restart.

## Before

At 21:20:50, 1090 read `Standby`, 1091 `Keine Anforderung`, 1100 `Aus`, 4122
0.0, 1004 0, 1098 `nicht gesperrt`, B38 29.5 °C, 88 0.0, 74 -0.5, written at
18:56:32 (`doc/verification-2026-11-07-pv-target-ignored.md`), and 4108 -1.0.
12763 listed 4108 as `Leistungsbegrenzung (kW)`, -1.0, with a `GLT Value` of -1.
No setting in the walk names the power limit; the translations'
`N2_POWER_LIMIT_HEATPUMP` appears nowhere in it.

## The write and the restart

| Time           | What happened                                                           |
| -------------- | ----------------------------------------------------------------------- |
| 21:33:20       | 3.0 to 4108, read back; 12763 lists it at 3.0 with a `GLT Value` of 3.0 |
| 21:33:20–39:30 | 4108 reads 3.0 at every read, 38 of them; nothing written               |
| about 21:39:27 | the log's `T20ERR_USER_SHUTDOWN`                                        |
| 21:39:31       | the last answers of both channels                                       |
| 21:39:40       | both connections closed by the controller                               |
| about 21:39:41 | the log's `T20ERR_NEUSTART_1`                                           |
| 21:39:50       | Modbus answers again; 74 0.0, 88 0.0                                    |
| 21:39:51       | the web interface answers again, at Kunde level                         |
| 21:39:52       | 4108 -1.0; 1008, 4122 -1.0 and 1090, 1091, 1100, 1004, 1098 -1          |
| 21:40:10–40:11 | 1090, 1091, 1100, 1004, 1098 and 4122 read as before the restart        |
| 21:40:20       | 1008 29.4 °C                                                            |
| 21:40:20–53:01 | 4108 -1.0 at every read                                                 |

The log's times are the controller's clock, which ran 28 s ahead of the local
one at 21:40:30 and at 21:52:54; the table gives them in local time. Neither
watch had to be restarted: both lost their connection and made it anew. Between
the controller answering and its values standing, Modbus returned the sentinels
of an unfitted sensor for 20 to 30 s, with status `ok`; `decode` reads them as
`NoValue` or `NoValueOr`.

## What else the restart changed

- **74** came back 0.0 rather than -0.5, and 12763 listed 74 and 88 with an
  empty `GLT Value`, as after the restart of 2026-11-06
  (`doc/verification-2026-11-07-pv-target.md`, "Before"). The web interface's
  energy flow, which printed 74 as the grid's -0.5 before, printed no grid
  after.
- **The user level** fell from Fachmann to Kunde. 6245 and 12763 answered "not
  accessible" until it was entered again.
- **The settings stood.** Of the 340 requests of each walk, 33 drew a different
  answer, and none of them through a setting's value: the clock, the log, live
  temperatures and powers, the network page, which added
  `Kunden registriert: 2`, the notices' times, the statistics and the graphs.
  The PV menu's `PV001` to `PV031` and the modulation's `IV002` to `IV023` read
  alike.
- **The notices** were the same two, `N2_USERLEVELACTIVE`, raised anew by the
  entry at 21:40:48, and `N2_ERR_DHCPCONF` of 2026-09-15; `idm-web --status`
  lists the second only at Fachmann level.
- **The heat quantities of 2026-11-06 grew** though the compressor stood:
  heating from 45.27 to 47.23, hot water from 4.98 to 5.36, defrost from 1.42 to
  1.75. The row of 2026-11-07, which reads 773.9 for heating and does not fit a
  day, grew by the same 1.96, 0.38 and 0.33, and the weekly averages by a
  seventh of them. The energy counters 1746 to 1762 were not read.
- **The graphs' history was laid out anew.** The 30-hour graphs 1, 2 and 100
  cover the same span with points at other times. The 8-day graphs 1, 2 and 100
  began on 2026-10-30 at 23:50 before and on 2026-10-31 at 23:58 after, a day
  later; the 8-day graph 101, the PV channels, began on 2026-11-06 at 05:16
  before and on 2026-11-05 at 21:06 after, with 177 points rather than 41.

The controller's log shows the restart of 2026-11-06 the same way, a
`T20ERR_USER_SHUTDOWN` at 20:41:06 and a `T20ERR_NEUSTART_1` at 20:41:20; the
restart of the update on 2026-11-05 shows only the second.

## What it shows

- **4108 is volatile.** The EEPROM keeps what a restart loads; 4108 came back as
  its default.
- **4108 does not fall back while no one writes it,** for six minutes at least:
  the controller does not drop it as stale in that time.
- **A restart from the display drops every value a building management system
  wrote** that this run watched, 74, 88 and 4108, and Modbus answers about 10 s
  after the connection closes, with sentinels for another 20 to 30 s.

## What it does not settle

- Whether a power cycle at the mains switch, or the restart an update makes,
  differs from `System Neustart`
  (`what-a-power-cycle-does-to-74-and-the-controller`).
- Whether 4108 caps the draw, and in which modes
  (`power-limit-4108-semantics-unknown`).
- What changed the heat quantities and the graphs' history.

## Reproducing

At Kunde level for Modbus, the compressor off:

    cabal run idm-dump -- HOST --watch 10 74 88 4108 1008 1090 1091 1100 1074 4122 1004 1098 > watch.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
    IDM_PIN=... cabal run idm-web -- HOST --watch 10 6245 10263 12763 > webwatch.jsonl
    IDM_PIN=... tools/webprobe.py HOST > before.json
    cabal run idm-write -- HOST 4108 3.0

Then, after some minutes, `System Neustart` on the display, and once 1008 reads
a temperature again:

    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
    IDM_PIN=... tools/webprobe.py HOST > after.json
    IDM_PIN=... cabal run idm-web -- HOST --leave-fachmann
