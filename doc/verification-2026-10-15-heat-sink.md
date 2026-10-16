# The heat sink registers against the display

2026-10-15. The controller's register page names 1068, 1070 and 1072 after
the heat sink's return, flow and flow rate
([verification-2026-10-14-gltmon.md](verification-2026-10-14-gltmon.md)), and
the web backend's sensor page prints B124, B125 and B2 under the same names.
Read at the same minute while the machine heated, each register tracks its
designator, and the controller's thermal power at 4126 turns out to be
computed from these three registers.

## What was recorded

|             |                                                                                         |
| ----------- | --------------------------------------------------------------------------------------- |
| Registers   | `captures/navigator-2.0-watch-2026-10-15-0835.jsonl`, 08:35–08:47                       |
| Web backend | `captures/navigator-2.0-webwatch-2026-10-15-0835.jsonl`, 08:35–08:47, 4768 `N2_SENSORS` |
| Interval    | 10 s, both                                                                              |
| User level  | Fachmann, entered for the run and left afterwards                                       |
| Scans       | `captures/navigator-2.0-scan-2026-10-15-0837.json`, `-0841.json`, `-0847.json`          |

The registers are 1066 to 1074, 1104, 1100, 1090, 1091, 1350, 4122 and 4126.
The machine was heating throughout: 1090 read 1, `Heizbetrieb`, 1091 and 1100
read 1. 73 rounds on each side, no read failed, and every web reading is set
against the register read nearest to it, at most 2.0 s away.

## What agrees

| Designator                         | Address | Largest difference | Mean difference | Range over the run |
| ---------------------------------- | ------- | ------------------ | --------------- | ------------------ |
| B124 Rücklauftemperatur Wärmesenke | 1068    | 0.05 K             | 0.024 K         | 24.2–26.8 °C       |
| B125 Vorlauftemperatur Wärmesenke  | 1070    | 0.05 K             | 0.026 K         | 28.6–31.3 °C       |
| B2 Durchfluss Wärmesenke           | 1072    | 0.72 l/min         | 0.18 l/min      | 32.2–33.3 l/min    |
| B45 Ladefühler                     | 1066    | 0.05 K             | 0.026 K         | 28.8–31.3 °C       |
| B51 Vorlauftemperatur HK A         | 1350    | 0.06 K             | 0.025 K         |                    |

The display prints one decimal, which accounts for the temperatures. The flow
rate moves by tenths from one second to the next, which accounts for the
rest. The return and the flow cannot be swapped: they stood 4.4 to 4.6 K
apart all run, and B124 never came closer than 4.3 K to 1070. B45 and B125
ran close together, and swapping 1066 and 1070 is what the values rule out
least: swapped, they differ from the display by up to 0.16 K, mean 0.07, more
than its rounding allows. 1066 was joined to B45 on 2026-09-20, when nothing
near it read alike.

So the parameter list's silence on the heat sink, recorded in
[verification-2026-09-20.md](verification-2026-09-20.md), is the list's
alone: the machine serves the heat sink's flow, return and flow rate over
Modbus, at 1070, 1068 and 1072.

## 4126 is computed from them

4126, `thermische Leistung (Durchflusssensor)`, divided by the flow rate at
1072 and the spread from 1068 to 1070, gives 4.12 to 4.26 kJ/(kg·K) over the 73
rounds, median 4.186: the specific heat of water. The controller's thermal
power is the product of these three registers, not a separate measurement.

4122 read 2.70 to 3.13 kW. A coefficient of performance, 4126 over 4122,
read 3.17 to 3.77 in this run, median 3.54. It rests on 1068, 1070 and 1072, which a reader of the registers
can now check, rather than on a figure whose source was unknown.

## The charge pump's two registers

1104, `Status Ladepumpe (M73)`, read 65535, which the table decodes as not
driven, throughout, while 32 l/min flowed. 1074, `Ladepumpe Wärmesenke
Steuersignal`, read 93 to 97 in the watch and in the three scans. In the scan
of 2026-10-14 12:11, with the machine at rest and 1072 at 0, both read `ffff`.

1104 does not report this pump's signal while the machine heats; 1074 does.
Whether 1074's `ffff` at rest is the -1 of the pump signals at 1104 to 1109,
"not driven", needs the display's `Analogausgänge` page beside it. The table
still reads it as 65535. It is, and 1104 does not follow the pump:
[verification-2026-10-16-charge-pump.md](verification-2026-10-16-charge-pump.md).

## Reproducing

    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
    IDM_PIN=... cabal run idm-web -- HOST --watch 10 4768 > webwatch.jsonl
    cabal run idm-dump -- HOST --watch 10 1066 1068 1070 1072 > watch.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --leave-fachmann

while the machine runs; at rest, the flow rate reads 0 on both sides and
cannot tell anything apart.
