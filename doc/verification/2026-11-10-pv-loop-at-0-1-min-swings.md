# With `PV011` at 0.1 min a meter-fed PV run swings and ends after 8 minutes

2026-11-10, evening. One store charge on 74 written as a grid meter's
export, with `PV011` shortened from 2.0 min to 0.1 min, its minimum, to learn
whether the PI controller of the PV run settles once the mean of 74 adds no
lag (`pv-control-of-74-and-88`, step 1). The simulated PV stepped down after
the start program, to learn the lowest draw such a loop holds.

It did not settle. After the start program the speed swung between about 35
and 95 rps, the draw between 0.9 and 2.6 kW, with a period of about 90 s,
the mean of 74 between -1.02 and +0.67. The swing stayed bounded, where with
`PV011` at 2.0 min the same feed drove the speed to the top
(`doc/verification/2026-11-07-pv-target.md`). The run ended 8 minutes after
the compressor start, before the minimum runtime, in the first step down,
with the mean at -0.18; a mean of -1.02 two minutes earlier had not ended
it. It is the third PV run to end at about 8 minutes on a mean at or below
zero.

## What was set

As on 2026-11-09 (`doc/verification/2026-11-09-power-limit-held-at-1-0.md`):
`PV008` at `N2_GLTSF`, `PV001` Yes, `PV002` No, `PV013` Always, `PV006`
40 °C. `PV011`, 10389, set to 0.1 min at the display before the run, one
EEPROM cycle, and read 0.1 at every request of the web watch; it stays
there for the next run. The web interface was at Fachmann level from
20:57:04 (`captures/navigator-10-level-20.24-2608-2026-11-10-2056.log`).
Only 74, 88 and 4108 were written.

## What was recorded

Every 10 s from 20:57:16 to 21:08:08 over Modbus 74, 88, 4108, 1008, 1066,
1070, 1090, 1091, 1100, 1074, 4122, 1004 and 1098, 858 reads and none
failed (`captures/navigator-10-watch-20.24-2608-2026-11-10-2057.jsonl`).
Every 10 s over the same span over the web the system overview, 6245
`N2_MODULATION_OVERVIEW`, 10263 `N2_PV_POWER`, 12763 `N2_GLTMON` and 10389
`PV011`, 330 requests and none failed
(`captures/navigator-10-webwatch-20.24-2608-2026-11-10-2057.jsonl`). The
writes, 63, each read back, in one log
(`captures/navigator-10-write-20.24-2608-2026-11-10-2057.log`). Software
20.24-2608 on both channels throughout. The refrigerant circuit's pages,
4768 `N2_SENSORS` and 5888 `N2_EVR_OVERVIEW`, were not in the web watch.

## Before

At 20:57:16, 1090 read `Standby`, 1100 `Aus`, 4122 0.0, 1004 0, 1098
`nicht gesperrt`, B38 29.6 °C, B45 23.7 °C, B125 27.4 °C, 88 0.0, 4108
-1.0 and 74 -0.5, as the driver had left it on 2026-11-09, more than 30
minutes after the last PV stop.

## The run

0.0 to 88 once; 74 every 10 s: 2.0 until the compressor ran, then 2.0 less
the last 4122 of the watch, the export of 2.0 kW of PV with the pump the
only load, for 6 minutes after the start, then 1.5 less 4122, to be
followed by 1.2, 1.0 and 0.8, each for 3 minutes. With `PV011` at 0.1 min
the mean of 74 is the last value written. The speed is 6245's.

| Time     | 74    | 4122 (kW) | Speed (rps) | What happened                               |
| -------- | ----- | --------- | ----------- | ------------------------------------------- |
| 20:57:30 | 2.00  | 0.00      | 0           | 0.0 to 88, 2.0 to 74                        |
| 20:58:47 | 2.00  | 0.00      | 0           | the request, `info` 33 `RD_REQ_PV`          |
| 20:59:48 | 2.00  | 0.30      | 0           | 1100 `Ein`; the export of 2.0 kW of PV      |
| 21:00:48 | 0.83  | 1.14      | 50.4        | the start program                           |
| 21:03:48 | 0.83  | 1.34      | 56.8        | the start program is over; the speed climbs |
| 21:04:28 | -0.14 | 2.60      | 94.5        | the first peak                              |
| 21:05:18 | 0.60  | 1.33      | 51.7        | the first trough                            |
| 21:05:48 | 0.24  | 1.95      | 83.1        | the export of 1.5 kW of PV                  |
| 21:05:58 | -0.45 | 2.52      | 89.2        | the second peak                             |
| 21:06:08 | -1.02 | 2.11      | 80.4        | the lowest value written                    |
| 21:06:58 | 0.40  | 0.92      | 34.6        | the second trough                           |
| 21:07:38 | 0.24  | 1.78      | 69.5        | the last read with 1100 `Ein`               |
| 21:07:47 | -0.15 | 2.17      | 81.6        | `info` cleared; 1100 `Aus` at 21:07:48      |
| 21:07:49 | -0.50 | 0.00      | 0           | 0.0 to 88, -1.0 to 4108, -0.5 to 74         |

The request came 1 minute 17 seconds after the first write, the compressor
1 minute later. The start program held 50.4 rps at 1.14 to 1.23 kW for
about 3 minutes 50 seconds, the export at 0.77 to 0.86. From 21:03:48 the
speed swung: peaks at 94.5 and 89.2 rps, troughs at 51.7 and 34.6, a peak
following a trough by 50 to 70 s, about 90 s from peak to peak. The swing
was not damped by the step down to 1.5 kW. The compressor ran 8 minutes 0
seconds, to within the 10 s of the watch: it read `Ein` first at 20:59:48
and last at 21:07:38. The overview cleared `info` between 21:07:37 and
21:07:47, so within the same 10 s; the captures do not order the two. B38
rose from 31.0 to 31.9 °C while the compressor ran, B45 and B125 from 27
to 34 °C. 1004 read 0 and 1098 `nicht gesperrt` throughout.

## What it shows

- **The mean's lag was not the whole cause of the overshoot.** With
  `PV011` at 0.1 min the speed no longer ran to the top and held it, as it
  did with 2.0 min on 2026-11-07, but it swung between about 35 and 95 rps
  from the end of the start program on. What lag is left is the feed's: 74
  is written every 10 s from a 4122 read every 10 s, so the controller sees
  a change of speed 10 to 20 s late, and the gains, P 5.0 and I 10.0, are
  too high for that.
- **A short negative mean does not end a run.** The mean stood below zero
  from 21:05:58 to 21:06:38, down to -1.02, 6 to 7 minutes after the start,
  and the run went on. Past the minimum runtime, on the morning of
  2026-11-06, 72 s of a negative mean ended one
  (`doc/verification/2026-11-06-pv-surplus-own-draw.md`).
- **A run ends at about 8 minutes on a mean at or below zero.** This one
  ended 8 minutes 0 seconds after the start, the mean at -0.18. On
  2026-11-06 one ended after 8 minutes 10 seconds as the mean came back to
  zero from below (`doc/verification/2026-11-06-pv-surplus-loop.md`), and on
  2026-11-07 one after 8 minutes 0 seconds with the mean at -1.23
  (`doc/verification/2026-11-07-pv-target.md`). Runs whose mean was above
  zero at 8 minutes went on past it, to the minimum runtime of 10 minutes
  or beyond.

## What the run does not settle

- Whether the stop at 8 minutes is a check at that time. For the stops of
  2026-11-06 and 2026-11-07 the mean had been negative for over a minute,
  which a stretch of negative mean alone would explain; this one came with
  the mean negative for at most 10 s, after a stretch of 40 s that had not
  ended the run, which only a check at about 8 minutes explains.
- What a clamp of the value written, or lower gains, does to the swing.
- The lowest draw a meter-fed loop holds: the run ended before the steps
  below 1.5 kW of PV.

## Reproducing

With the PV menu as above and `PV011` at 0.1 min:

    cabal run idm-dump -- HOST --watch 10 74 88 4108 1008 1066 1070 1090 1091 1100 1074 4122 1004 1098 > watch.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
    IDM_PIN=... cabal run idm-web -- HOST --watch 10 --reason 6245 10263 12763 10389 > webwatch.jsonl
    tools/drivepv.py HOST watch.jsonl --final -0.5 --final-target 0 \
      2.0/10/ein/0 2.0-4122/10/ein+360 1.5-4122/10/+180 1.2-4122/10/+180 \
      1.0-4122/10/+180 0.8-4122/10/aus > write.log
    tools/runtable.py watch.jsonl --web webwatch.jsonl --writes write.log --mean 6

`tools/drivepv.py` was deleted after commit 7bc8367d7f42, the last that has it,
and `git show 7bc8367d7f42:tools/drivepv.py` recovers it. `idm-drive`, with
a schedule of `schedules/`, took its place.
