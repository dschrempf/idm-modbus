# A PV run capped at 1.0 kW from the start holds 30 minutes, then ends below `PV006`

2026-11-09, evening. One store charge on a constant surplus written to 74,
with 4108 `Leistungsbegrenzung Wärmepumpe` at 1.0 kW from before the start
and held, to learn whether the lowest limit that caps a run lets the start
program through, and how long a run at that limit holds
(`power-limit-4108-semantics-unknown`, `pv-control-of-74-and-88`). A web
watch read the controller's reason for the request each round
(`watch-the-request-reason-pv-in-idm-web`).

1.0 let the start program through, as 1.2 did at noon
(`doc/verification-2026-11-09-power-limit-floor.md`): 1.11 to 1.43 kW at
50.4 rps for 3 minutes. After it the speed came down to 37.2 to 40.8 rps
and the draw held 1.01 kW on average, past the minimum runtime, for 26
minutes. Then the request ended, 30 minutes 50 seconds after the compressor
start, with B38 at 37.9 °C, 2.1 K below `PV006`, where the run on 1.5 of
2026-11-08 had ended at 40.00 °C. No capture says why. The controller
named the request PV's throughout.

## What was set

As on 2026-11-08 (`doc/verification-2026-11-08-power-limit-cap.md`):
`PV008` at `N2_GLTSF`, `PV001` Yes, `PV002` No, `PV013` Always, `PV006`
40 °C, `PV011` 2.0 min, not read again. The web interface was at Fachmann
level from 17:29 to 18:03
(`captures/navigator-10-level-20.24-2608-2026-11-09-1728.log`). Only 74,
88 and 4108 were written.

## What was recorded

Every 10 s from 17:28:52 to 18:03:13 over Modbus 74, 88, 4108, 1008, 1090,
1091, 1100, 1074, 4122, 1004 and 1098, 2277 reads and none failed
(`captures/navigator-10-watch-20.24-2608-2026-11-09-1728.jsonl`). Every
10 s from 17:29:09 to 18:03:11 over the web the system overview, 6245
`N2_MODULATION_OVERVIEW`, 10263 `N2_PV_POWER` and 12763 `N2_GLTMON`, 820
requests and none failed
(`captures/navigator-10-webwatch-20.24-2608-2026-11-09-1728.jsonl`). The
writes, 192, each read back, in one log
(`captures/navigator-10-write-20.24-2608-2026-11-09-1729.log`). A webprobe
walk after the run, for the graphs
(`captures/navigator-10-webapi-20.24-2608-2026-11-09-1807.json`). Software
20.24-2608 on both channels throughout.

## Before

At 17:28:53, 1090 read `Standby`, 1091 `Keine Anforderung`, 1100 `Aus`,
4122 0.0, 1004 0, 1098 `nicht gesperrt`, B38 30.6 °C, 88 0.0, 4108 -1.0, and
74 -0.5, as the driver had left it at 12:56, 4 h 33 min after the last PV
stop. A heating run on circuit C's demand lay between
(`doc/verification-2026-11-09-heating-run-as-on-1574.md`).

## The run

0.0 to 88 once; 1.0 to 4108 and then 2.0 to 74 every 20 s, until the
compressor stopped. The mean of 74 was 2.0 from 17:31:23 on. The speed is
6245's, the flow and return the system overview's.

| Time     | 4122 (kW) | Speed (rps) | B38 (°C) | What happened                                    |
| -------- | --------- | ----------- | -------- | ------------------------------------------------ |
| 17:29:20 | 0.00      | 0           | 30.6     | 0.0 to 88, 1.0 to 4108, 2.0 to 74                |
| 17:30:43 | 0.00      | 0           | 30.6     | 1090 `Heizbetrieb`, 1091 `Anforderung`, 1074 100 |
| 17:31:33 | 0.12      | 0           | 32.8     | 1100 `Ein`, 50 s ± 10 s after the request        |
| 17:32:33 | 1.36      | 50.4        | 33.6     | the start program                                |
| 17:35:43 | 1.05      | 39.7        | 33.8     | the start program is over; the speed comes down  |
| 17:41:33 | 1.04      | 39.6        | 34.8     | the minimum runtime                              |
| 18:02:13 | 0.99      | 37.2        | 37.9     | flow 39.8 °C, return 37.6 °C                     |
| 18:02:23 | 1.05      | 37.2        | 37.9     | 1090 `Standby`, 1091 and 1100 off                |
| 18:02:25 | 0.00      | 0           | 37.9     | 0.0 to 88, -1.0 to 4108, -0.5 to 74              |

The request came 1 minute 23 seconds after the first write. From 17:32:33
to 17:35:23, 18 reads, 4122 read 1.11 to 1.43 kW and the speed 50.4 rps,
above the limit. From 17:35:43 to 18:02:13, 160 reads, 4122 read 0.85 to
1.22 kW, 1.01 on average, and the speed 37.2 to 40.8 rps, 39.5 on average
in the first ten minutes and 37.9 in the last. The compressor ran 30
minutes 50 seconds. 1074 read 60 to 71 while it ran. 4122 summed over the
run is 0.53 kWh. B38 rose 2.1 K while the pump circulated before the
compressor start, and 0.15 to 0.12 K a minute while it ran. 1004 read 0 and
1098 `nicht gesperrt` throughout.

## What the web pages showed

- **The system overview** read `operationMode` 1 and `info` 33 from
  17:30:49 to 18:02:09, and `operationMode` 0 without `info` from 18:02:19
  on. 33 is `RD_REQ_PV` (`doc/verification-2026-11-09-power-limit-floor.md`,
  "The request reason"). The flow rose from 31.4 °C at 17:31:09 to 36.5 at
  17:40, 38.0 at 17:50, 39.4 at 18:00 and 39.8 at 18:02:09, the return
  about 2 K below it from 17:40 on. The source inlet read 5.3 to 5.4 °C
  in the last minute.
- **12763** listed 4108 as `Leistungsbegrenzung  (kW)`, its `Value` and
  `GLT Value` alike: -1.0 at 17:29:11, 1.0 from 17:29:21 and -1.0 from
  18:02:31. 74 and 88 read as written.
- **10263** read `mom./prog. Leistung Heizen` 0.8 kW to 17:43:50 and 0.9 kW
  from 17:44:00 on.
- **6245** read the drive status `stop` to 17:31:30, `run` from 17:31:40 to
  18:02:20 and `stop` from 18:02:30 on, and the error code 0.0 at every
  request. In the 30 s before the stop 6245, 12763 and the system
  overview changed only as running values drift: a temperature by 0.1 K,
  the motor current by 0.1 A, the DC bus voltage by 2 V.

## What ended it

The request ended before the compressor: the overview cleared `info` at
18:02:19, between 1091's last `Anforderung` at 18:02:13 and the stop in
the round of 18:02:23, and the driver wrote nothing in between. Not a
defrost: 1090 went from `Heizbetrieb` to `Standby` without reading
`Abtauung`, which it reads through a defrost
(`doc/verification-2026-10-16-draw.md`), and the request would stand
through one. The controller's graph channel 10004 `N2_DEFROSTING`, in the
webprobe walk after the run, marks its last defrost from 15:43 to 15:50,
in the heating run of the afternoon, and none from 17:31 to 18:02;
channels 10000 `N2_STAGES` and 10001 `N2_HEATING` mark the run from 17:31
to 18:02.

What the captures leave as candidates:

- **A temperature against `PV006`.** B38 read 37.9 °C, 2.1 K below it. The
  flow read 39.8 °C, below it too; on 2026-11-08 B38 reached 40.00 °C before
  that run ended, and the flow, above B38 while the store charges, must
  have stood above 40 for a while without ending it. B45 `Ladefühler`, the
  water going into the store, has five-minute means in the controller's
  graph that put it near 39.6 °C at the stop, below 40
  (`doc/verification-2026-11-09-graphs-record-every-channel.md`); it stands
  about 2 K above B38 while the store charges, so on 2026-11-08 it too
  passed 40 before that run ended. No graph
  channel holds the flow, B33, and the watch of 2026-11-08 did not read it.
- **A time of about 30 minutes**, for a capped run or one at low speed. The
  run on 1.5 of 2026-11-08 held 46 minutes 30 seconds, so not for every PV
  run.

## What it shows

- **A limit of 1.0 lets the start program through.** It drew up to 1.43
  kW, above the limit, and was not ended for it, as under 1.2.
- **A limit of 1.0 caps a run from the start.** The speed came down to 38
  to 40 rps once the start program was over, as it had when 1.0 was
  written under a running run at noon, and the draw sat at the limit for 26
  minutes.
- **A limit of 1.0 does not hold off a start.** The request came 1 minute
  23 seconds after the first write, the compressor 50 s later, as with 1.2
  and 1.5.
- **A run capped at 1.0 can end before `PV006`.** This one ended at 30
  minutes 50 seconds with the store 2.1 K below it, on a request the
  controller withdrew, not on an error or a lock.

## What the run does not settle

- What ended the run: a temperature, a time, or something else.
- Whether a run at 1.0 ends the same way each time, and whether one at 1.2
  or 1.5 would have ended so too had the store been as warm.
- Whether a limit below 1.0 written before the start holds off the start.
- What 4108 does outside a PV run.

## Reproducing

With the PV menu as above, at Kunde level for Modbus:

    cabal run idm-dump -- HOST --watch 10 74 88 4108 1008 1090 1091 1100 1074 4122 1004 1098 > watch.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
    IDM_PIN=... cabal run idm-web -- HOST --watch 10 --reason 6245 10263 12763 > webwatch.jsonl
    tools/drivepv.py HOST watch.jsonl --final -0.5 --final-target 0 --final-limit -1 \
      2.0/20/ein/0/1.0 2.0/20/aus//1.0 > write.log

and after the run

    IDM_PIN=... tools/webprobe.py HOST > webapi.json
