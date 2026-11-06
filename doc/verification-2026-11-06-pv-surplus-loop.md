# A meter-style surplus at 74 does not hold a run near its target

2026-11-06, evening. A store charge was started on 1.7 written to 74, and
from 3.5 minutes after the compressor started, 1.0 minus 4122 was written
every 20 s: what a grid meter would read with 1.0 kW of PV and the pump the
only load. The run did not settle near 1.0 kW. Once the start program
ended, the speed climbed from 50 to 117 rps, although every value written
was already negative, then fell to the floor, 24 rps at 0.67 kW, and the
compressor stopped after 8 minutes 10 seconds. A second start, on 1.7 for
ten minutes beginning nine minutes after that stop, never came.

The direction of the speed followed the sign of the two-minute mean of the
values written to 74, not the value written last; see "What it shows".

## What was set

As in the morning (`doc/verification-2026-11-06-pv-surplus-own-draw.md`):
`PV008` at `N2_GLTSF`, `PV001` Yes, `PV002` No, `PV013` Always, `PV011`
2.0 min, `PV006` 40 °C, `N2_PV_HEATING_HYSTERESIS` (13300) 4 K. The web
interface was at Fachmann level from 19:54, for the speed; the output of
`--enter-fachmann` was lost, and `--status` read `Fachmann (2)` at 19:54:58
(`captures/navigator-2.0-level-20.24-2608-2026-11-06-1954.log`, written by
hand). Nothing but 74 was written.

## What was recorded

Every 10 s from 19:51:50 to 20:39:00 over Modbus 74, 1008, 1090, 1091,
1100, 1074, 4122, 1004 and 1098, 2553 reads and none failed
(`captures/navigator-2.0-watch-20.24-2608-2026-11-06-1951.jsonl`). Every
10 s from 19:54:11 to 20:38:52 over the web 6245 `N2_MODULATION_OVERVIEW`
and 10263 `N2_PV_POWER`, 538 requests and none failed
(`captures/navigator-2.0-webwatch-20.24-2608-2026-11-06-1954.jsonl`). The
writes, 21 for the first run and 15 for the second, none failed
(`captures/navigator-2.0-write-20.24-2608-2026-11-06-1954.log`,
`captures/navigator-2.0-write-20.24-2608-2026-11-06-2013.log`).

## Before

At 19:47, 74 read -0.5, the value written last at 11:37:15, 8 h 10 min
before. 1090 `Standby`, 1100 `Aus`, 4122 0.0, 1098 `nicht gesperrt`, B38
27.3 °C. The PV page read `mom./prog. Leistung Heizen` 0.7 kW.

## The first run

The mean is that of the values written, over the 120 s before, computed from
the write log; the speed and motor power are 6245's.

| Time     | 74 written | Mean of 74 | Speed (rps) | What happened                            |
| -------- | ---------- | ---------- | ----------- | ---------------------------------------- |
| 19:54:38 | 1.7        | -0.5       | 0           | written every minute                     |
| 19:55:59 |            | about 1.0  | 0           | 1090 `Heizbetrieb`, 1091 `Anforderung`   |
| 19:56:50 |            | 1.70       | 0           | 1100 `Ein`                               |
| 19:57:51 |            | 1.70       | 50.4        | the start program, 1.2 kW                |
| 20:00:22 | -0.24      | 1.70       | 50.4        | 1.0 minus 4122 every 20 s from here      |
| 20:01:01 | -0.24      | 1.05       | 61.4        | the start program ends; the speed climbs |
| 20:01:51 | -1.95      | -0.01      | 111.3       | the mean crosses zero                    |
| 20:02:01 | -1.95      | -0.31      | 117.0       | the highest speed, 4122 4.0 kW           |
| 20:02:11 | -3.0       | -0.68      | 112.0       | the speed falls, about 12 rps per 10 s   |
| 20:03:41 | -0.03      | -1.45      | 24.0        | the floor, 0.67 kW                       |
| 20:03:49 | 0.30       | -1.31      | 24.0        | the controller weighs a 1.0 kW surplus   |
| 20:04:51 | 0.35       | -0.06      | 24.0        |                                          |
| 20:04:59 |            | 0.06       | 0           | 1090 `Standby`, then 1091 and 1100 off   |
| 20:05:12 | -0.5       |            | 0           | written once                             |

B38 rose from 27.3 to 30.2 °C. 4122 summed over the run is 0.19 kWh. 1004
read 0 throughout. The PV page printed 74 as written, as in the morning, and
`mom./prog. Leistung Heizen` read 0.8 kW from the start until 20:34, 0.7
after.

## The second start

From 20:13:41, 1.7 was written every minute: the mean stood at 1.7 from
about 20:15:40, past the compressor's minimum dwell time of 10 minutes,
setting 5419, which ended at 20:15:00. Neither 1090 nor 1091 moved by
20:23:53. B38 stood at 29.8 °C, below `PV006` minus 13300, 36 °C, the
switch-on threshold its help text gives. -0.5 was written at 20:24:01; the
write script, missed by the `kill` meant to end it, wrote 1.7 twice more, at
20:24:54 and 20:25:56, and -0.5 stands since 20:26:24.

## What it shows

- **The speed follows the sign of the mean of 74.** It climbed from the end
  of the start program while the mean was positive, peaked 10 s after the
  mean crossed zero, and fell while it was negative, at about the rate it
  climbed. The values written were negative from 20:00:22 on; the speed
  climbed for another 60 s regardless. So 74 is weighed, for the speed, as
  `PV011`'s mean and as an export: above zero the controller takes more,
  below zero less. The morning fits, less sharply: 1.7 climbed, 0 held
  120 rps, -0.5 fell.
- **A meter-style value against a two-minute mean overshoots.** The value a
  meter reads turns negative as soon as the draw exceeds the PV; the mean
  follows two minutes later, and in between the controller climbs. A
  consumer writing the meter's export as it is drives the run from the floor
  to full speed and back, whatever cadence it writes at.
- **The run stopped after 8 minutes 10 seconds, before the minimum runtime
  of 10 minutes**, setting 5412, whose help text excepts only a fault. It
  stopped as the mean came back to zero, after 70 s at the floor.
- **A second start failed with nothing that the documented settings
  explain.** The standstill had passed and B38 was well below the
  switch-on threshold.
- **The start came at a lower mean than in the morning.** The request came
  when the mean reached about 1.0 against a forecast of 0.7 kW; in the
  morning 1.0 held for 12 minutes against 0.8 kW and started nothing.

## What the run does not settle

- What stops a PV run: the stop of the morning came 72 s into a negative
  mean at 81 rps, this one at the floor as the mean recrossed zero, and
  before the minimum runtime.
- What blocks a start after a PV run, and for how long.
- What the start threshold is: about 0.3 kW above the forecast fits both
  runs of the day, and nothing else tests it.

`doc/pv-control.md` lists the sources on these and the observations that
would settle them.

## Reproducing

With the PV menu as above, at Kunde level for Modbus:

    cabal run idm-dump -- HOST --watch 10 74 1008 1090 1091 1100 1074 4122 1004 1098 > watch.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
    IDM_PIN=... cabal run idm-web -- HOST --watch 10 6245 10263 > webwatch.jsonl
    tools/drive74.py HOST watch.jsonl --final -0.5 1.7/60/ein+210 1.0-4122/20/ein+2910 -0.5/60/aus > write.log
    tools/runtable.py watch.jsonl --web webwatch.jsonl --writes write.log

The run used two scratch scripts that `tools/drive74.py` replaced; the
schedule above is theirs. The table's mean of 74 was taken at the times of
6245's samples; `tools/runtable.py` takes it at the rounds of the Modbus
watch, so its figures differ from the table's by up to one round.
