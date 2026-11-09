# The heating floor is 24 rps and draws 0.6 to 0.7 kW

2026-11-05. With heating capped at 50 % and the heating curve of circuit C
lowered, the compressor came out of its start program and slowed, without
any further change, to 24.0 rps. It held exactly that speed for seven
minutes while circuit C's flow stayed 1.7 K below its target: a limit, not
a choice. There it drew 0.61 to 0.72 kW by 4122, 0.67 kW on average, and
gave 2.8 kW of heat, at 8.3 °C outdoors and 27.8 °C flow. 24.0 rps is 20 %,
`IV003`, on the scale the defrost of 2026-10-16 implied, 1.2 rps per
percent. The cap itself was never reached, so this run does not test it.

## What was set

At Fachmann level, through the web interface, before the run and back after
it (read by `idm-web --show`, before, `captures/navigator-10-show-20.24-1574-2026-11-05-1113.txt`;
during, `-1115.txt`; after, `-1233.txt`):

| Setting                                  | Before | During | After |
| ---------------------------------------- | ------ | ------ | ----- |
| `IV002` `N2_MOD_MAX_POWER_HEATING`       | 100    | 50     | 100   |
| `HKC10` `N2_HC_HEATING_SLOPE`, circuit C | 0.40   | 0.30   | 0.40  |

`IV003`, `N2_MOD_MIN_POWER_HEATING`, read 20, its least. Circuit A stayed
off. Circuit C was switched on at 11:15, and its room target raised from 18
to 20 °C at about 11:21, to use up the heat left in the store sooner; it went
back to 18 °C at about 12:33.

## What was recorded

Every 10 s from 11:13 to 12:33: over Modbus 1000, 1090, 1100, 4122, 4126,
1350, 1354, 1378 and 1382, 482 reads each and none failed
(`captures/navigator-10-watch-20.24-1574-2026-11-05-1113.jsonl`); over the web
interface 6245, `N2_MODULATION_OVERVIEW`, 482 requests
(`captures/navigator-10-webwatch-20.24-1574-2026-11-05-1113.jsonl`). Three of these
answered `NoAnswer`, all at 12:08, while the level was renewed
(`captures/navigator-10-level-20.24-1574-2026-11-05-1113.log`).

## The run

1090 went to `Heizbetrieb` at 12:11:25 and 1100 to `Ein` at 12:12:25; both
went back to 0 at 12:33:15.

| From     | To       | Speed, rps             | 4122, kW  |
| -------- | -------- | ---------------------- | --------- |
| 12:12:25 | 12:13:15 | 0 to 50.4, rising      | 0.29–0.91 |
| 12:13:15 | 12:16:25 | 50.4, fixed            | 1.10–1.24 |
| 12:16:25 | 12:22:45 | 49.9 to 24.0, falling  | 1.20–0.59 |
| 12:22:45 | 12:29:55 | 24.0, 44 reads         | 0.61–0.72 |
| 12:30:05 | 12:33:05 | 25.1 to 39.5, swinging | 0.63–1.01 |

The start program, three minutes at 50.4 rps, is the one of 2026-10-16. Its
descent was smooth, about 4 rps a minute, and stopped at 24.0 rps to the
page's decimal. What raised the speed again after 12:30 is not known; the
stop at 12:33:15 followed the room target going back to 18 °C.

## The floor

Over the 44 reads at 24.0 rps, 12:22:45 to 12:29:55:

| Register                                          | Least | Most  | Mean  |
| ------------------------------------------------- | ----- | ----- | ----- |
| 4122 `Aktuelle Leistungsaufnahme Wärmepumpe`, kW  | 0.61  | 0.72  | 0.67  |
| 4126 `thermische Leistung (Durchflusssensor)`, kW | 2.34  | 2.91  | 2.77  |
| 1000 `Außentemperatur (B32)`, °C                  | 8.26  | 8.40  | 8.34  |
| 1354 `Heizkreis C Vorlauftemperatur (B53)`, °C    | 27.72 | 27.80 | 27.75 |
| 1382 `Heizkreis C Sollvorlauftemperatur`, °C      | 29.33 | 29.55 | 29.44 |

Three things make this the floor rather than a speed the controller chose:

- **It held a round figure against demand.** The flow stayed 1.6 to 1.8 K
  below target for the whole seven minutes, and a controller with demand left
  over that is free to go lower would not settle on 24.0 exactly.
- **It is 20 % on the defrost's scale.** The defrost of 2026-10-16, set by
  `IV007` to 65 %, ran at 78.0 rps
  ([verification-2026-10-16-draw.md](verification-2026-10-16-draw.md)):
  1.2 rps per percent. `IV003`'s 20 % is then 24.0 rps, which is what the
  run held.
- **The descent ended there.** It fell at a steady rate and stopped without
  overshoot.

The heat and the draw make a coefficient of performance of about 4.1 at this
point, 2.77 over 0.67.

## What the run does not settle

- **The cap.** On the same scale, `IV002` at 50 % is 60 rps. The controller
  never asked for more than the start program's 50.4, so the cap did not
  bind and the run says nothing of how it acts.
- **The floor elsewhere.** The draw at a fixed speed rises with the lift from
  the source to the flow. This is one point, 8.3 °C outdoors and 27.8 °C in
  circuit C; colder air or a warmer flow will draw more at the same 24 rps.
  1350 and 1354 are the circuits' flows: the heat pump's own, B33 at 1050,
  reads -1.0 on this machine.
- **The machine's whole draw.** 4122 again followed 6245's `motor power`: at
  all 125 readings with the drive at `run`, the nearer 4122 read differs by at
  most 0.05 kW. It is the inverter's figure; the fan, the pumps and the
  controller are not in it.

## Reproducing

    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
    IDM_PIN=... cabal run idm-web -- HOST --show 6259 7757 6252
    IDM_PIN=... cabal run idm-web -- HOST --watch 10 6245 > webwatch.jsonl
    cabal run idm-dump -- HOST --watch 10 1000 1090 1100 4122 4126 1350 1354 1378 1382 > watch.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --leave-fachmann

with `IV002` at 50 and a heating curve low enough that the flow nears its
target, renewing the level every hour with a pause of half a minute between
leaving and entering.
