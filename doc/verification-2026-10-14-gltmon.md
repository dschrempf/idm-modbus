# The controller's own list of its registers

2026-10-14. At Fachmann level, the web backend's settings tree holds an info
page, 12763 `N2_GLTMON`, that the walks since 2026-09-24 have captured without
anyone reading it: a table of the addresses the controller serves over Modbus,
with a name, an access right and the current value for each. It lists 115
addresses. 91 of them are in the parameter list. The other 24 are not, and
among them is the maximum flow temperature that
[verification-2026-09-20.md](verification-2026-09-20.md) concluded had no
address.

## What was recorded

| | |
|---|---|
| The page | `captures/navigator-2.0-webapi-2026-10-01-1158.json`, the `detail` of setting 12763, Fachmann |
| Widths | `captures/navigator-2.0-widths-2026-10-14-1208.json`, the 24 addresses |
| | `captures/navigator-2.0-widths-2026-10-14-1214.json`, circuits B and E to G |
| Values | `captures/navigator-2.0-scan-2026-10-14-1211.json`, the table with the page's rows in it |

Everything was read; nothing was set, on the controller or over Modbus. The
user level was not touched, which is why no web capture is as recent as the
reads: the page shows only at Fachmann level.

## What the page states, and what it does not

Each row has five cells, headed `ID`, `Name`, `Access`, `Value` and
`GLT Value`. The name carries the unit in parentheses at its end, `Maximale
Vorlauftemperatur Heizen A (°C)`. The access right is `RO` or `RW`. The fifth
cell is empty but for five rows, where it holds `-1`; nothing here depends on
it.

The page states no datatype, and the way it prints a value does not reveal
one: 1520, two registers wide, prints `22`, and 1074, one register wide, prints
`-1.0`. It states no persistence, range, default or parameter identifier
either. It lists the circuits the house has, A, C and D, and not B, the
machine's internal one, or E to G.

## Measuring the width

`idm-dump HOST --widths` reads each address as one register and as two, and
the address after it as one. A value two registers wide answers to the second
read, while the address inside it refuses the third. A single register refuses
the second read, unless another register follows it; 1449, followed by 1450,
answers both. Where the three reads cannot tell, `tools/transcribe.py` leaves
the row out. None of the 24 was undecided:

- one register: 504 `Trennwärmetauscher` and 1074 `Ladepumpe Wärmesenke
  Steuersignal`
- two registers, every other address the third read refusing with exception 2

The table gives the two-register rows the datatype `FLOAT`. The settings decode,
low word first, to exactly what the page printed for them: `000041b0` is 22.0,
`000041c8` 25.0 and `00004234` 45.0. 1746, `Elektrische Leistungsaufnahme
(gesamt)`, decodes to 128.94 kWh, where the page printed 108.2 thirteen days
before; as a `DWORD` the same bytes would be some billion kWh. The manual's own
energy counters, 1748 to 1762, are `FLOAT` as well.

The one-register rows get the datatype `one-register`, which says only that:
nobody states whether it is signed, or which value means absence. 504 reads 2,
as the page printed. 1074 reads `ffff` where the page printed `-1.0`, which
looks like the signed control signal of the pumps at 1104 to 1109; looking like
it is not a source, so the table reads it as 65535.

## What was left out

- 68, 70, 72 and 80 have no name on the page. They are `FLOAT`-wide and read
  -1.0.
- 4116 `Firmware Version IDM` prints `T_NAV10_20.24-1574-g183d9b17a` on the
  page, but over Modbus it is a float of about 10⁻¹²: whatever the register
  holds, it is not the version the page prints.
- The circuits the page does not list. Over Modbus they answer all the same:
  the minimum flow temperature of B and E to G is at 1522, 1528, 1530 and 1532,
  their maximum at 1536, 1542, 1544 and 1546, every one two registers wide,
  reading 25.0 and 45.0. They follow the pattern of A, C and D at a step of
  two, but nothing names them, so the table does not either.

That leaves 19 rows, which the table carries with the source `gltmon`. All 19
answered in the scan of 12:11, and none of the manual's rows changed status
against `captures/navigator-2.0-scan-2026-09-29-1324.json`.

## The maximum flow temperature

| Circuit | Address | Read at 12:11 | Settings tree, 2026-10-01 |
|---|---|---|---|
| A | 1534 | `00004234`, 45.0 | `N2_HC_MAX_FLOW_TEMP`, `HSA04`, 45 |
| C | 1538 | `00004234`, 45.0 | `N2_HC_MAX_FLOW_TEMP`, `HSC04`, 45 |
| D | 1540 | `00004234`, 45.0 | `N2_HC_MAX_FLOW_TEMP`, `HSD04`, 45 |

1449, `Sollvorlauftemperatur HK A (Konstant-HK)`, is the parameter `HKA03`, a
different identifier from `HSA04`, and the page does not list it. The
conclusion of 2026-09-20 holds, 1449 is not the maximum flow temperature, and
it no longer rests on the change made at the display having taken effect. Its
second half does not: the maximum flow temperature has an address, outside the
parameter list. The minimum is beside it, at 1520, 1524 and 1526.

That 1534 is `HSA04` rests on the name and on both reading 45. The page carries
no identifier and the settings tree no address, and every circuit sits at the
same 45, so the values cannot tell the circuits apart either.

## The heat sink

1068, 1070 and 1072, `Rücklauftemperatur Wärmesenke`, `Vorlauftemperatur
Wärmesenke` and `Durchfluss Wärmesenke`, are by their names the heat sink
return, flow and flow rate that
[verification-2026-09-20.md](verification-2026-09-20.md) lists among what the
web interface shows and Modbus does not: B124, B125 and B2. No capture yet
holds a web reading and a register reading of them at the same minute, so the
join to the designators is the names' claim alone.
