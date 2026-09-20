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

The controller's own JavaScript names the whole protocol, which is how the
above is known rather than guessed: every read is `overview`, `detail` or
`traverse`, and every write is `save` or `execute`, so the script's whitelist
covers the write side exactly. Two reads are refused as well —
`relaytest`/`overview`, which opens the relay test, and
`authentication`/`overview`, which asks with `userlevel` 4.

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
| Graph | `data/navigator-2.0-webapi-2026-09-20-2218.json`, 22:18–22:21 |

The graph capture has no sweep beside it and needs none: it is history rather
than live values, and the counters had not moved since 19:54.

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
what is there is a ratio: 1.19 between the lifetime totals, 1.19 between the two
heating figures, and 1.21 across the single charge the graph isolates below.
1754 held at 265.396 through the 20:07, 20:37 and 21:41 sweeps, so no hot water
was made after 19:54 for the page to be counting and the register not.

**No register carries the controller's number.** Searching all 663 addresses
for 316.81, 1.28, and for the runtimes and electrical energies the same pages
print — 39.65 h and 82.71 kWh for hot water, 0.17 h and 0.20 kWh for heating —
finds nothing within 0.4 percent of any of them. The Wärmemenge page and the
Wärmemenge registers are two separate accountings, and the register table's
names for 1748–1762 should not be read as naming what that page prints.

## The graph, and what it settles

The same capture answers this, in a part of it nobody had read. Beside the
statistics the backend serves a **graph**: a sampled history of the sensors the
web interface plots, and of whether the machine was heating, making hot water
or defrosting. It is the only source here that carries time. A register says
what is true now and a statistic says what has accumulated; the graph is what
says *when the machine ran*, which is what a rise in a counter has to be
attributed to.

Its timestamps are seconds since 2000-01-01, and they are local time: read as
if they were UTC they give the wall clock. The `timestamp` the status page
carries is the same trick in milliseconds since 1970, and it agrees with the
minute the capture was taken. The window that arrives unasked is 2026-09-19
15:39 to 2026-09-20 21:39, the 30 hours the interface's own second tab asks
for.

A second capture, `data/navigator-2.0-webapi-2026-09-20-2218.json` at
22:18–22:21, asks for the graph on purpose: `graph`/`overview`, then
`graph`/`traverse`, then `graph`/`detail` for each graph the controller offers
over each span the interface plots. `fromSecs` reaches back from now rather than
naming a date, and eight days is the furthest the interface looks; the
controller answered that request from 09-13 22:43 onwards, so seven days is what
it had. Two graphs exist, `System` with the four sensors and the four state
channels, and `WW` with the two hot water sensors.

In the 30 hours of the first capture the machine ran **exactly once**:

| Time | What the graph says |
|---|---|
| 09-19 15:39 – 09-20 09:05 | TW-Erwärmer decays 39.6 → 34.0 °C, no stage, no hot water |
| 09-20 09:05 – 10:32 | one stage running, `N2_HOTWATER` set |
| 09-20 10:32 – 21:39 | 57.9 °C decaying to 42.9, no stage |

87 minutes of it, against the 1.48 h — 89 minutes — the controller booked as
runtime for that day, so those two of its accountings agree. The lower sensor
stood at 34.0 °C when it started, below the 36 °C of `FW027`.

**The stamps on the state channels run an hour early.** `FW025` opens the hot
water window at 10:00 and the machine charges there, but the stage and
`N2_HOTWATER` channels put the run at 09:05. The tank's own sensors, in the same
response, have it warming until 11:40, which is where the program puts it, and
the live tail of both agrees with the wall clock to the minute. So the offset is
in the stored history rather than in the epoch, and summer time is the obvious
suspect. It is worth knowing before anyone dates something by this graph, and
nothing below rests on it: the duration of a run, the number of runs and the days
they fall on are the same either way.

**So the factor survives a single charge.** The sweep of 09-19 was taken at
15:05, half an hour before the graph begins, and the graph's first samples show
a tank already cooling, so nothing ran in the gap either.

| | |
|---|---|
| 1754 at 09-19 15:05 | 256.902 kWh |
| 1754 at 09-20 19:54 | 265.396 kWh |
| Rise, over one charge | **8.494 kWh** |
| The controller's figure for that day | **10.25 kWh** |
| Ratio | **1.207** |

That rules out the cheapest explanation: the registers are not lagging behind an
unobserved window. Two accountings of one 87-minute charge differ by a fifth.

**The controller books a day the machine did not run.** On 2026-09-19 it credits
10.25 kWh of hot water heat against 0 runtime and 0 electrical energy, and it is
the only such day in the 31 the daily series holds — every other day's
zero-or-nonzero pattern matches across all three series. The seven-day graph
says the same thing from the sensors instead of from the statistics: one stage
ran on 09-15, 09-17, 09-18 and 09-20, each time in the morning window for about
90 minutes with `N2_HOTWATER` set, and on 09-19 the TW-Erwärmer falls from 50.0 °C to
34.9 °C without a single rise. Nothing heated that water, and 10.25 kWh is
booked against it.

It is not confined to the daily list. September's daily figures sum to 128.89
against a printed monthly 128.90, and the three monthly figures sum to the
316.81 kWh total, so the phantom day is inside the number the page prints. That
is why the lifetime ratio is the weaker of the two: the total on the web side
contains at least one day that never happened, and the per-charge comparison
above does not.

**What the tank holds points the same way.** The charge took the lower sensor
from 34.0 to 57.9 °C and the upper from 47.1 to 59.3 °C, so a 300 L tank took
up between 6.3 kWh — if the mean before the charge was the average of the two
sensors — and 8.4 kWh, if the bulk of it stood at the lower sensor's 34 °C.
Hot water drawn during the 87 minutes adds to what was delivered and is not
measured here, so this is a floor and not a figure. The registers' 8.494 kWh
sits at the top of that band; the page's 10.25 kWh sits above it. Suggestive,
resting on a nominal volume rather than a measured one, and worth stating
because it is the only check here that does not come from the controller.

None of this says what 1748–1754 accumulate. It says the disagreement is real,
that it is per charge and not per lifetime, and that the page is the side with a
known defect. A caller who wants the heat the tank received has no better source
than the registers; a caller who wants the number the controller prints cannot
have it from Modbus at all.

**The channel that would name it exists and cannot be read.**
`graph`/`traverse` lists every channel the controller could plot, whether or not
a graph uses it, and among the groups — the site sensors, the heat pump states,
heating circuits A, C and D, the compressor, the circulation pump, the bivalent
stage — stands `N2_HEATQUANTITIES`, holding two channels named `T20x_QACT` with
the unit `N2_KW`. That is an instantaneous heat output in kW, which is what
registers 1790 and 1792 are called. Plotting it would require a graph that
contains it, and creating one is `graph`/`save`: a write, and out of this
script's reach. Modbus has the same quantity live, which is the way to take it.

So what would name the quantity: sampling 1754 and 1790 through a charge, and
integrating the second against the rise in the first. If they agree, the
registers are a closed accounting of a measured power and the page is computing
something else; if 1790 integrates to the page's figure instead, the counters
are the odd ones. That needs a run during a charge window, which `FW025` opens
at 10:00 on this machine, and has not been done.

## Reproducing

    tools/webprobe.py 192.168.0.200 PIN > data/navigator-2.0-webapi-DATE.json
    cabal run idm-dump -- 192.168.0.200 --json > data/navigator-2.0-scan-DATE.json

Run them in that order and within a few minutes of each other. The script needs
nothing but a Python interpreter, holds its own websocket client, and takes
three or four minutes: it paces itself at one request every two seconds, where
the manufacturer's own client polls a settings page twice a second.

The graph is worth capturing on its own whenever a counter is in question,
because it is the only thing that says what the machine was doing while the
counter moved, and it reaches back about a week — after that the answer is gone.
