# A limit at 4108 caps a PV run down to 1.0 kW, and ends it at 0.9

2026-11-09, noon. One store charge on a constant surplus written to 74,
with 4108 `Leistungsbegrenzung Wärmepumpe` at 1.2 kW from before the start,
lowered under the running run to 1.0 and then to 0.9, to learn how low a
limit caps the draw of a PV run (`power-limit-4108-semantics-unknown`,
`pv-control-of-74-and-88`). A webprobe capture during the run read the
controller's reason for the request
(`watch-the-request-reason-pv-in-idm-web`).

1.2 capped the run as 1.5 did on 2026-11-08: the speed held 45.5 to
46.8 rps once the start program was over, the draw 1.19 kW on average, past
the minimum runtime. 1.0, written under it 15 minutes after the start,
brought the speed down to 38.4 rps within 20 s and the draw to 0.98 kW on
average, and the run went on. 0.9, written 2 minutes 38 seconds later at
1.0 kW, ended the run within 8 s. Below 1.0, a limit ends a run rather than
capping it, whatever the distance to the draw: 0.8 did so 2.3 kW below it on
2026-11-07, 0.9 here 0.1 kW below, where 1.0 had capped 0.15 kW below. The
controller named the request PV's.

## What was set

As on 2026-11-08 (`doc/verification/2026-11-08-power-limit-cap.md`):
`PV008` at `N2_GLTSF`, `PV001` Yes, `PV002` No, `PV013` Always, `PV006`
40 °C, `PV011` 2.0 min, not read again. The web interface was at Fachmann
level from 12:35 to 12:57
(`captures/navigator-10-level-20.24-2608-2026-11-09-1235.log`). Only 74,
88 and 4108 were written.

## What was recorded

Every 10 s from 12:35:33 to 12:56:54 over Modbus 74, 88, 4108, 1008, 1090,
1091, 1100, 1074, 4122, 1004 and 1098, 1419 reads and none failed
(`captures/navigator-10-watch-20.24-2608-2026-11-09-1235.jsonl`). Every
10 s from 12:35:56 to 12:56:57 over the web 6245 `N2_MODULATION_OVERVIEW`,
10263 `N2_PV_POWER` and 12763 `N2_GLTMON`, 381 requests and none failed
(`captures/navigator-10-webwatch-20.24-2608-2026-11-09-1235.jsonl`). A
webprobe walk from 12:43:32 to 12:54:53, 341 requests
(`captures/navigator-10-webapi-20.24-2608-2026-11-09-1243.json`), on a
second websocket session beside the watch's; neither failed a request. The
writes, 118, each read back, in three logs, one per limit
(`captures/navigator-10-write-20.24-2608-2026-11-09-1236.log`, `-1253.log`
and `-1255.log`). Software 20.24-2608 on both channels throughout.

The limit was lowered by replacing the schedule driver under the run: the
first, which renewed 1.2, was killed at 12:53:03 without its final writes,
so 74 and 4108 stood as written, and a second, renewing 1.0, wrote at
12:53:17; the same again from 1.0 to 0.9 at 12:55:50 and 12:55:55. The
third wrote the final values once the compressor stopped.

## Before

At 12:35:33, 1090 read `Standby`, 1091 `Keine Anforderung`, 1100 `Aus`,
4122 0.0, 1004 0, 1098 `nicht gesperrt`, B38 32.5 °C, 88 0.0, 4108 -1.0, and
74 -0.5, as the driver had left it at 19:42 the evening before, 16 h 53 min
after the last PV stop.

## The run

0.0 to 88 once; 1.2 to 4108 and then 2.0 to 74 every 20 s, the limit
lowered as below. The mean of 74 was 2.0 from 12:37:24 on. The speed is
6245's.

| Time     | 4122 (kW) | Speed (rps) | B38 (°C) | What happened                                                          |
| -------- | --------- | ----------- | -------- | ---------------------------------------------------------------------- |
| 12:36:19 | 0.00      | 0           | 32.5     | 0.0 to 88, 1.2 to 4108, 2.0 to 74                                      |
| 12:37:44 | 0.00      | 0           | 32.5     | 1090 `Heizbetrieb`, 1091 `Anforderung`, 1074 100                       |
| 12:38:34 | 0.13      | 0           | 33.1     | 1100 `Ein`, 50 s ± 10 s after the request                              |
| 12:39:44 | 1.25      | 50.4        | 33.2     | the start program                                                      |
| 12:42:44 | 1.20      | 46.8        | 33.6     | the start program is over; the speed comes down                        |
| 12:48:44 | 1.19      | 46.7        | 34.9     | past the minimum runtime                                               |
| 12:53:17 | 1.08      | 45.6        | 35.7     | 1.0 to 4108                                                            |
| 12:53:44 | 0.99      | 38.4        | 35.8     |                                                                        |
| 12:55:55 | 0.99      | 38.4        | 36.1     | 0.9 to 4108                                                            |
| 12:56:04 | 0.00      | 0           | 36.2     | 1090 `Standby`, 1091 and 1100 off; 0.0 to 88, -1.0 to 4108, -0.5 to 74 |

From 12:39:44 to 12:42:24 4122 read 1.24 to 1.30 kW and the speed 50.4 rps,
above the limit of 1.2. From 12:42:44 to 12:53:14, 64 reads, 4122 read 1.13
to 1.32 kW, 1.19 on average, and the speed 45.5 to 46.8 rps. From 12:53:34
to 12:55:54, 15 reads, 4122 read 0.86 to 1.07 kW, 0.98 on average; the speed
read 42.6 rps 9 s after the write of 1.0, and 38.4 to 39.5 from 19 s after
it on. The
compressor ran 17 minutes 30 seconds. 1074 read 60 to 71 while it ran. 4122
summed over the run is 0.34 kWh. 1004 read 0 and 1098 `nicht gesperrt`
throughout.

## What the web pages showed

- **12763** listed 4108 as `Leistungsbegrenzung  (kW)`, its `Value` and
  `GLT Value` alike: -1.0 at 12:35:57, 1.2 from 12:36:27, 1.0 from 12:53:27,
  0.9 from 12:55:57 and -1.0 from 12:56:07. 74 and 88 read as written.
- **10263** read `mom./prog. Leistung Heizen` 0.8 kW to 12:50:46 and 0.9 kW
  from 12:50:56 on.
- **6245** read the drive status `run` from 12:38:36 to 12:55:56 and `stop`
  from 12:56:06 on, and the error code 0.0 at every request.
- **The webprobe walk**, at 12:43:36 to 12:43:40, with the limit at 1.2:
  `system` `overview` carried `heatpump.info` 33 beside `operationMode` 1;
  `home` `detail` carried `info` 33 beside `operationMode` 1 in widget 17,
  and widget 10 `operationMode` 1 without `info`; `home` `overview` the
  same for widget 17 in each of its three layouts. Widget 16 of `home`
  `detail` read a `performance` `number` of 3.7 and a `production` `power`
  of 4.5 kW, read here as the COP and the heat output. No other request of
  the walk carried an `info`.

## The request reason

33 is bits 1 and 32. The web interface's JavaScript
(`captures/navigator-10-webui-20.24-2608-2026-11-05-1641/main-7UP7UE6I.js`)
clears bit 1 before it counts the bits of `info`, so a value with one bit
besides it names one reason, and for `operationMode` 1, heating, bit 32 is
`RD_REQ_PV`, "PV Control" in its English translation. The controller
registered this run as PV's, not as a heating circuit's. What bit 1 means
the JavaScript does not say. The display was not read beside it.

## What it shows

- **A limit from 1.0 to 1.5 caps a PV run past the minimum runtime.** Under
  1.2 the speed came down after the start program rather than climbing one
  step, as it had under 1.5, and the draw sat at the limit.
- **The start program is not capped.** It drew 1.24 to 1.30 kW at 50.4 rps,
  above the limit of 1.2, and was not ended for it.
- **A capped run follows a lowered limit.** 1.2 to 1.0 under the running run
  brought the speed down 7 rps within 20 s, without a stop.
- **A limit below 1.0 ends a run.** 0.9 ended it within 8 s, 0.1 kW below a
  draw that 1.0 had held, so the distance to the draw is not what decides;
  the value is. The line lies between 0.9 and 1.0, and holds whether the
  limit is far below the draw (0.8 under 3.1 kW,
  `doc/verification/2026-11-07-power-limit.md`) or just below it. The
  heating floor, 24 rps and 0.6 to 0.74 kW, lies below it, so it is the
  controller's line, not the compressor's.
- **A limit at 1.2 does not hold off a start.** The request came 1 minute
  24 seconds after the first write, the compressor 50 s later, as with 1.5.

## What the run does not settle

- Whether a limit below 1.0 written before the start holds off the start,
  ends the run in the start program, or is cut off as it is reached. The
  start program draws above 1.2, so a run on such a limit would not be
  capped.
- Whether the line lies at 1.0 itself, or between 0.9 and 1.0, and whether
  it is a setting.
- How long a run capped at 1.0 holds: this one was ended at 0.9 after 2
  minutes 38 seconds at 1.0.
- What 4108 does outside a PV run.

## Reproducing

With the PV menu as above, at Kunde level for Modbus:

    cabal run idm-dump -- HOST --watch 10 74 88 4108 1008 1090 1091 1100 1074 4122 1004 1098 > watch.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
    IDM_PIN=... cabal run idm-web -- HOST --watch 10 6245 10263 12763 > webwatch.jsonl
    tools/drivepv.py HOST watch.jsonl --final -0.5 --final-target 0 --final-limit -1 \
      2.0/20/ein/0/1.2 2.0/20/aus//1.2 > write-1.2.log

and, about 15 minutes after the compressor start, `kill -KILL` the
driver's pid, the first line of its log, and at once

    tools/drivepv.py HOST watch.jsonl --final -0.5 --final-target 0 --final-limit -1 \
      2.0/20/aus//1.0 > write-1.0.log

and likewise for 0.9. A driver started under a running run reads 1100 `Ein`
at its first poll. The webprobe capture, about 5 minutes after the
compressor start:

    IDM_PIN=... tools/webprobe.py HOST > webapi.json
