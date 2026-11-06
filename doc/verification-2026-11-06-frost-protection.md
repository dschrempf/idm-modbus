# Frost protection runs a circuit's pump below 3 °C, whatever its mode

2026-11-06. At 1.5 °C outdoors the pumps of all three heating circuits ran,
with the heat pump at rest, every circuit's `Aktive Betriebsart` at "Aus",
and one circuit switched off. Each circuit's `Sollvorlauftemperatur` read
10.00 °C, where an inactive circuit had read 0.00 °C in every scan before.
Switching frost protection off for circuit D alone, `HSD40`, stopped its
pump M34 and set its target to 0.00 °C, while A and C kept running at
10.00 °C. The circuits' frost protection is what runs the pumps below
`AE025`, 3 °C, and its flow target is 10 °C, not `AE026`'s 20 °C.

## What was set

| Setting                                          | Before   | After    |
| ------------------------------------------------ | -------- | -------- |
| `AE025` `N2_FROST_PROTECTION_OUTDOOR_TEMP`, 5748 | 3 °C     | 3 °C     |
| `AE026` `N2_FROST_PROTECTION_FLOW_TEMP`, 5755    | 20 °C    | 20 °C    |
| `CF085` `N2_FROSTPROTECTION_HEATING_SIDE`, 12664 | 2        | 2        |
| `HSA40` `N2_HC_FROST_PROTECTION`, circuit A      | `N2_YES` | `N2_YES` |
| `HSC40` `N2_HC_FROST_PROTECTION`, circuit C      | `N2_YES` | `N2_YES` |
| `HSD40` `N2_HC_FROST_PROTECTION`, circuit D      | `N2_YES` | `N2_NO`  |

`CF085`'s 2 is `N2_YES_WITHSEPERATIONHEATEXCHANGER_KIT`. Before, the webapi
capture at Fachmann level, 11:50 to 11:56
(`captures/navigator-2.0-webapi-20.24-2608-2026-11-06-1148.json`); after,
read by `idm-web --show` at 21:23
(`captures/navigator-2.0-show-20.24-2608-2026-11-06-2120.txt`). `HSD40` was
changed by hand at the display between 21:07 and 21:17, at one EEPROM cycle,
with the Fachmann level entered by `idm-web`. The circuits' modes stayed as
they were: A and C `Zeitprogramm`, D `Aus` (1393, 1395, 1396; `HKA01`,
`HKC01`, `HKD01`). Nothing was written to a register.

## What was recorded

- 11:50, at 7.3 °C by the sensor page, the webapi capture above: 4789
  `N2_DIGITAL_OUTPUTS`; 1090, 1091 and 1100 from the watch of that run
  (`captures/navigator-2.0-watch-20.24-2608-2026-11-06-1102.jsonl`).
- 21:02 to 21:06, with frost protection on for all three circuits:
  `idm-dump HOST` and `idm-web HOST --show 4789 5748 5755 12664 7092 7988 8436`,
  printed to the terminal and not captured. The values below are quoted from
  that output.
- 21:20 to 21:23, after the change: a scan
  (`captures/navigator-2.0-scan-20.24-2608-2026-11-06-2120.json`) and the
  show above, the level changes around it in
  `captures/navigator-2.0-level-20.24-2608-2026-11-06-2120.log`.

## The readings

| Register or output                    | 11:50   | 21:02–21:06 | 21:20–21:23 |
| ------------------------------------- | ------- | ----------- | ----------- |
| 1000 B32 `Außentemperatur`            | 7.3     | 1.58        | 1.50        |
| 1002 `Gemittelte Außentemperatur`     |         | 4.59        | 4.52        |
| 1060 B37 `Luftansaugtemperatur`       | 6.7     | 0.80        | 0.77        |
| 1378 `Sollvorlauftemperatur` A        |         | 10.00       | 10.00       |
| 1382 `Sollvorlauftemperatur` C        |         | 10.00       | 10.00       |
| 1384 `Sollvorlauftemperatur` D        |         | 10.00       | 0.00        |
| 1498, 1500, 1501 `Aktive Betriebsart` |         | "Aus"       | "Aus"       |
| M31 `Pumpe Heizkreis A`               | 0       | 1           | 1           |
| M33 `Pumpe Heizkreis C`               | 0       | 1           | 1           |
| M34 `Pumpe Heizkreis D`               | 0       | 1           | 0           |
| M41, M43 `Mischer Heizkreis` A, C     | "Aus"   | "Zu"        | "Zu"        |
| M44 `Mischer Heizkreis D`             | "Aus"   | "Zu"        | "Aus"       |
| 1090, 1091, 1100                      | at rest | at rest     | at rest     |

The 11:50 temperatures are the sensor page's, 4768 `N2_SENSORS`, to one
decimal. "At rest" is 1090 `Standby`, 1091 `Keine Anforderung` and 1100
`Aus`. 1004 read 0 at 21:02 and 21:20. The circuits' flows, B51, B53 and
B54, stood above 21 °C throughout.

In every scan before, from `navigator-2.0-scan-20.24-1574-2026-09-19-1503.json`
to `navigator-2.0-scan-20.24-2608-2026-11-05-1617.json`, at 7.4 to 23.0 °C
by B32, a circuit whose `Aktive Betriebsart` read "Aus" read 0.00 °C at its
`Sollvorlauftemperatur`, D included.

## What it shows

- **A circuit's frost protection overrides its mode.** D's `Betriebsart`
  "Aus" left its pump running; `HSD40` stopped it. Of the modes, only the
  system's "Aus", -1 at 1005, is documented to stop frost protection
  (`doc/verification-2026-10-15-web-app.md`).
- **Its flow target is 10 °C.** 1384 went from 10.00 to 0.00 °C with
  `HSD40` the only change, while 1378 and 1382 stayed at 10.00. `AE026`
  reads 20 °C, so whatever it governs, it is not the circuit's target. With
  the flow above the target the mixer is driven closed, "Zu", and the pump
  runs; with protection off the mixer is not driven, "Aus", as at 11:50.
- **It keys on a current temperature, not the average.** It ran with 1002 at
  4.59 °C, above `AE025`, and B32 and B37 both below it. Which of the two
  it reads is not settled.
- **It asks nothing of the heat pump** while the flows stay above 10 °C:
  1090, 1091 and 1100 stayed at rest throughout.

## Open

- Where it lets go: the input, B32 or B37, and any hysteresis above
  `AE025`. A watch across a rise past 3 °C settles both:

      cabal run idm-dump -- HOST --watch 60 1000 1060 1378 1382 1384 > watch.jsonl
      IDM_PIN=... cabal run idm-web -- HOST --watch 60 4789 > webwatch.jsonl

- What `AE026`'s 20 °C governs, and whether `AE025` also feeds `CF085`, the
  protection of the separation heat exchanger.
- Whether the status overview's `frostProtectionInfo` reflects a circuit's
  frost protection. It read `active` false at 11:48, at 7.3 °C; it was not
  read while the pumps ran.
