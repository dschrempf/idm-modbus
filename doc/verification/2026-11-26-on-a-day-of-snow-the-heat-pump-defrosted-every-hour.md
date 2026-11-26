# On a day of snow the heat pump defrosted every hour

2026-11-26, on 20.24-2608. On a day of heavy snow, at 0.5 to 1.8 °C
outdoors, the heat pump defrosted ten times in 11.8 hours of operation,
eight of them 53 to 60 minutes after the one before, the compressor
running between them. On the seven days before, at -3.9 to 11.7 °C, it
defrosted once in 2.9 to 10.8 hours of operation. The outdoor temperature
does not explain the difference: the two days before were colder. Every
defrost lasted about six minutes, 19 of the 25 to within a second of it.

## What was recorded

The walk at Fachmann level at 20:36
(`captures/navigator-10-webapi-20.24-2608-2026-11-26-2036.json`), which asks
every graph for the last eight days. Its state channels reach back to
2026-11-19 05:15, its temperatures to 12:58 that day. The channels read:

| Channel                                  | What it gives                                 |
| ---------------------------------------- | --------------------------------------------- |
| 10004 `N2_DEFROSTING`                    | a defrost's start and end                     |
| 80 `T15x_BETRIEBSART_SYSTEM`             | the mode: 1 heating, 4 hot water, 8 defrost   |
| 55 `T23x_4WAYVALVE`, M51                 | the 4-way valve                               |
| 53 `T23x_COMPRESSOR`, M1                 | the compressor, outside a defrost (see below) |
| 1 `T25x_AIN_TAUS`, 26 `T25x_AIN_TAIR_IN` | outdoor and intake air, each point a mean     |

The times are the controller's clock, about 30 s ahead of the host's. In
the eight-day span a temperature's point is the mean over about 1.6 hours
([web-backend.md](../web-backend.md#graphs)), too coarse to show the air
or the evaporator around a defrost. M1 reads 0 for the first five minutes
of every defrost, though the compressor runs from about a minute in
([2026-11-26-a-graphs-state-channel-keeps-one-point-per-five-minutes](2026-11-26-a-graphs-state-channel-keeps-one-point-per-five-minutes.md));
it is read here only between defrosts. The snow is the household's
account; no channel measures snow or humidity.

The defrost settings, as the walk read them:

| Setting                                | Value    |
| -------------------------------------- | -------- |
| `CL001` `N2_TEMP_DEFROST_END`          | 36 °C    |
| `CL002` `N2_DEFROST_RELEASE_TEMP`      | 25 °C    |
| `CL005` `N2_DEFROST_BLOCK_TIME`        | 30 min   |
| `CL006` `N2_DEFROST_DOWNTIME_TIME`     | 180 s    |
| `CL008` `N2_DEFROST_SAFETY_DEFROSTING` | 0 h      |
| `CL014` `N2_MAX_DEFROST_TIME`          | 15 min   |
| `CL016` `N2_DEFROST_FAN_SPEED`         | 0        |
| `IV007` `N2_MOD_DEFROST_POWER`         | 65 %     |
| `IV014` `N2_DEFROST_DIFFERENCE`        | 50       |
| `WP029` `N2_MIN_FLOW_LIMIT_DEFROST`    | 10 l/min |

## How a defrost shows

- 80 goes to 8 and 10004 to 1 in the same second, and both go back to the
  mode before at the end. Twice that was a hot water charge, on 2026-11-21
  at 13:36 and 2026-11-26 at 13:12, and each charge went on after the
  defrost.
- M51 switches 15 to 22 s after the start and back in the second the
  defrost ends.
- 19 of the 25 lasted 5:59 to 6:01. The others lasted 5:27 (the one in
  the charge of 2026-11-21), 6:10, 6:14, 6:16, 6:49 and 6:52. The defrost
  of 2026-11-09 lasted 7:20
  ([2026-11-26-a-graphs-state-channel-keeps-one-point-per-five-minutes](2026-11-26-a-graphs-state-channel-keeps-one-point-per-five-minutes.md)),
  and the one of 2026-10-16, on 20.24-1574, 8:20 to 8:30 by its reads
  every 10 s (`captures/navigator-10-watch-20.24-1574-2026-10-16-0745.jsonl`,
  [2026-10-16-draw](2026-10-16-draw.md)).

## How often

"Operation" is the time 80 stood at a mode other than 0: heating, hot
water, defrost, and the standstills a mode holds, such as the minimum
standstill after a charge. Every day began with a heating request at
05:15.

| Day        | Outdoor, °C             | Operation, h | Defrosts | Starts                            | Operation per defrost, h |
| ---------- | ----------------------- | ------------ | -------- | --------------------------------- | ------------------------ |
| 2026-11-19 | 9.1 to 10.1, from 12:58 | 10.8         | 2        | 07:05, 08:58                      | 5.4                      |
| 2026-11-20 | 8.4 to 11.7             | 10.8         | 1        | 06:03                             | 10.8                     |
| 2026-11-21 | 3.5 to 9.2              | 9.4          | 1        | 13:36, in a hot water charge      | 9.4                      |
| 2026-11-22 | -0.4 to 5.9             | 11.8         | 4        | 06:24, 07:35, 10:40, 14:12        | 2.9                      |
| 2026-11-23 | -0.3 to 4.1             | 10.9         | 2        | 07:02, 10:31                      | 5.4                      |
| 2026-11-24 | -3.4 to 4.2             | 11.8         | 2        | 07:37, 11:03                      | 5.9                      |
| 2026-11-25 | -3.9 to 2.5             | 9.6          | 3        | 07:31, 09:16, 11:37               | 3.2                      |
| 2026-11-26 | 0.5 to 1.8              | 11.8         | 10       | 06:04, then about hourly to 15:43 | 1.2                      |

The outdoor range is that of the means, not of the readings. On the mild
days a run went on for seven to ten hours without one: on 2026-11-19 from
09:05 to 16:02, on 2026-11-20 from 06:09 to 16:00, on 2026-11-21 from 05:15
to 12:40. Where a day's first defrost came in the morning, it came 48
minutes (2026-11-20 and 2026-11-26) to 2 h 22 min (2026-11-24) after the
request at 05:15.

On 2026-11-26:

| Start    | End      | Apart from the last | Between                                          |
| -------- | -------- | ------------------- | ------------------------------------------------ |
| 06:04:08 | 06:10:09 | 0:48:14             | the compressor's start at 05:15:54               |
| 07:03:56 | 07:09:55 | 0:53:47             |                                                  |
| 08:06:03 | 08:12:03 | 0:56:08             |                                                  |
| 09:05:25 | 09:11:24 | 0:53:22             |                                                  |
| 10:05:46 | 10:11:46 | 0:54:22             |                                                  |
| 11:05:35 | 11:11:34 | 0:53:49             |                                                  |
| 12:06:19 | 12:12:19 | 0:54:45             |                                                  |
| 13:12:01 | 13:18:01 | 0:59:42             | hot water from 12:59:59                          |
| 14:41:38 | 14:47:38 | 1:23:37             | the charge's end at 14:10:25, a stop to 14:20:44 |
| 15:43:51 | 15:49:51 | 0:56:13             |                                                  |

Apart from the stop after the charge, the compressor ran from 05:15:54 to
17:04:00; M1 shows no other stop between the defrosts. Of those 11 h 48 min,
an hour was defrost. On 2026-11-24, by contrast, it ran without a stop from
the end of one defrost at 07:43:31 to the start of the next at 11:03:29,
3 h 20 min, at outdoor means of -1.6 to 1.1 °C.

## What it shows

- **A defrost lasts six minutes** on 20.24-2608, and goes back to the
  mode it interrupted, a hot water charge included.
- **How often one comes is not the outdoor temperature's.** At 0.5 to
  1.8 °C, eight came 53 to 60 minutes after the one before; at -3.9 to
  4.2 °C on the days before, 2.9 to 5.9 hours of operation went to one.
  Snow, or the humidity that came with it, is the likely difference, and
  no channel the controller records measures either.
- **After a defrost, none came sooner than 53 minutes**, on the day they
  came most often; `CL005`'s block time is 30 min.

## Open

- What starts a defrost: the stretches of 53 to 60 minutes on the day the
  evaporator iced fastest suggest a floor in the controller, but no
  setting read is 50 to 60 minutes.
- What ends one: 19 of 25 lasted six minutes to the second, short of
  `CL014`'s 15 min; whether `CL001`'s 36 °C is reached that evenly, or a
  time ends it, is not known.
- What a defrost costs: 1756 `Wärmemenge Abtauung`, by its name the
  defrosts' heat, read 43.82 kWh in the scan at 20:48
  (`captures/navigator-10-scan-20.24-2608-2026-11-26-2048.json`), but no
  scan from the morning stands beside it. Two scans a day apart would give
  a day's.
- What happens around a defrost below the graph's resolution: the air, the
  evaporator and the flow in the minutes before and after. A watch, at
  Fachmann level for 4768 and 5888, through a defrost would show it.

## Reproducing

    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
    IDM_PIN=... tools/webprobe.py HOST > webapi.json
    IDM_PIN=... cabal run idm-web -- HOST --leave-fachmann

and the eight-day span, `fromSecs` 691200, of the graphs holding 10004, 80,
55, 53, 1 and 26 read from it.
