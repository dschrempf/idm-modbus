# A circuit's pump stops while its flow is above its maximum, `HSx04`

2026-11-24, evening, on 20.24-2608, at -3.3 °C outdoors. Circuit D's pump
M34 started when D went into Normal at about 21:31 and stopped at 21:40.
It then stayed off for an hour, while D read "Heizen", a set flow of
20.00 °C and a request, and its flow B54 stood at 21.9 to 23.4 °C, above
D's maximum flow, `HSD04` 20 °C. Raising `HSD04` to 35 °C at the display
started the pump within 30 s, with B54 at 21.9 °C, still above the set
flow: the pump stops on the maximum, not on the set flow. D's mixer is
faulty, so while the pump ran, the flow rose to the buffer's temperature
although the mixer was driven "Zu".

## What was set

| Setting                                  | Value                                                           |
| ---------------------------------------- | --------------------------------------------------------------- |
| `HKD01` `N2_HC_D_MODE`, 1396             | `Manuell Heizen` at 21:29 and 21:30, `Zeitprogramm` from 21:31  |
| `HKD06` `N2_HC_D_PROGRAM`                | Normal 04:00 to 06:00 daily, and on that Tuesday 21:00 to 23:00 |
| `HKD04`, `HKD05` room target Normal, Eco | 15 °C, 10 °C                                                    |
| `HKD08` `N2_HC_HEATING_LIMIT`            | 6 °C                                                            |
| `HKD10` `N2_HC_HEATING_SLOPE`            | 0.3                                                             |
| `HSD04` `N2_HC_MAX_FLOW_TEMP`, 8310      | 20 °C; 35 °C from between 22:41 and 22:44:43                    |
| `HSD05` `N2_HC_MIN_FLOW_TEMP`            | 12 °C                                                           |
| `HSD40` `N2_HC_FROST_PROTECTION`, 8436   | `N2_NO`, as since 2026-11-06                                    |

The settings were read with `idm-web --show` at 22:39 at Fachmann level,
entered by `idm-web --enter-fachmann`, and printed, not captured. `HSD04`
was changed by hand at the display, at one EEPROM cycle, and the Normal
window of the day extended to 24:00 at about 23:01. Nothing was written to
a register.

## What was recorded

- `idm-dump --watch 20` of 1396, 1501, 1384, 1356, 1008, 1002, 1090 and
  1091, 21:29 to 21:31
  (`captures/navigator-10-watch-20.24-2608-2026-11-24-2129.jsonl`), and
  again 22:17 to 22:18 with 1012
  (`captures/navigator-10-watch-20.24-2608-2026-11-24-2217.jsonl`).
- Circuit D's page, `system.heatingcircuit` `detail` of `D`, at 22:41,
  printed, not captured.
- `idm-web --watch 30` of 8310 `HSD04`, 4789 `N2_DIGITAL_OUTPUTS` and 4768
  `N2_SENSORS`, 22:44:43 to 23:04:44
  (`captures/navigator-10-webwatch-20.24-2608-2026-11-24-2244.jsonl`).
- Graphs 1, 102, 104, 105 and 107, three hours back, at 23:08
  (`captures/navigator-10-webgraph-20.24-2608-2026-11-24-2308.json`). A
  line channel's point is an average over its interval, about 50 minutes
  before 22:41 and 5 minutes after; a step channel's point is a change.
  M34's changes there lag the watch's by up to 20 s, and the one at about
  23:01 shows as 23:05:01, so the times below are the watch's where it
  has them. Why the one shows four minutes late is
  [2026-11-26-a-graphs-state-channel-keeps-one-point-per-five-minutes](2026-11-26-a-graphs-state-channel-keeps-one-point-per-five-minutes.md).

## The readings

| Time     | Source   | D's mode                   | 1384 set flow | B54 flow | B38 buffer | M34 | M44   |
| -------- | -------- | -------------------------- | ------------- | -------- | ---------- | --- | ----- |
| 21:29:25 | watch    | `Manuell Heizen`, "Heizen" | 0.00          | 19.27    | 28.23      |     |       |
| 21:31:04 | watch    | `Zeitprogramm`, "Heizen"   | 0.00          | 19.28    | 28.22      |     |       |
| 21:33:59 | graph    |                            |               |          |            | 1   |       |
| 21:40:22 | graph    |                            |               |          |            | 0   |       |
| 22:17:02 | watch    | `Zeitprogramm`, "Heizen"   | 20.00         | 23.40    | 27.56      |     |       |
| 22:41    | page     | `activeMode` 1, `demand` 1 | 20.0          | 22.1     |            | off |       |
| 22:44:43 | webwatch |                            |               | 21.9     | 27.3       | 0   | "Aus" |
| 22:45:13 | webwatch |                            |               | 21.9     | 27.3       | 1   | "Aus" |
| 22:46:43 | webwatch |                            |               | 22.2     | 27.3       | 1   | "Zu"  |
| 22:52:14 | webwatch |                            |               | 26.5     | 26.9       | 1   | "Zu"  |
| 22:59:14 | webwatch |                            |               | 28.1     | 26.5       | 1   | "Zu"  |
| 22:59:43 | webwatch |                            |               | 28.2     | 26.5       | 0   | "Zu"  |
| 23:01:43 | webwatch |                            |               | 28.1     | 26.4       | 1   | "Zu"  |
| 23:04:44 | webwatch |                            |               | 28.2     | 26.2       | 1   | "Zu"  |

The mode is 1396 and 1501, or the page's `mode` and `activeMode`; the page
reads M34 as `pumpActive` false. At 22:41 the page also read `heatLimit`
6, `avgOutdoor` 0.4 and `outdoor` -3.3, and at 22:36 the heat pump was at
rest: 1090 `Standby`, 1091 `Keine Anforderung`. M34 stopped at 22:59:43, as the Normal window ended at 23:00, and ran again
from 23:01:43, once it was extended. D's set flow, a graph average, read
20.00 until 22:41 and 20.2 to 20.6 after `HSD04` went to 35 °C.

## What it shows

- **The pump stops while the flow is above `HSx04`.** With `HSD04` at
  20 °C, M34 stayed off with B54 at 21.9 to 23.4 °C and D in "Heizen"
  with a request. With `HSD04` at 35 °C, it started within 30 s at the
  same 21.9 °C, the only setting changed.
- **The set flow does not stop it.** It started, and ran on, with B54 above
  the set flow of 20.0 to 20.6 °C.
- **`HSx04` caps the set flow.** 1384 read exactly 20.00, `HSD04`, until
  the maximum went to 35 °C, and then the curve's 20.2 to 20.6.
- **With D's mixer faulty, D's flow is the buffer's temperature.** B54 rose
  from 21.9 to 28.2 °C in 14 minutes with M44 driven "Zu", and ended above
  B38's 26.2 °C. With a maximum below the buffer's temperature the pump
  stops minutes after it starts, as at 21:40.

## Open

- At what flow below `HSx04` a stopped pump starts again: B54 never fell
  below 20 °C while `HSD04` was 20 °C.
- Whether the maximum stops a circuit's frost protection too. On
  2026-11-06 frost protection ran M34 with B54 above 21 °C, but `HSD04`
  was 40 °C then (`captures/navigator-10-webapi-20.24-2608-2026-11-06-1148.json`).
- Earlier that day the graph had M34 running from about 04:57 to 06:39
  with B54 averaging 25.8 to 27.4 °C, above the 20 °C `HSD04` read at
  21:10. Whether `HSD04` was 20 °C that morning is not recorded.
- `Manuell Heizen` read a set flow of 0.00 °C for the minute it was held,
  21:29:25 to 21:30:24.
