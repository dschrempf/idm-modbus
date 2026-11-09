# A limit at 4108 above the start program's draw caps a PV run

2026-11-08, evening. One store charge on a constant surplus written to 74,
with 4108 `Leistungsbegrenzung Wärmepumpe` at 1.5 kW from before the start,
to learn whether 4108 caps the draw of a PV run where the limit lies above
the start program's 1.2 kW (`power-limit-4108-semantics-unknown`,
`pv-control-of-74-and-88`).

It does. Once the start program was over, the speed rose from 50.4 to
58.8 rps in one round of the watch and went no further: for 42 minutes the
draw at 4122 read 1.18 to 1.52 kW, 1.39 on average, where a constant
surplus has driven the speed to the top, 120 rps and about 4 kW
(`doc/verification-2026-11-06-pv-surplus-own-draw.md`), and 2.0 the evening
before rose 6 to 13 rps every 10 s at the same point
(`doc/verification-2026-11-07-power-limit.md`). The run went past the
minimum runtime and on to `PV006`: the compressor stopped as B38 read
40.00 °C, 46 minutes 30 seconds after its start. It is the first PV run held
below full speed past the minimum runtime.

## What was set

As on 2026-11-07 (`doc/verification-2026-11-07-power-limit.md`): `PV008` at
`N2_GLTSF`, `PV001` Yes, `PV002` No, `PV013` Always, `PV006` 40 °C, `PV011`
2.0 min, not read again. The web interface was at Fachmann level from 18:54
to 19:44 (`captures/navigator-10-level-20.24-2608-2026-11-08-1854.log`).
Only 74, 88 and 4108 were written.

## What was recorded

Every 10 s from 18:52:57 to 19:43:28 over Modbus 74, 88, 4108, 1008, 1090,
1091, 1100, 1074, 4122, 1004 and 1098, 3344 reads and none failed
(`captures/navigator-10-watch-20.24-2608-2026-11-08-1852.jsonl`). Every
10 s from 18:53:20 to 19:43:31 over the web 6245 `N2_MODULATION_OVERVIEW`,
10263 `N2_PV_POWER` and 12763 `N2_GLTMON`, 906 requests and none failed
(`captures/navigator-10-webwatch-20.24-2608-2026-11-08-1854.jsonl`). The
writes, 278, each read back
(`captures/navigator-10-write-20.24-2608-2026-11-08-1853.log`). Software
20.24-2608 on both channels throughout.

## Before

At 18:52:57, 1090 read `Standby`, 1091 `Keine Anforderung`, 1100 `Aus`,
4122 0.0, 1004 0, 1098 `nicht gesperrt`, B38 29.6 °C, 88 0.0, 4108 -1.0, and
74 -0.5, as the driver had left it at 22:18:48 the evening before, 20 h 34
min after the last PV stop.

## The run

0.0 to 88 once; 1.5 to 4108 and then 2.0 to 74 every 20 s throughout. The
mean of 74 was 2.0 from 18:55:58 on. The speed is 6245's.

| Time     | 4122 (kW) | Speed (rps) | B38 (°C) | What happened                                                          |
| -------- | --------- | ----------- | -------- | ---------------------------------------------------------------------- |
| 18:53:54 | 0.00      | 0           | 29.6     | 0.0 to 88, 1.5 to 4108, 2.0 to 74                                      |
| 18:55:18 | 0.00      | 0           | 29.6     | 1090 `Heizbetrieb`, 1091 `Anforderung`, 1074 100                       |
| 18:56:08 | 0.30      | 0           | 31.1     | 1100 `Ein`, 50 s ± 10 s after the request                              |
| 18:57:18 | 1.16      | 50.4        | 31.3     | the start program                                                      |
| 19:00:28 | 1.44      | 58.8        | 31.5     | the start program is over; the speed climbs one step                   |
| 19:06:18 | 1.44      | 57.6        | 32.5     | past the minimum runtime                                               |
| 19:20:58 | 1.42      | 55.2        | 35.6     | 10263's forecast 0.9 kW, from 0.8                                      |
| 19:42:28 | 1.33      | 51.6        | 39.9     |                                                                        |
| 19:42:38 | 1.36      | 51.6        | 40.0     | 1090 `Standby`, 1091 and 1100 off; 0.0 to 88, -1.0 to 4108, -0.5 to 74 |

From 18:57:18 to 19:00:18 4122 read 1.16 to 1.35 kW and the speed 50.4 rps.
From 19:00:28 to 19:42:28, 253 reads, 4122 read 1.18 to 1.52 kW, 1.39 on
average, above 1.5 twice, 1.51 at 19:01:48 and 1.52 at 19:05:38, and the
speed 51.6 to 58.8 rps, falling by about 7 rps over the 42 minutes as the
store warmed. 1074 read 70 to 74 while the compressor ran. 4122 summed over
the run is 1.06 kWh. B38 rose 1.5 K while the pump circulated before the
start and 8.9 K during the run. 1004 read 0 and 1098 `nicht gesperrt`
throughout.

## What the web pages showed

- **12763** listed 4108 as `Leistungsbegrenzung  (kW)`, -1.0 with a
  `GLT Value` of -1.0 at 18:53:21, 1.5 with a `GLT Value` of 1.5 from
  18:54:01, and -1.0 with a `GLT Value` of -1.0 from 19:42:41 on.
- **10263** read `mom./prog. Leistung Heizen` 0.8 kW to 19:20:50 and 0.9 kW
  from 19:20:51 on, before and after the stop.
- **6245** read the drive status `run` from 18:56:10 to 19:42:39 and `stop`
  from 19:42:40 on, and the error code 0.0 at every request.

## What it shows

- **4108 caps the draw where the limit is above it at the start.** With 74
  at a constant 2.0, the loop's error stood at 2.0 all run long, which on
  2026-11-06 drove the speed to 120 rps; here the speed stopped one step past
  the start program and followed the limit rather than the loop, coming down
  as the store warmed. The draw sat mostly between 1.3 and 1.45 kW, a little
  below the limit.
- **A capped run holds past the minimum runtime and ends at `PV006`.** The
  surplus at 74 stood; the stop came at 40.00 °C, as in the run on 3.0 of
  2026-11-05 (`doc/verification-2026-11-05-pv-surplus.md`).
- **A limit above the forecast does not hold off a start.** 1.5 against the
  forecast's 0.8 kW: the request came 1 minute 24 seconds after the first
  write, the compressor 50 s later.
- **Read with 2026-11-07,** a limit below the draw ends a run
  (`doc/verification-2026-11-07-power-limit.md`) and one above it caps the
  climb. Where the line between the two runs, the runs do not say: 0.8 was
  2.3 kW below the draw it met, 1.5 never below it.

## What the run does not settle

- Whether a limit below the start program's 1.2 kW, written before the start,
  caps as this one did, holds the run in the start program, ends it once the
  start program draws more, or holds off the start. 0.8, near the floor's
  draw, is the value a low PV run wants.
- Whether lowering the limit under a capped run brings the speed down or
  ends the run, as 0.8 did under 3.1 kW.
- What 4108 does outside a PV run: in a run on a circuit's demand or a hot
  water charge.
- Why the start came 50 s after the request, against 3 minutes 40 seconds the
  evening before, after a restart.

## Reproducing

With the PV menu as above, at Kunde level for Modbus:

    cabal run idm-dump -- HOST --watch 10 74 88 4108 1008 1090 1091 1100 1074 4122 1004 1098 > watch.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
    IDM_PIN=... cabal run idm-web -- HOST --watch 10 6245 10263 12763 > webwatch.jsonl
    tools/drivepv.py HOST watch.jsonl --final -0.5 --final-target 0 --final-limit -1 \
      2.0/20/ein/0/1.5 2.0/20/aus//1.5 > write.log
    tools/runtable.py watch.jsonl --web webwatch.jsonl --writes write.log

The last phase runs until the compressor stops, so the driver's final
values cannot be what ends the run.
