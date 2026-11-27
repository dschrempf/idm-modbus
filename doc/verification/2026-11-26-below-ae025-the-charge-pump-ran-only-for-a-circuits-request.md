# Below `AE025` the charge pump ran only for a circuit's request

2026-11-26 21:10 to 2026-11-27 06:13, on 20.24-2608. At 0.1 to 0.6 °C
outdoors, below `AE025`'s 3 °C, the charge pump M73 stood for over five
hours while the intermediate circuit's B33 fell to 13.9 °C and B34 to
8.6 °C, both below `AE026`'s 20 °C. It ran only for circuit C's heating
requests, at 02:28 and 04:56, and through a defrost; the request reason
never read `RD_REQ_FROST_PROT`. At rest the heat sink's B124 and B125
never fell below 21.4 °C. 4789's M73 read 100 in every read, at rest and running
alike: it is the pump's on/off output, not whether it runs.

## What was set

Nothing was changed. As the walks of 2026-11-26 at 20:36
(`captures/navigator-10-webapi-20.24-2608-2026-11-26-2036.json`) and
2026-11-27 at 06:14
(`captures/navigator-10-webapi-20.24-2608-2026-11-27-0614.json`) read them:

| Setting                                            | Value                                       |
| -------------------------------------------------- | ------------------------------------------- |
| `AE025` `N2_FROST_PROTECTION_OUTDOOR_TEMP`, 5748   | 3 °C                                        |
| `AE026` `N2_FROST_PROTECTION_FLOW_TEMP`, 5755      | 20 °C                                       |
| `CF085` `N2_FROSTPROTECTION_HEATING_SIDE`          | 2, `N2_YES_WITHSEPERATIONHEATEXCHANGER_KIT` |
| `HSA40`, `HSC40`, `HSD40` `N2_HC_FROST_PROTECTION` | `N2_NO`                                     |
| `HKA01`, `HKC01`, `HKD01`                          | `N2_TIMETABLE`                              |
| `HKD06`, D's Normal windows                        | 04:00 to 06:00, 17:00 to 19:00              |
| `HSD04`, D's maximum flow                          | 35 °C                                       |

No circuit was in frost protection, so a circuit's pump ran only for its
timetable: C's from 21:35 on, D's in its Normal window.

## What was recorded

    idm-dump HOST --watch 60 1000 1060 1008 1072 1074 1090 1091 1100 1104 1356 1501
    idm-web HOST --watch 60 --reason --fachmann 4768 4789

`captures/navigator-10-watch-20.24-2608-2026-11-26-2110.jsonl` and
`captures/navigator-10-webwatch-20.24-2608-2026-11-26-2110.jsonl`, both
from 21:10 to 06:13 without a lost read; their `.stderr` files are empty.
The web watch held the Fachmann level for 4768's intermediate circuit,
renewing it every 56 to 57 minutes; its level lines say when. 4768
`N2_SENSORS` gives B32, B33/B113, B34/B114, B124, B125 and B2; 4789
`N2_DIGITAL_OUTPUTS` gives M1, M73 and the circuits' pumps; the `system`
overview gives the request reason. The times are the host's; the
controller's clock runs about 30 s ahead.

## The night

Each cell is the lowest to the highest reading of the span.

| Time        | State (1090, reason)       | 1074   | 1072, l/min | B33, °C   | B34, °C   | B125, °C  |
| ----------- | -------------------------- | ------ | ----------- | --------- | --------- | --------- |
| 21:10–02:27 | standby                    | `ffff` | 0.0         | 13.9–20.4 | 8.6–11.7  | 21.7–25.5 |
| 02:28–03:09 | heating, 513 `RD_REQ_HK_C` | 60–100 | 22.5–33.0   | 13.9–33.1 | 8.6–28.0  | 18.7–28.7 |
| 03:10–04:55 | standby                    | `ffff` | 0.0         | 22.5–28.7 | 8.2–28.1  | 25.9–28.8 |
| 04:56–05:40 | heating, 513 `RD_REQ_HK_C` | 69–100 | 26.3–33.3   | 18.6–34.3 | 13.6–28.7 | 22.4–30.0 |
| 05:41–05:46 | defrost, no reason         | 100    | 32.3–32.6   | 18.8–30.1 | 26.2–28.7 | 24.5–29.5 |
| 05:47–06:13 | heating, 513 `RD_REQ_HK_C` | 60–100 | 26.9–33.4   | 24.3–35.4 | 25.5–29.0 | 26.0–30.6 |

- 1000, B32, read 0.1 to 0.6 °C all night, below `AE025` throughout.
- At rest B124 and B125 never fell below 21.4 °C, B124's lowest, at 02:27.
  B125's 18.7 °C came at 02:29, in the run's first minute, as the water
  standing in the lines came through.
- In the minute each request began, 1074 went to 100 and 1072 to 32 l/min,
  a minute before the compressor started. Wherever 1074 read `ffff`, 1072
  and B2 read 0.0; wherever it read a value, both read a flow. B2 and 1072
  agreed to within 1 l/min in every round but 05:50, as the pump slowed
  after the defrost, where they were read seconds apart.
- In the defrost all three circuits' pumps stopped and M73 ran on at 100.
- 1104 `Status Ladepumpe (M73)` read `ffff` in every read, as before
  ([registers.md](../registers.md#the-charge-pump-1074-not-1104)).
- 4789's M73 `Ladepumpe Wärmesenke EIN/AUS` read 100 in all 541 reads.
- B34 falls fast once the pump stops, from 28.1 °C at 03:10 to 8.6 °C at
  03:30, at 0.3 °C outdoors. B33 and B125 fall slowly: from 21:10 to 02:27
  B33 from 20.4 to 13.9 °C, B125 from 25.5 to 21.7 °C.
- Circuit D's pump M34 ran from 03:59 to 05:58 but for the defrost, its
  Normal window by the controller's clock; D's flow 1356 rose from 20.5 to
  28.6 °C. It started no request: both requests were C's.
- 1008, B38, rose from 19.7 to 22.5 °C between 21:37 and 22:00 with the
  heat pump at rest, from two minutes after C's pump started.

## What it shows

- **The frost protection of the outdoor unit does not key on B33 or B34
  against `AE026`.** 812199 §5.7 starts the charge pump below the frost
  protection outdoor temperature while "die Vorlauftemperatur der
  Wärmepumpe" is below "die einstellbare Minimaltemperatur". For five
  hours B32 was below `AE025` and B33 and B34 were below `AE026`, and the
  pump stood.
- **4789's M73 is the pump's enable, not its state.** It read 100 with
  the pump stopped and with 33 l/min. Whether M73 runs is 1074's
  signal, `ffff` for stopped, and the flow at 1072 or B2. The reading of
  2026-11-24 at 21:07, M73 at 100 with 1074 "not driven" and no flow, was
  the same state, not a disagreement.
- **Both runs were heating requests.** Their reason was C's, 513; no read
  had 64, `RD_REQ_FROST_PROT`.

## Open

- **Whether the frost protection keys on the heat sink.** 812199 §1.8
  requires a heating-side minimum of 20 °C for the defrost, which is what
  the web interface says `AE026` secures. B124 and B125 are the heating
  side's, and stayed above 21.4 °C, because C's requests heated them
  before they got there. A night where they fall below 20 °C, below
  `AE025`, would show it: from 25.5 °C at about 0.7 K an hour, it takes
  eight hours without a request.
- **What the intermediate circuit holds.** 812199 §5.8 fills the outdoor
  lines with brine behind an intermediate heat exchanger, which would make
  B33 and B34 at 8 °C no frost risk; `CF085` names a separation heat
  exchanger kit, but what fills its circuit was not read.
- **Why B38 rose 2.3 K at rest** once C's pump ran: the pump drawing on
  the buffer past its sensor is the likely reading, not checked.

## Reproducing

    idm-web HOST --status            # Kunde, below 3 °C at B32
    cabal run idm-dump -- HOST --watch 60 1000 1060 1008 1072 1074 1090 1091 1100 1104 1356 1501 > watch.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --watch 60 --reason --fachmann 4768 4789 > webwatch.jsonl

overnight, both stopped with SIGTERM, then the walk at Fachmann level:

    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
    IDM_PIN=... tools/webprobe.py HOST > webapi.json
    IDM_PIN=... cabal run idm-web -- HOST --leave-fachmann
