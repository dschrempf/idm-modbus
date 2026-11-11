# The PV control holds 74 at +0.25 kW, and below it holds a run at the floor

2026-11-11, evening. One store charge on 74, planned as the clamp run of
`pv-control-of-74-and-88`: 74 written as the export of a simulated PV,
clamped to ±0.1 kW, with `PV011` at 0.1 min. The clamp never left its upper
bound, so 74 stood at +0.1 for 45 minutes, and the run went on from there by
hand, a value of 74 at a time.

The speed control holds the mean of 74 at about +0.25 kW, not at 0. Above
it the speed rose, below it the speed fell, the faster the farther 74 stood
from it, 5.8 to 7.5 rps a minute for each 0.01 kW; at +0.25 the speed
held where it stood, at 26.6, 45.8 and 27.7 rps. At +0.1 it fell to the
floor, 24 rps at 0.63 to 0.75 kW, and held there; the run went on for 77
minutes, past the 8 and the 30 minutes earlier runs ended at, and ended at
`PV006`. 88 at -1.0 under the regulated run moved nothing, and nor did
`SSYSPV030` set from 1.0 to 0 kW.

## What was set

As on 2026-11-10 (`doc/verification/2026-11-10-pv-loop-at-0-1-min-swings.md`):
`PV008` at `N2_GLTSF`, `PV001` Yes, `PV002` No, `PV013` Always, `PV006`
40 °C, `PV011` 0.1 min, which read 0.1 at every request of the web watch.
The web interface was at Fachmann level from 21:20:53 but for a renewal,
22:15:54 to 22:16:33, read at Kunde. During the run, at about 21:58:40, at
the display, `SSYSPV030` `N2_PVOffGridHousePower` from 1.0 to 0 kW, one
EEPROM cycle; the walk after the run read 0.0, and `SSYSPV031`
`N2_PVStaticHousepwrActive` No
(`captures/navigator-10-webapi-20.24-2608-2026-11-11-2241.json`). Only 74,
88 and 4108 were written over Modbus, 4108 always -1.0.

## What was recorded

Nine `idm-drive` captures, one after another, each reading 74, 88, 4108,
1008, 1066, 1070, 1090, 1091, 1100, 1074, 4122, 1004 and 1098 every 10 s,
from 21:21:07 to 22:40:22, 6227 reads and none failed, 492 writes, each read
back and confirmed (`captures/navigator-10-drive-20.24-2608-2026-11-11-2121.jsonl`,
`…-2208`, `…-2218`, `…-2221`, `…-2225`, `…-2227`, `…-2232`, `…-2234` and
`…-2237`). The first ran `schedules/pv-clamp-0-1.toml`; each of the
others took over a running charge with a schedule written for the step, its
text in the capture's `begin` line, of which
`schedules/pv-floor-target-and-steps.toml` and `schedules/pv-floor-0-25.toml`
are kept. Each drive but the last was ended with SIGKILL, so that its
finals, -0.5 to 74 among them, did not end the run: those captures have no
`end` line, and the next drive's first write followed the last one's by 4
to 11 s, with 74 standing at the last value meanwhile. Every 10 s over the
same span over the web the system overview, 4768 `N2_SENSORS`, 5888
`N2_EVR_OVERVIEW`, 6245 `N2_MODULATION_OVERVIEW`, 10263 `N2_PV_POWER`, 12763
`N2_GLTMON` and 10389 `PV011`, 3367 requests and none failed
(`captures/navigator-10-webwatch-20.24-2608-2026-11-11-2120.jsonl`). A walk
at Fachmann level after the run, the level entered and left by `idm-web`
(`captures/navigator-10-level-20.24-2608-2026-11-11-2241.log`). Software
20.24-2608 on both channels throughout.

## Before

At 21:21:07, 1090 read `Standby`, 1100 `Aus`, 4122 0.0, 1004 0, 1098
`nicht gesperrt`, B38 29.3 °C, B45 21.6 °C, B125 25.3 °C, 88 0.0, 4108
-1.0 and 74 -0.5, from the dry runs of 21:06 and 21:08; the last PV stop was
on 2026-11-10 at 21:07. The PV page's forecast read 0.7 kW.

## The run

0.0 to 88 once and 2.0 to 74 every 10 s until the compressor ran, then 74 as
below. With `PV011` at 0.1 min the mean of 74 is the last value written. The
speed is 6245's, the draw 4122.

| Time     | 74     | 88   | Speed (rps)  | Draw (kW)   | What happened                                        |
| -------- | ------ | ---- | ------------ | ----------- | ---------------------------------------------------- |
| 21:21:10 | 2.0    | 0.0  | 0            | 0.00        | the first write                                      |
| 21:22:31 |        |      | 0            | 0.00        | the request, `info` 33 `RD_REQ_PV`                   |
| 21:23:18 | +0.1   |      | 0            | 0.16        | 1100 `Ein`; the clamped export of 2.0 kW of PV       |
| 21:24:19 |        |      | 50.4         | 1.18        | the start program's speed                            |
| 21:31:39 |        |      | 47.4         | 1.01        | the speed falls, 8 min 20 s after the start          |
| 21:32:09 |        |      | 24.0         | 0.75        | the floor; it holds there to 22:16                   |
| 21:58:40 |        |      | 24.0         | 0.66        | `SSYSPV030` to 0 at the display; nothing moves       |
| 22:08:24 |        | -1.0 | 24.0         | 0.69 – 0.72 | 4 minutes; nothing moves                             |
| 22:12:23 |        | 0.0  | 24.0         | 0.73        |                                                      |
| 22:16:24 | +0.3   |      | 34.7 → 100.7 | 0.81 → 3.19 | about +33 rps a minute                               |
| 22:18:49 | +0.2   |      | 103.3 → 24.0 | 3.41 → 0.65 | about -29 a minute, to the floor by 22:21:48         |
| 22:21:58 | +0.25  |      | 26.6         | 0.68 – 0.85 | held from 22:22:37, 3 minutes                        |
| 22:25:45 | +0.27  |      | 26.6 → 49.3  | 0.82 → 1.30 | about +15 a minute                                   |
| 22:27:25 | +0.25  |      | 45.8         | 1.18 – 1.21 | from 50.3 to 45.8, held from 22:29:03, 3 min 40 s    |
| 22:32:48 | +0.23  |      | 45.8 → 27.6  | 1.19 → 0.86 | about -13 a minute                                   |
| 22:34:23 | +0.25  |      | 27.7         | 0.73 – 0.90 | held from 22:34:52, 3 minutes                        |
| 22:38:02 | +0.255 |      | 27.7 → 33.9  | 0.89 → 0.96 | about +3 a minute                                    |
| 22:40:21 | -0.5   | 0.0  | 0            | 0.00        | B38 40.01 °C: 1100 `Aus`, `info` cleared; the finals |

The speed answered a step within one to two rounds. Its rate, per 0.01 kW
of 74 off +0.25: 6.6 rps a minute at +0.3, 5.8 at +0.2, 7.5 at +0.27, 6.5
at +0.23 and 5.8 at +0.255. B38 rose about 0.1 K a minute at the floor,
from 30.5 °C at the start; B125 passed 40 °C at 22:28:33 and B45 at
22:29:03, and they read 41.48 and 41.35 °C at the stop. The PV page printed
`Überschuss` as written, to one decimal; its forecast read 0.8 kW from the
request and 0.9 from 22:06:53. 1004 read 0 and 1098 `nicht gesperrt`
throughout.

## What it shows

- **The speed control's target is +0.25 kW at 74, not 0.** The speed held
  at +0.25 at three speeds, rose at +0.255 and above, and fell at +0.23 and
  below. A rate proportional to the distance from +0.25, at whatever speed,
  is the integral of a PI controller on the error "mean of 74 less 0.25".
  Whether 0.25 is a setting, `N2_PV_POWERTARGET` or a constant, no source
  states.
- **A 74 between 0 and +0.25 holds a run at the floor until the store is
  full.** The speed sank to 24 rps, 0.63 to 0.75 kW, and the run neither
  ended at 8 minutes nor at 30, nor at the minimum runtime; it ended at
  `PV006` 77 minutes after the start. The stops of earlier runs at about 8
  minutes all came with a mean at or below 0; this mean stood above 0
  throughout.
- **A meter-fed 74 aims the controller at an export of +0.25 kW**, not
  at a balance: a consumer that writes the export as measured leaves 0.25
  kW to the grid while the run holds.
- **88 does not move the speed under a regulated run either.** At -1.0
  for 4 minutes, with the speed at the floor and 74 at +0.1, the speed and
  the draw stayed where they were. The steps of 2026-11-07 came 5 to 8
  minutes after the start, while the speed still held the start program's
  50.4 rps.
- **`SSYSPV030` does not weigh in a run with 74 renewed every 10 s**, with
  `SSYSPV031` at No: 1.0 to 0 kW moved nothing in the 10 minutes after.
- **Neither B45 nor B125 at `PV006` ends a run.** Both stood above 40 °C
  for 11 minutes before the stop, which came with B38 at 40.01 °C.

## What the run does not settle

- Why the start program's speed held for 8 min 20 s here, at an error of
  -0.15, when on 2026-11-10 an error of about +0.58 raised it after about 4
  minutes. The fall that followed, about 40 rps a minute, was slower than
  the rate the steps measured would give at -0.15.
- What a clamp does to the swing of a meter-fed loop: the clamp never left
  its upper bound.
- Whether the target is the same with `PV011` at 2.0 min, and for a hot
  water charge.

## Reproducing

With the PV menu as above and `PV011` at 0.1 min:

    IDM_PIN=... idm-web HOST --watch 10 --reason --fachmann 4768 5888 6245 10263 12763 10389 > webwatch.jsonl
    idm-drive HOST schedules/pv-clamp-0-1.toml > drive.jsonl

Once the speed holds the floor, end that drive with SIGKILL and start the
next at once, here `schedules/pv-floor-target-and-steps.toml`, then a
schedule of one phase, `surplus` the value of the step and
`until = "stop"`, as `schedules/pv-floor-0-25.toml`, for each step after.
The last drive writes the finals. After the stop:

    tools/runtable.py drive.jsonl --web webwatch.jsonl
    IDM_PIN=... idm-web HOST --enter-fachmann
    IDM_PIN=... tools/webprobe.py HOST > webapi.json
    IDM_PIN=... idm-web HOST --leave-fachmann
