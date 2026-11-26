# A graph's state channel keeps one point per five minutes

2026-11-26, on 20.24-2608, from captures of 2026-11-09, 2026-11-24 and
2026-11-26. A state channel of a graph does not have a point at every
change. A change within five minutes of the channel's last point is
stamped five minutes after that point, with the state the channel holds
then. Every point compared fits this rule: the compressor's M1 against
1100 through a defrost, and circuit D's pump M34 against the web watch.
So M1 reads 0 for the first five minutes of every defrost, though the
compressor runs from about a minute in.

## What was compared

- **A defrost on 2026-11-09.** 1090 and 1100 read every 10 s
  (`captures/navigator-10-watch-20.24-2608-2026-11-09-1450.jsonl`),
  against graph 105's M1, channel 53 `T23x_COMPRESSOR`, and graph 1's
  10004 `N2_DEFROSTING`, in the walk of 18:29
  (`captures/navigator-10-webapi-20.24-2608-2026-11-09-1829.json`).
- **Circuit D's pump M34 on 2026-11-24.** 4789 `N2_DIGITAL_OUTPUTS` read
  every 30 s
  (`captures/navigator-10-webwatch-20.24-2608-2026-11-24-2244.jsonl`),
  against graph 104's channel 66 `T21x_PUMPHEATINGCIRCUIT_D`
  (`captures/navigator-10-webgraph-20.24-2608-2026-11-24-2308.json`);
  the run is
  [2026-11-24-a-circuits-pump-stops-while-its-flow-is-above-its-maximum](2026-11-24-a-circuits-pump-stops-while-its-flow-is-above-its-maximum.md).
- **The 25 defrosts from 2026-11-19 to 2026-11-26**, in the eight-day span
  of the walk of 2026-11-26 at 20:36
  (`captures/navigator-10-webapi-20.24-2608-2026-11-26-2036.json`), whose
  graphs hold M1, 10004, 80 `T15x_BETRIEBSART_SYSTEM` and 55
  `T23x_4WAYVALVE`.

A graph's time is the controller's clock. On 2026-11-09 the defrost's edges
put it 21 s ahead of the watch's: 1090 first read 8 at 15:42:52 and 1 again
at 15:50:12, and 10004 rose at 15:43:13 and fell at 15:50:33. A watch read
gives a change to within its interval, 10 s.

## The readings

The defrost of 2026-11-09, the compressor by 1100 and by M1:

| Event                            | 1100, first read | The same, +21 s | M1          |
| -------------------------------- | ---------------- | --------------- | ----------- |
| Heating starts the compressor    | 15:16:32         | 15:16:53        | 1, 15:17:01 |
| Defrost begins, compressor stops | 15:42:52         | 15:43:13        | 0, 15:43:13 |
| Compressor starts                | 15:43:52         | 15:44:13        | 1, 15:48:13 |
| Defrost ends, compressor stops   | 15:50:12         | 15:50:33        | 0, 15:53:13 |
| Compressor starts                | 15:53:32         | 15:53:53        | 1, 15:58:13 |

Between 15:43:52 and 15:50:12 the compressor ran: 4122 read 0.29 to
2.22 kW and 4126 fell to -8.61 kW. M1's first two points of the defrost
came at changes after hours without one. Each later point came 5:00 after
the one before, at the next change: the start at 15:44:13 shows at 15:48:13,
the stop at 15:50:33 at 15:53:13, the start at 15:53:53 at 15:58:13.

Circuit D's pump on 2026-11-24, the web watch's times and the graph's:

| Event          | 4789, first read | M34, graph  |
| -------------- | ---------------- | ----------- |
| The pump runs  | 22:45:13         | 1, 22:45:31 |
| The pump stops | 22:59:43         | 0, 23:00:01 |
| The pump runs  | 23:01:43         | 1, 23:05:01 |

The controller's clock was 18 s ahead here. The start at about 23:02:01,
two minutes after the stop's point, shows at 23:05:01, 5:00 after it.

In all 25 defrosts of the eight days, M1 goes to 0 in the second 10004
rises and back to 1 5:00 to 5:02 later, while the defrost lasts 5:27 to
6:52. After four of them (2026-11-22 14:12, 2026-11-23 10:31,
2026-11-25 09:16 and 11:37) M1 reads 0 again ten minutes from the start
and 1 at fifteen: a stop after the defrost, as on 2026-11-09, whose times
the graph does not give. Outside a defrost, M1's changes come where the
registers put them: every morning's heating request, at 05:15:00 to
05:15:02, shows the compressor's start 51 to 54 s later, the 50 s a start
takes
([heat-pump.md](../heat-pump.md#a-start-and-a-stop)), and a stop in the
second of the mode's change.

## What it shows

- **A state channel holds at most one point per five minutes.** A change
  more than five minutes after the channel's last point is stamped at its
  time; one sooner is stamped five minutes after that point, with the
  state then.
- **M1 says nothing about the compressor in a defrost.** It reads 0 for
  the first five minutes, while the compressor stood about one minute and
  ran the rest. The compressor in a defrost, and in the minutes after it,
  is read from 1100, 4122 or the inverter's page 6245.
- **A short stop leaves no point**, predicted and not yet seen: a stop and
  a start both within five minutes of the last point leave the state the
  channel had.

## Open

- Whether every state channel keeps the rule; it was seen in M1 and M34.
  The defrost's own channels, 10004, 80 and 55, change about six minutes
  apart, so the defrosts read here do not test it.
- Whether a line channel's 5-minute points
  ([web-backend.md](../web-backend.md#graphs)) are the same grid.

## Reproducing

A watch of 1090 and 1100 every 10 s through a defrost, then a walk at
Fachmann level, or `graph`/`detail` of a graph holding M1 and 10004:

    cabal run idm-dump -- HOST --watch 10 1090 1100 4122 4126 > watch.jsonl
    IDM_PIN=... tools/webprobe.py HOST > webapi.json
