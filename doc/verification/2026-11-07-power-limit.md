# A limit at 4108 below the draw ends a PV run at once

2026-11-07, late evening. One store charge on a constant surplus written to
74, with 4108 `Leistungsbegrenzung Wärmepumpe` written 0.8 kW once the speed
climbed, to learn whether 4108 caps the draw of a PV run near the heating
floor (`power-limit-4108-semantics-unknown`, `pv-control-of-74-and-88`).

It does not, at least not from 3.1 kW down to 0.8. The compressor
stopped within 9 s of the write, at 112.5 rps, 5 minutes 10 seconds after
its start: before the 10 minutes of the minimum runtime, 5412, with 74 at
2.0 throughout and the store 10 K below `PV006`. The request went off with
it, and 1004 reported nothing. 4108 is the first value written in these runs
that the controller acted on at once, and the first to end a run before its
minimum runtime on a surplus that stood.

## What was set

As on 2026-11-06 (`doc/verification/2026-11-06-pv-surplus-own-draw.md`):
`PV008` at `N2_GLTSF`, `PV001` Yes, `PV002` No, `PV013` Always. `PV006`,
40 °C, and `PV011`, 2.0 min, as read at 18:43
(`doc/verification/2026-11-07-pv-target-ignored.md`), not read again; both
are held in EEPROM, so the restart at 21:39
(`doc/verification/2026-11-07-restart.md`) left them. The web interface was
at Fachmann level from 22:08 to 22:19
(`captures/navigator-10-level-20.24-2608-2026-11-07-2206.log`). Only 74,
88 and 4108 were written.

## What was recorded

Every 10 s from 22:06:16 to 22:19:07 over Modbus 74, 88, 4108, 1008, 1090,
1091, 1100, 1074, 4122, 1004 and 1098, 858 reads and none failed
(`captures/navigator-10-watch-20.24-2608-2026-11-07-2206.jsonl`). Every
10 s from 22:08:26 to 22:19:17 over the web 6245 `N2_MODULATION_OVERVIEW`,
10263 `N2_PV_POWER` and 12763 `N2_GLTMON`, 198 requests and none failed
(`captures/navigator-10-webwatch-20.24-2608-2026-11-07-2206.jsonl`). The
writes, 36, each read back
(`captures/navigator-10-write-20.24-2608-2026-11-07-2209.log`). Software
20.24-2608 on both channels throughout.

## Before

At 22:06:16, 1090 read `Standby`, 1091 `Keine Anforderung`, 1100 `Aus`,
4122 0.0, 1004 0, 1098 `nicht gesperrt`, B38 29.2 °C, 88 0.0, 4108 -1.0,
and 74 0.0, as the restart at 21:39 had left it. The last PV stop was at
18:56:30, 3 h 12 min before.

## The run

0.0 to 88 once and 2.0 to 74 every 20 s throughout; from 5 minutes after
1100 first read `Ein`, 0.8 to 4108 before every write of 74. The mean of 74
was 2.0 from 22:10:40 on. The speed is 6245's.

| Time     | 4108 | 4122 (kW) | Speed (rps) | What happened                                                 |
| -------- | ---- | --------- | ----------- | ------------------------------------------------------------- |
| 22:08:39 | -1.0 | 0.00      | 0           | 0.0 to 88, 2.0 to 74                                          |
| 22:09:57 |      | 0.00      | 0           | 1090 `Heizbetrieb`, 1091 `Anforderung`, 1074 100              |
| 22:13:36 |      | 0.33      | 0           | 1100 `Ein`, 3 min 40 s ± 10 s after the request               |
| 22:14:47 |      | 1.18      | 50.4        | the start program                                             |
| 22:17:47 |      | 1.38      | 56.7        | the start program is over; the speed climbs                   |
| 22:18:37 | 0.8  | 3.13      | 112.5       | 0.8 to 4108, read back; 2.0 to 74 at 22:18:38                 |
| 22:18:46 |      | 0.00      | 0           | 1090 `Standby`, 1091 and 1100 off; 6245's drive status `stop` |
| 22:18:47 | -1.0 |           |             | 0.0 to 88, -1.0 to 4108 at 22:18:48, -0.5 to 74               |

From 22:14:47 to 22:17:37 4122 read 1.13 to 1.27 kW and the speed 50.4 rps;
from 22:17:47 on the speed rose by 6 to 13 rps every 10 s. 1074 rose from 60
at the start to 96. 4108 read 0.8 at 22:18:45 and -1.0 from 22:18:55 on.
B38 rose to 30.2 °C while the pump circulated before the start and read
30.1 °C at the stop. 4122 summed over the run is 0.11 kWh. 1004 read 0 and
1098 `nicht gesperrt` throughout.

## What the web pages showed

- **12763** listed 4108 as `Leistungsbegrenzung  (kW)`, -1.0 with a
  `GLT Value` of -1 up to 22:18:37, 0.8 with a `GLT Value` of 0.8 at
  22:18:47, and -1.0 with a `GLT Value` of -1.0 from 22:18:57 on.
- **10263** read `mom./prog. Leistung Heizen` 0.8 kW throughout, before the
  start and during the run alike. `Wärmepumpe Aufnahmeleistung` followed
  4122, 1.1 to 1.3 kW in the start program and 3.5 kW at 22:18:36.
- **6245** read the drive status `run` and the error code 0.0 to 22:18:36,
  and `stop` with the error code 0.0 from 22:18:46 on.

## What it shows

- **4108 acts on a PV run.** Written below the draw, it ended the run within
  one round of the watch. Nothing written to 74 or 88 had moved a run that
  fast.
- **It ends the run rather than capping it.** The speed did not come down
  to the limit first: the read before the stop was 112.5 rps and 3.1 kW,
  the next 0. The controller withdrew the request too, as at a PV stop,
  rather than stopping the compressor under a standing request.
- **It overrides the minimum runtime.** The run ended 5 minutes 10 seconds
  after its start. The help text of 5412 names only an error as an
  exception, and 6245 and 1004 reported none.
- **The forecast does not follow the limit.** 10263's 0.8 kW stood before,
  at and after the write.

## What the run does not settle

- Whether 4108 caps the draw where the limit is above the floor's and the
  start program's draw, or always ends a run whose draw exceeds it. The
  limit here was 0.8 kW, close to the floor, against 3.1 kW. A limit
  written before the start, above the start program's 1.2 kW, would show
  which: a speed that climbs to the limit and holds is a cap, a stop when
  the draw reaches it a cut-off.
- Whether a limit below the forecast, 0.8 kW here, holds off a start.
- Why the start came 3 minutes 40 seconds after the request, against 50 s
  in the evening run before (`doc/verification/2026-11-07-pv-target-ignored.md`).
  The controller had restarted 30 minutes before; whether that holds a
  start, no setting read names.

## Reproducing

With the PV menu as above, at Kunde level for Modbus:

    cabal run idm-dump -- HOST --watch 10 74 88 4108 1008 1090 1091 1100 1074 4122 1004 1098 > watch.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
    IDM_PIN=... cabal run idm-web -- HOST --watch 10 6245 10263 12763 > webwatch.jsonl
    tools/drivepv.py HOST watch.jsonl --final -0.5 --final-target 0 --final-limit -1 \
      2.0/20/ein/0 2.0/20/ein+300 2.0/20/aus//0.8 > write.log
    tools/runtable.py watch.jsonl --web webwatch.jsonl --writes write.log

The last phase runs until the compressor stops, so the driver's final
values cannot be what ends the run.
