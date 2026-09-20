# Checking the table against the controller's web backend

2026-09-20, later the same evening. The verification earlier that day read the
web interface the way a person does, off the rendered page, and wrote what it
said into a TSV by hand. The pages turn out to carry no values at all: the web
interface is a single-page application, and every number it prints arrives over
a websocket. Asking that websocket directly is the same witness, read without
the transcription step — and it says more than the page does, because a setting
arrives labeled with the manufacturer's own parameter identifier, the `FW030`
and `BV002` of the parameter list.

That identifier is what makes this the stronger of the two web sources. The
hand-read TSV joins to the register table on the sensor designator inside a
register's name, which works for `B32` and not for a setting. The backend hands
over `param` next to the live value, so a setting joins on the column the
register table already has, and the join is stated in one place: the table.

## The instrument

The websocket is `ws://HOST:61220`; the local PIN travels in the URL as
`auth_code`. Messages are JSON, `{controller, command, data}`. The protocol has
four commands, and two of them write: `save` and `execute`. `tools/webprobe.py`
sends only `overview` and `detail`, refuses anything else before it opens the
socket, and never touches the user level — everything below was read at the
level the controller was already standing at, `userlevel` 0 in this capture.
Nothing was set, on the controller or over Modbus, at any point.

The script walks the settings tree as well as the pages: `overview` on a menu
yields its children, `detail` on a leaf yields the value, its unit, its limits
and its `param`. What the tree contains is therefore what the controller was
willing to show, which matters below.

The capture is verbatim except for the code that opens the controller and the
strings that name the machine, which are replaced by `<redacted>` so a reader
can tell a removal from an absence. The settings tree hands out the local code
twice — once as `SSYSLPIN`, once as the `displayValue` of the menu entry above
it — and the pages carry the MAC address and the myIDM identifier. None of them
is evidence for anything here.

## What was compared

| | |
|---|---|
| Web backend | `data/navigator-2.0-webapi-2026-09-20-2138.json`, 21:38–21:41 |
| Registers | `data/navigator-2.0-scan-2026-09-20-2141.json`, 21:41–21:43 |
| Offset | under 5 minutes |

The sweep partitions the 663 addresses into the same 232 that answer and 431
that refuse as the four sweeps before it did, address for address. Nothing
about the machine's configuration moved.

## What agrees, on the parameter identifier

Nineteen settings carry a `param` that the register table also carries. All
nineteen agree, and the three floats agree bit for bit — the backend hands over
the same double the register decodes to, `0.4000000059604645`, not a rounded
`0.4`.

| Parameter | Address | Register | Web | Register | Raw |
|---|---|---|---|---|---|
| BV002 | 1120 | 2. Wärmeerzeuger - Bivalenzpunkt 1 | −5 | −5 | `fffb` |
| BV003 | 1121 | 2. Wärmeerzeuger - Bivalenzpunkt 2 | −20 | −20 | `ffec` |
| FW027 | 1033 | Warmwasserladung Einschalttemperatur | 36 | 36 | `0024` |
| FW028 | 1034 | Warmwasserladung Ausschalttemperatur | 44 | 44 | `002c` |
| HKA01 | 1393 | Betriebsart Heizkreis A | 1 | 1 | `0001` |
| HKC01 | 1395 | Betriebsart Heizkreis C | 1 | 1 | `0001` |
| HKD01 | 1396 | Betriebsart Heizkreis D | 0 | 0 | `0000` |
| HKA04 | 1401 | Raumsolltemperatur Heizen Normal HK A | 22 | 22.0 | `000041b0` |
| HKC04 | 1405 | Raumsolltemperatur Heizen Normal HK C | 22 | 22.0 | `000041b0` |
| HKD04 | 1407 | Raumsolltemperatur Heizen Normal HK D | 22 | 22.0 | `000041b0` |
| HKA05 | 1415 | Raumsolltemperatur Heizen Eco HK A | 18 | 18.0 | `00004190` |
| HKC05 | 1419 | Raumsolltemperatur Heizen Eco HK C | 18 | 18.0 | `00004190` |
| HKD05 | 1421 | Raumsolltemperatur Heizen Eco HK D | 18 | 18.0 | `00004190` |
| HKA08 | 1442 | Heizgrenze HK A | 15 | 15 | `000f` |
| HKC08 | 1444 | Heizgrenze HK C | 15 | 15 | `000f` |
| HKD08 | 1445 | Heizgrenze HK D | 15 | 15 | `000f` |
| HKA10 | 1429 | Heizkurve HK A | 0.4000000059604645 | 0.4000000059604645 | `cccd3ecc` |
| HKC10 | 1433 | Heizkurve HK C | 0.4000000059604645 | 0.4000000059604645 | `cccd3ecc` |
| HKD10 | 1435 | Heizkurve HK D | 0.4000000059604645 | 0.4000000059604645 | `cccd3ecc` |

**The two Bivalenzpunkte settle the sign of a `WORD`.** 1120 answers `fffb` and
1121 answers `ffec`, and the controller prints −5 °C and −20 °C beside `BV002`
and `BV003`. Read as unsigned those registers are 65531 and 65516, which is
what the capture records, because a capture records the uninterpreted number.
The parameter list documents a minimum of −90 °C for both, and letting that
minimum decide the sign is what produces the two numbers the controller itself
prints. This is the first evidence for that rule from outside the machine's own
arithmetic.

## What agrees, on the pages

| Address | Register | Register | Where the backend says it | Web |
|---|---|---|---|---|
| 1002 | Gemittelte Außentemperatur | 20.26 | `homeDetail`, `avgOutdoor` | 20.3 |
| 1005 | Betriebsart System | 4 | `homeDetail`, `systemMode.value` | 4 |
| 1098 | EVU - Sperrkontakt | 1 | Digitaleingänge, "EW/EVU Sperrkontakt" | 1 |
| 1099 | Summenstörung Wärmepumpe | 0 | `notification`, `current` | empty |
| 1378 | Heizkreis A Sollvorlauftemperatur | 0.0 | Heizkreis A, `temperatures.set` | 0.0 |
| 1382 | Heizkreis C Sollvorlauftemperatur | 0.0 | Heizkreis C, `temperatures.set` | 0.0 |
| 1384 | Heizkreis D Sollvorlauftemperatur | 0.0 | Heizkreis D, `temperatures.set` | 0.0 |

**1002 does have a page**, which the earlier note doubted: the home page prints
it as the averaged outdoor temperature, beside the interval it averages over,
16.0 h. The weather page prints the same pair as `20°C/16.0h`.

**A target flow temperature of zero is a value, not a sentinel.** All three
circuits are idle, all three answer 0.0 rather than −1.0, and the controller
prints 0.0 for all three. A reader of this table must not treat a target flow
temperature the way it treats an unfitted sensor.

1005 is confirmed at 4, "Nur Warmwasser" — which matches the machine: the
heating period has not started.

## What the web interface cannot settle

Not every register has a page, and saying which is part of the result.

| Registers | Why not |
|---|---|
| 1032 Warmwasser-Solltemperatur (`FW030`) | the settings tree offers `FW027` and `FW028`, the charge on and off temperatures, and no `FW030` at all. The register still reads its documented default, 46 |
| 1457–1497, cooling | cooling is not configured on this machine — `coolingConfigured` is false, the operating mode offers no cooling, and each circuit's `temperatures` carries a `heating` block and nothing else. The registers answer, with what are evidently defaults; no page will ever confirm them here |
| 1006 Smart Grid Status | the Smart Grid menu exists and holds settings (`EV002`, `PV017`), but prints no status. The register answers 255, the `UCHAR` sentinel, which is consistent with a Smart Grid that is not in use, and is not a check |
| 1091–1093, the three demands | not shown anywhere. The Heizkreis page has a `demand` of its own, which is 1 for circuit A while 1091 is 0, so the two are not the same thing |
| 1122, 1123 (`BV102`, `BV103`) | the tree has one auxiliary heat generator, not two. Both registers read the same −5 and −20 as `BV002` and `BV003`, which is what a default looks like |
| 1124 Bivalenz Betriebszustand | not shown |
| 1048 Aktueller Strompreis | not shown; the register answers −1.0 and no tariff service is subscribed |

**The manual's enumeration for 1005 is incomplete.** The backend offers the
operating modes −1, 0, 1, 2, 3, 5 and 4; the parameter list documents 0, 1, 2, 4
and 5, and page 439 of 812170 lists no 3. `data/navigator-2.0-enums.tsv` is
faithful to the manual here — the gap is the manual's. What 3 and −1 mean is
open.

## Where they disagree: the Wärmemenge counters

The controller's own Wärmemenge totals do not match registers 1748–1754, and
the gap is not a rounding.

| | Web total | Register | Address |
|---|---|---|---|
| Warmwasser | 316.81 kWh | 265.396 | 1754 |
| Heizen | 1.28 kWh | 1.080 | 1748 |

The registers are internally consistent to everything a 32-bit float carries:
1.080 + 265.396 is 1750's 266.476. The web totals agree with their own monthly
series, 110.94 + 76.98 + 128.90 = 316.82. Each side adds up; they are adding up
different things.

**It is not a counter that was reset.** A reset would leave a fixed offset, and
the gap grows with use. Between the sweep of 2026-09-19 and the 19:54 sweep of
2026-09-20, 1754 rose by 8.494 kWh, from 256.902 to 265.396. The controller's
figure for 2026-09-20 is 10.25 kWh, and all of it falls inside that window:
1754 then held at 265.396 through the 20:07, 20:37 and 21:41 sweeps, so no hot
water was made after 19:54 for the page to be counting and the register not.
The window reaches back into 2026-09-19 as well, which can only add to the
register's rise, never to the page's 10.25. The ratio, 1.21, is the ratio
between the totals, 1.19, and between the two heating figures, 1.19.

**No register carries the controller's number.** Searching all 663 addresses
for 316.81, 1.28, and for the runtimes and electrical energies the same pages
print — 39.65 h and 82.71 kWh for hot water, 0.17 h and 0.20 kWh for heating —
finds nothing within 0.4 percent of any of them. The Wärmemenge page and the
Wärmemenge registers are two separate accountings, and the register table's
names for 1748–1762 should not be read as naming what that page prints.

Settling it needs two sweeps spanning a single charge, compared against the
controller's figure for the same charge: if the ratio holds at 1.19 the
registers are a scaled quantity, and it is worth asking which.

## Reproducing

    tools/webprobe.py 192.168.0.200 PIN > data/navigator-2.0-webapi-DATE.json
    cabal run idm-dump -- 192.168.0.200 --json > data/navigator-2.0-scan-DATE.json

Run them in that order and within a few minutes of each other. The script needs
nothing but a Python interpreter, holds its own websocket client, and takes
about three minutes: it paces itself at one request every two seconds, where
the manufacturer's own client polls a settings page twice a second.
