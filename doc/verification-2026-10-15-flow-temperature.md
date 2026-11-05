# Which circuit's flow temperature limit each register holds

2026-10-15. The controller's register page lists the minimum and maximum flow
temperature of circuits A, C and D at 1520 to 1540 and names no parameter
identifier; the settings tree names `HSA04` and `HSA05` and no address
([verification-2026-10-14-gltmon.md](verification-2026-10-14-gltmon.md)).
Every circuit's maximum stood at 45 and A and C's minimum at 22, so neither a
name nor a value could join them. Moving three settings to values no other
circuit held, and watching both sides, joins all six.

## What was recorded

|             |                                                                                                                             |
| ----------- | --------------------------------------------------------------------------------------------------------------------------- |
| Registers   | `captures/navigator-2.0-watch-20.24-1574-2026-10-15-0836.jsonl`, 1520, 1524, 1526, 1534, 1538, 1540                         |
| Web backend | `captures/navigator-2.0-webwatch-20.24-1574-2026-10-15-0836.jsonl`, the settings 6966, 6980, 7862, 7876, 8310, 8324         |
| Interval    | 10 s, both, 08:36–08:47                                                                                                     |
| Scans       | `captures/navigator-2.0-scan-20.24-1574-2026-10-15-0837.json` before, `-0841.json` with all three moved, `-0847.json` after |
| Widths      | `captures/navigator-2.0-widths-20.24-1574-2026-10-15-0836.json` and `-0841.json`, 1520 to 1546, circuits A to G             |
| User level  | Fachmann, entered for the run and left afterwards                                                                           |

The settings were changed by hand, at the controller; the library sent only
reads and the two level changes.

## The moves

Each line is the first read that showed a new value. Register and setting
moved within one round of each other each time.

| Register | Setting | Register moved    | Setting moved     |
| -------- | ------- | ----------------- | ----------------- |
| 1534     | `HSA04` | 45 → 44, 08:39:55 | 45 → 44, 08:40:05 |
| 1538     | `HSC04` | 45 → 43, 08:40:35 | 45 → 43, 08:40:36 |
| 1520     | `HSA05` | 22 → 23, 08:41:15 | 22 → 23, 08:41:15 |
| 1534     | `HSA04` | 44 → 40, 08:45:55 | 44 → 40, 08:45:55 |
| 1520     | `HSA05` | 23 → 22, 08:46:05 | 23 → 22, 08:46:05 |
| 1538     | `HSC04` | 43 → 40, 08:46:15 | 43 → 40, 08:46:16 |
| 1540     | `HSD04` | 45 → 40, 08:46:25 | 45 → 40, 08:46:27 |
| 1526     | `HSD05` | 25 → 22, 08:46:35 | 25 → 22, 08:46:27 |

1524 and `HSC05` stayed at 22 throughout; they are joined because the page
lists three minima and the tree holds three, and the other two are joined by
a move. Every other register that changed between the scans of 08:37 and
08:41, across all 682 addresses, is a sensor, a power or a counter, and no
address changed status. The circuits the page does not list, B and E to G at
1522, 1528 to 1532, 1536 and 1542 to 1546, kept 25 and 45 in the widths
captures before and after: they are not these circuits' settings either.

The maximum now stands at 40 for A, C and D, and the minimum at 22, which
leaves the six as tied as before.

| Address | Parameter                                    |
| ------- | -------------------------------------------- |
| 1520    | `HSA05`, Minimale Vorlauftemperatur Heizen A |
| 1524    | `HSC05`, by elimination                      |
| 1526    | `HSD05`                                      |
| 1534    | `HSA04`, Maximale Vorlauftemperatur Heizen A |
| 1538    | `HSC04`                                      |
| 1540    | `HSD04`                                      |

## Where the join is stated

`data/navigator-2.0-gltmon-parameters.tsv`, by hand, since only a write
settled it and no capture can derive it. `tools/transcribe.py` reads it into
the register table's `parameter` column, refuses an address that is not a row
of the page and an identifier another row carries already, and, given a
webapi capture, refuses a join where the tree's value for the identifier
differs from the page's value for the address. That check is weak where
circuits share a value, which is why it is a check and not the join.
