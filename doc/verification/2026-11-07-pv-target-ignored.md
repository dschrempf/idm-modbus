# A target of +1.0 at 88 does not move a PV run; 0 at 74 ends it at the minimum runtime

2026-11-07, evening. One store charge on a surplus written to 74, to
separate a step of 88, `PV-Zielwert (Smartfox und Solar-Log)`, from the end
of the minimum runtime, which the second run of the morning could not
(`doc/verification/2026-11-07-pv-target.md`).

74 was held at 0 from the compressor's start, and 88 written +1.0 from 5 to
8 minutes after it, past the start program. The speed held 50.4 rps under
+1.0 as before and after it. With 74 and 88 at 0 the controller then ended
the run 10 minutes 10 seconds after the start, without a fall of the speed
first, and with B38 at 30.9 °C, far below the 40 °C of `PV006` at which a
charge ends.

## What was set

As on 2026-11-06 (`doc/verification/2026-11-06-pv-surplus-own-draw.md`):
`PV008` at `N2_GLTSF`, `PV001` Yes, `PV002` No, `PV013` Always. `PV006`,
10333, read 40 and `PV011`, 10389, 2.0 min at 18:43
(`captures/navigator-10-show-20.24-2608-2026-11-07-1843.txt`); the rest
was not read again. The web interface was at Fachmann level from 18:43:27
to 18:56:48 (`captures/navigator-10-level-20.24-2608-2026-11-07-1843.log`).
Only 74 and 88 were written.

## What was recorded

Every 10 s from 18:43:30 to 18:56:40 over Modbus 74, 88, 1008, 1090, 1091,
1100, 1074, 4122, 1004 and 1098, 800 reads and none failed
(`captures/navigator-10-watch-20.24-2608-2026-11-07-1843.jsonl`). Every
10 s from 18:43:45 to 18:56:36 over the web 6245 `N2_MODULATION_OVERVIEW`,
10263 `N2_PV_POWER` and 12763 `N2_GLTMON`, 234 requests and none failed
(`captures/navigator-10-webwatch-20.24-2608-2026-11-07-1843.jsonl`). The
writes, 40, each read back
(`captures/navigator-10-write-20.24-2608-2026-11-07-1844.log`). Software
20.24-2608 on both channels throughout.

## Before

At 18:40, 1090 read `Standby`, 1091 `Keine Anforderung`, 1100 `Aus`, 4122
0.0, 1004 0, 1098 `nicht gesperrt`, B38 27.7 °C, 88 0.0, and 74 -0.5, the
final value of the morning's second run, written at 12:48:58, 5 h 55 min
before the first write.

## The run

0.0 to 88 once and 2.0 to 74 every 20 s until 1100 read `Ein`; from then on
0 to 74 every 20 s, and 88 stepped. The mean is `tools/runtable.py`'s, that
of the values written over the 120 s before; the speed is 6245's.

| Time     | 74  | 88   | Mean of 74 | Speed (rps) | What happened                                                |
| -------- | --- | ---- | ---------- | ----------- | ------------------------------------------------------------ |
| 18:44:08 | 2.0 | 0.0  | -0.50      | 0           |                                                              |
| 18:45:30 |     |      | about 1.2  | 0           | 1090 `Heizbetrieb`, 1091 `Anforderung`, 82 s after the first |
| 18:46:20 | 0   |      | 2.00       | 0           | 1100 `Ein`; 0 every 20 s from here                           |
| 18:47:20 |     |      | 1.00       | 50.4        | the start program, 4122 1.2 kW                               |
| 18:48:20 |     |      | 0.00       | 50.4        |                                                              |
| 18:51:22 |     | +1.0 | 0.00       | 50.4        | 5 min after the start; nothing moves for 3 min               |
| 18:54:21 |     | 0.0  | 0.00       | 50.4        |                                                              |
| 18:56:20 |     |      | 0.00       | 50.4        | 10 min after the start                                       |
| 18:56:30 |     |      | 0.00       | 50.4        | 1090 `Standby`, 1091 and 1100 off, after 10 min 10 s ± 10 s  |
| 18:56:31 |     | 0.0  |            | 0           | -0.5 to 74                                                   |

From 18:47:20 to 18:56:20 the speed read 50.4 at every read but two, 50.5
and 51.0, and 4122 1.13 to 1.28 kW. 1074 read 70 or 71 from 18:47:10 on.
B38 rose from 27.7 to 30.9 °C. 4122 summed over the run is 0.20 kWh. 1004
read 0 and 1098 `nicht gesperrt` throughout.

## What the web pages showed

- **12763** listed 74 and 88 as written, beside a `GLT Value` of the same,
  as in the morning. At 18:44:06, before the first write, 74 read -0.50
  with a `GLT Value` of -0.5: the value written at 12:48:58.
- **10263** printed 74 as written as `Überschuss`, and nothing that follows 88. `mom./prog. Leistung Heizen` read 0.7 kW before the start and 0.8 from
  it on; `Wärmepumpe Aufnahmeleistung` 1.0 to 1.2 kW during the run.

## What it shows

- **88 at +1.0 does not move a running charge.** For 3 minutes, 5 to 8
  minutes after the start and 1 to 4 minutes past the start program, the
  speed held 50.4 rps. With the morning's -1.0, also 3 minutes past the
  start program, neither sign of 88 moved the speed with the mean of 74 at 0. The controller does move the speed at that time of a run: in the
  morning's first run it climbed from 50.4 rps 4 minutes after the start, on
  a positive mean.
- **74 at 0 ends a run at the minimum runtime.** The request and the
  compressor went off together, within 20 s of the 10 minutes of 5412, with
  74 and 88 at 0 for 2 minutes and the store 9 K below `PV006`. On the
  morning of 2026-11-06 0 at 74 held a run at 120 rps past the minimum
  runtime; that run held the top, this one the start program's speed.
- **With the mean at 0 the speed does not leave the start program's.** Here
  for 9 minutes, in the morning's second run for 9 minutes too: 50.4 rps,
  1.2 kW. A PI controller with an error of 0 holds its output, and its
  output at the end of the start program is the start program's speed.
- **The stop came without a fall.** In the morning's second run the speed
  fell to the floor, 24 rps and 0.74 kW, in the 40 s before the minimum
  runtime ended, 40 to 50 s after 88 went to +1.0, and the compressor
  stopped 21 s after it. Here 88 stood at 0 and the speed was 50.4 rps up to
  the stop. Since +1.0 for 3 minutes moved nothing tonight, the morning's
  fall is not explained by 88 acting on the speed.

## What the run does not settle

- Whether 88 acts on anything but the speed: on the start, on the stop, or
  through the fall that preceded the morning's stop.
- What decides at the minimum runtime: why 0 at 74 ended this run and the
  morning's second, but held the run of 2026-11-06 at the top.
- How to hold a run at low power past the minimum runtime. A mean of 0
  holds the speed and ends the run; a mean above 0, constant, drives the
  speed to the top (`doc/verification/2026-11-06-pv-surplus-own-draw.md`).

## Reproducing

With the PV menu as above, at Kunde level for Modbus:

    cabal run idm-dump -- HOST --watch 10 74 88 1008 1090 1091 1100 1074 4122 1004 1098 > watch.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
    IDM_PIN=... cabal run idm-web -- HOST --show 10333 10389
    IDM_PIN=... cabal run idm-web -- HOST --watch 10 6245 10263 12763 > webwatch.jsonl
    tools/drivepv.py HOST watch.jsonl --final -0.5 --final-target 0 \
      2.0/20/ein/0 0/20/ein+300 0/20/ein+480/1.0 0/20/aus/0 > write.log
    tools/runtable.py watch.jsonl --web webwatch.jsonl --writes write.log

The last phase holds 74 and 88 at 0 until the compressor stops, so the
driver's final -0.5 cannot be what ends the run.

`tools/drivepv.py` was deleted after commit 7bc8367d7f42, the last that has it,
and `git show 7bc8367d7f42:tools/drivepv.py` recovers it. `idm-drive`, with
a schedule of `schedules/`, took its place.
