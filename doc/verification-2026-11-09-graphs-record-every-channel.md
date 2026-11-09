# The controller records every graph channel, whether or not a graph holds it

2026-11-09, evening. Graphs created in the web interface by hand, then read
with `tools/webprobe.py`, to learn whether a channel that no graph held had
a history, and so whether the flow or the charge sensor at the stop of the
run of `doc/verification-2026-11-09-power-limit-held-at-1-0.md` can still be
read.

It does. A channel put into a new graph answered with the same history as
one that had always been in a graph, back to 2026-11-01 in the eight-day
span, which is as far as any graph reaches. A graph chooses what a read
returns, not what the controller records. Seven graphs now hold all 37
channels `graph`/`traverse` lists at Kunde level, among them 112 and 365,
which no graph held before
(`doc/verification-2026-11-09-heating-run-as-on-1574.md`). The flow, B33,
is no graph channel at either level.

## What was done

Before: the three graphs of 20.24-2608, `System` (1), `WW` (100) and `PV`
(101), holding 1, 5, 7, 363, 183, 184 and 10000 to 10004
(`captures/navigator-10-webapi-20.24-2608-2026-11-09-1807.json`, from
18:07). In the web interface, by hand: `WW` renamed `Warmwasser`, 280 and
281 added to `PV`, and the graphs `Anlage` (102), `HK A und B` (103), `HK D` (104)
and `Pumpe und Kreise` (105) created. A graph is changed by a `save`, which
`tools/webprobe.py` does not send. Two walks after, at Kunde level, none of
whose requests failed: one with `Anlage` alone
(`captures/navigator-10-webapi-20.24-2608-2026-11-09-1819.json`) and one
with all seven (`captures/navigator-10-webapi-20.24-2608-2026-11-09-1829.json`).
Each asks every graph for the last 30 hours (`fromSecs` 108000) and the
last eight days (691200), as the web interface does.

## What the graphs answered

| Graph            | Channels                                         |
| ---------------- | ------------------------------------------------ |
| System           | 1, 5, 7, 363, 10000, 10001, 10003, 10004         |
| Warmwasser       | 7, 363                                           |
| PV               | 183, 184, 280, 281                               |
| Anlage           | 1, 5, 7, 36, 37, 38, 73, 80, 213, 363            |
| HK A und B       | 9, 11, 16, 18, 63, 65, 99, 101, 106, 108         |
| HK D             | 12, 66, 102, 109                                 |
| Pumpe und Kreise | 53, 58, 59, 112, 365, 10000, 10001, 10003, 10004 |

Every channel the new graphs added had points from before them: 213 B45
`Ladefühler` from 2026-11-01 18:27, 80 `T15x_BETRIEBSART_SYSTEM` from
2026-11-01 22:14, 112 and 365 from 2026-11-01 18:05 and 18:31, 106, 108,
109 and 102
from 2026-10-31 23:58. A channel that holds a state answers a point per
change: 36, 37, 38, 58 and 59 answered a single point, at the time of the
read, and so did not change in eight days. `HK A und B` holds circuit C
too; the machine has no circuit B.

The samples are sparse and grow sparser with age. In the 30-hour span a
temperature has a point about every 50 minutes, in the eight-day span
about every 1.6 hours, but the last half hour about every 5 minutes. A
state channel has one per change in both.

The span does not make the samples denser: the controller thins what it
keeps. At 18:36 `Anlage` was asked for the last 2 hours, the shortest span
the web interface plots, and for two past windows by `toSecs`, which the
web interface sends but leaves unset
(`captures/navigator-10-webgraph-20.24-2608-2026-11-09-1836.json`). The 2
hours answered B45 and B38 at 16:32, 17:23 and then every 5 minutes from
18:09; the points from 17:38 to 18:04 that the walk of 18:19 had answered
were gone. A past window answered the points the longer spans have, three
for 2026-11-08 18:30 to 20:30. A five-minute sample lasts about half an
hour, so a graph read soon after an event sees it at that grain, and later
at about 50 minutes. A graph says what the machine did while nobody
watched; it does not replace a watch.

No request reads a channel apart from a graph: the web interface's
JavaScript (`captures/navigator-10-webui-20.24-2608-2026-11-05-1641/`)
sends `graph`/`overview`, `traverse`, `detail` with a graph's `id`, and
`save`, which creates, changes or removes a graph.

## What it settles

- **112 and 365 can be read.** `doc/software-versions.md` said no graph
  held them and a read could not reach them; `Pumpe und Kreise` holds them
  now, with their history.
- **B45 at the stop of the run at 1.0.** The graph has B45 at 38.0 °C at
  17:54, 38.7 at 17:59, 39.5 at 18:04 and 39.0 at 18:09, B38 at 36.2, 37.0,
  37.8 and 37.7. The run stopped at 18:02. B45 was near 40, but whether it
  reached it the samples do not say; for the runs of 2026-11-08 and the noon
  of 2026-11-09 the 30-hour span has one point of B45 each.

## What it does not settle

- **The channels of the Fachmann level.** At Fachmann level `traverse`
  lists 54 channels (`captures/navigator-10-webapi-20.24-2608-2026-11-09-1243.json`),
  17 more than at Kunde: 23 B71, 26 B37, 28 B79, 29 B78, 55 M51, 60 M63,
  76, 91, 93, 145, 146 `T25x_AIN_TCOND`, 148 `T23xPRS`, 149, 153 B86, 180,
  182 B87 and 188. No graph holds them, and whether a graph holding them
  answers at Kunde level is untried.
- **How far back the history reaches** past the eight days the web
  interface asks for.

## Reproducing

Create the graphs in the web interface, then

    IDM_PIN=... tools/webprobe.py HOST > webapi.json
