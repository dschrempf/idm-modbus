# Checking the table against the controller's own display

2026-09-20. The Navigator's web interface prints the same sensors and settings
the parameter list describes, under the manufacturer's own labels and sensor
designators. Reading a page and the register block within a few minutes of each
other turns a plausible number into a checked one: a name in the table is right
if the value under it tracks the value the controller prints beside the same
designator.

The previous verification established what the machine answers and what the
sentinels mean, using the machine alone. This one asks a different question —
whether the table names the right thing — and it needs a second witness.

## What was compared

Two rounds, each a web page and a register sweep taken close together.

| Round | Web pages | Capture | Offset |
|---|---|---|---|
| 1 | Fühlereingänge, Analogausgänge, Digitaleingänge, Digitalausgänge, 19:47–19:49 | `data/navigator-2.0-scan-2026-09-20-1954.json` | 5–7 min |
| 2 | Expansionsventil, Modulation, Warmwasser, Heizkreis A/C/D, Wärmemenge, Fühlereingänge, System Informationen, 20:01–20:06 | `data/navigator-2.0-scan-2026-09-20-2007.json` | 1–8 min |
| 3 | one setting changed on purpose, see below, around 20:30 | `data/navigator-2.0-scan-2026-09-20-2037.json` | — |

The web side is transcribed into `data/navigator-2.0-web-2026-09-20.tsv`: the
page, the sensor designator, the label, the value, the unit and the minute it
was read, and nothing else. It carries no addresses. The join to the register
table is on the designator the register name already contains —
`Außentemperatur (B32)` against `B32` — so the mapping under test is stated in
one place only, and the transcription cannot quietly agree with it. The
machine's identifier from the System Informationen page is deliberately left
out; it is evidence for nothing here.

Both captures are full sweeps of all 663 addresses, and both partition them
into the same 232 that answer and 431 that refuse, address for address, as the
sweep of the day before did. Nothing about the machine's configuration moved
between the two days.

## What agrees

Sensors, round 2, web at 20:06 against registers at 20:07–20:09:

| Designator | Address | Web | Register |
|---|---|---|---|
| B32 Außentemperatur | 1000 | 21.0 | 21.05 |
| B38 Wärmespeichertemperatur | 1008 | 21.2 | 21.22 |
| B41 TW-Erw. Temp. | 1012 | 43.9 | 43.91 |
| B48 TW-Erw. Temp. oben | 1014 | 57.4 | 57.40 |
| B37 Ansauglufttemperatur | 1060 | 22.1 | 22.05 |
| B45 Ladefühler | 1066 | 23.8 | 23.84 |
| B51/B53/B54 Vorlauftemperatur HK A/C/D | 1350/1354/1356 | 22.8 / 21.8 / 22.4 | 22.75 / 21.82 / 22.39 |
| B61/B63 Raumtemperatur HK A/C | 1364/1368 | 23.2 / 22.9 | 23.18 / 22.91 |

B41 needed the second round. In round 1 the hot water tank read 45.0 and the
intermediate circuit 44.4, while 1012 read 44.38, which either could explain.
In round 2 they had separated: B41 43.9, B33 43.8, and 1012 read 43.907.

**Existence agrees everywhere but one pair.** B35, B36, B40, B42, B43, B46,
B72 and B31 are absent from the Fühlereingänge page, and 1054, 1058, 1010,
1030, 1056, 1064, 1062 and 1392 all answer −1.0. The page and the sentinel pick
out the same set of fitted sensors.

Settings. Three of these are not at the manufacturer's default, which is what
makes them evidence rather than coincidence — a wrongly named register would
have to hold the same unusual number by accident:

| Address | Name | Web | Register | Default |
|---|---|---|---|---|
| 1033 | Warmwasserladung Einschalttemperatur | 36 °C | 36 | 46 |
| 1034 | Warmwasserladung Ausschalttemperatur | 44 °C | 44 | 50 |
| 1429/1433/1435 | Heizkurve HK A/C/D | 0.4 | 0.4 | 0.6 |
| 1393/1395/1396 | Betriebsart Heizkreis A/C/D | Zeitprogramm, Zeitprogramm, **Aus** | 1, 1, **0** | — |
| 1401/1415, 1442, 1505 | Raumsolltemperatur normal and eco, Heizgrenze, Parallelverschiebung | 22.0, 18.0, 15, 0 | same | at default |

Heating circuit D is the useful one: it is the circuit without a room unit and
the only one switched off, and it is the only one whose mode register reads 0.
A table that had the circuits in the wrong order would have put the 0 elsewhere.

Digital signals, round 1:

| Address | Name | Web | Register |
|---|---|---|---|
| 1098 | EVU - Sperrkontakt | EW/EVU Sperrkontakt 1 | 1 |
| 1100 | Status Verdichter 1 | M1 Verdichter 1, 0 | 0 |
| 1118 | Zirkulationspumpe (M64) | M64 Zirkulationspumpe, 0 | 0 |
| 1112 | Umschaltventil Heizen/Warmwasser (M63) | M63 Ventil Heizen/Vorrang, **Heizen** | **0** |

1112 is the one the parameter list leaves unenumerated. The display says the
valve stands in "Heizen" while the register reads 0, so for this register 0 is
heating and 1 is hot water, not the other way around.

The heat quantities close exactly: 1748 Heizen 1.080 plus 1754 Warmwasser
265.396 plus 1756 Abtauung 0.000 is 266.476, which is what 1750 and 4128 both
read. The System Informationen page tells the same story in hours, 0.2 heating
against 39.7 hot water, and reprints the firmware string recorded yesterday
unchanged.

## Four findings

### A pump that is not driven answers like a pump that is not there

The Analogausgänge page prints its own scale in a footnote:

> "-1%" Pumpe wird nicht angesteuert / "0%" Pumpe läuft mit min. Drehzahl /
> "100%" Pumpe läuft mit max. Drehzahl

and shows `M73 Ladepumpe Wärmesenke Steuersignal` at −1.0 %, while the
Digitalausgänge page shows the same pump's `EIN/AUS` at 100. The pump is fitted
and running. Address 1104, `Status Ladepumpe (M73)`, reads 65535.

So 65535 is −1 and −1 is a state, not an absence. The parameter list says as
much and was not being read: it documents 1104 to 1109 from a **minimum of −1**
to a maximum of 100. Meanwhile 1106, the groundwater pump of a machine that has
no groundwater pump, reads the identical word. The wire cannot separate a pump
nothing is calling for from a pump that was never installed, and the library
was claiming it could.

This also corrects the sign rule. Yesterday's document derived it from the unit
— a `WORD` in degrees Celsius is two's complement — and noted that a bivalence
point set to −1 °C would then be swallowed by the sentinel, with no way around
it. There is a way around it, and the manual supplies it: **a `WORD` whose
documented minimum is negative is signed, and 65535 is a value it may hold.**
That covers the bivalence points at −90 and the pump signals at −1 alike, and
leaves 65535 free to mean absence in the registers documented from 0 up, which
is every other one. `Batteriefüllstand` at address 86 stays absence under this
rule, as yesterday concluded, because no minimum is printed for it at all.

### 1050 and 1052 report sensors that exist as not fitted

`Wärmepumpen Vorlauftemperatur (B33)` and `Wärmepumpen Rücklauftemperatur
(B34)` both answer −1.0, in both rounds. The Fühlereingänge page shows
`B33/B113 Vorlauftemperatur 1 Zwischenkreis` at 44.4 and then 43.8, and
`B34/B114 Rücklauftemperatur 1 Zwischenkreis` at 37.0 and then 36.5. The
sensors are fitted, the controller reads them, and the registers named after
them report absence.

Whether the manual has the designator wrong or this machine populates the pair
only for other hydraulic schemes cannot be settled from here. What can be
settled is the consequence: **this machine exposes no flow temperature, no
return temperature and no flow rate over Modbus at all.** B124 and B125, the
heat sink flow and return, and B2, the flow rate, have no register anywhere in
the list. Anyone reaching for a coefficient of performance will have to take
1790 and 4122 and stop there.

The table keeps saying `present` for 1050 and 1052, because they do answer.

### An enumeration printed once was reaching one register

The list prints the six operating modes beside `Betriebsart Heizkreis A` and
leaves B to G bare, and `enumLabel` was a plain lookup on address and code. So
1395 reading 1 could not be labeled, although the display proves it means
`Zeitprogramm`, and neither could 1396 reading 0, which means `Aus`. The same
held for the active mode of circuits B to G and for compressors 2 to 4.

The expansion belongs in the transcription, not in the parser: the fact that
circuits B to G share A's modes is a fact about the printed list. `transcribe.py`
now groups registers that differ only in the letter or digit ending their name
and are otherwise alike — same datatype, access, range and unit — and gives
every member the enumeration printed beside one of them. It refuses to share
where two members carry enumerations of their own, since they are then not
saying the same thing. The enumeration table grows from 16 addresses to 45; the
register table does not change at all. The zone module rooms turn out to be the
same shape and pick up their modes too.

### The maximum flow temperature is not in the list, and 1449 is not it

Reading a machine that sits at its defaults cannot tell a register from a
coincidence. 1449 to 1455, `Sollvorlauftemperatur HK x (Konstant-HK)`, read 45
for circuits A, C and D, which is both the manual's default for them and the
`Maximale Vorlauftemperatur Heizen` the display showed for all three. Nothing
in rounds 1 and 2 separated the two readings.

So the setting was moved: `Maximale Vorlauftemperatur Heizen` set to 42, 43 and
44 for circuits A, C and D, breaking the tie three ways at once. Comparing the
capture afterwards against the one before, across all 232 addresses that
answer:

- **no setting register changed at all**; the only registers that moved were
  sensors, drifting by tenths
- 1449, 1451 and 1452 still read 45

The manual's name for 1449 stands, then, and it is simply sitting at its
default on circuits that are not constant circuits. `Maximale
Vorlauftemperatur Heizen` has no address anywhere in the list — a conclusion
that searched the whole answering set rather than the registers whose names
suggested themselves.

1450, the same setting for the circuit B this house does not have, reads 60
rather than 45. That is the trap the previous verification records: a circuit
that is not installed still carries factory values, and not even the same ones
as its neighbors.

This rests on the change having reached the controller; it was made from the
display and not read back there.

### A documented minimum the machine does not respect

1034 holds 44 °C. The parameter list documents it from 46 to 53
(`manual/812170.txt:474`; the transcription is faithful). The display shows the
same 44, so this is the controller's value and not a decoding error. A range
check built from the table would reject a setting the machine itself holds,
which matters for the write path that does not exist yet.

## What the web interface shows and Modbus does not

Worth recording as a negative result, since these are the first things asked
for. None of them has a register in the list:

- the refrigerant circuit entire: B71 Heißgastemperatur, B78/B78v
  Verdampfungsdruck and -temperatur, B79 Verdampferaustritt, B86/B86v
  Kondensationsdruck and -temperatur, B87 Flüssigkeitsleitung, superheat,
  subcooling, expansion valve position
- B124 and B125, heat sink flow and return, and B2, the flow rate
- the inverter: motor speed, current, voltage, power, DC bus voltage
- board temperature and the central unit's battery voltage
- most of the heating circuit settings: Raumeinflussfaktor, the mixer
  parameters, Estrich Heizen, Zuschaltzeit, and the minimum and maximum flow
  temperature

The daily heat quantity chart was captured too, but its window starts after the
machine did, so it cannot be summed against 1754 and is not evidence here.

## What changed in the library

- `Drive`, a new type: `NotDriven` or `Driven` per cent. A signed percentage
  decodes to it, so −1 never reaches a caller as a number and `Driven 0`, a
  pump at its minimum speed, is no longer confused with a pump at rest.
- The sign of a `WORD` follows the documented minimum rather than the unit,
  which removes the special case instead of adding one, and stops the sentinel
  from eating a legal bivalence point.
- `enumLabel` reaches every register the manual describes, by way of the
  transcription rather than an alias table in Haskell.

## Reproducing

    cabal run idm-dump -- 192.168.0.200 --json > capture.json

taken within a minute or two of the web page being read. The page is at the
controller's address in a browser; the service pages used here are under
"Wärmepumpe" and "Anlage". Reading a page writes nothing, but the same screens
carry controls that do, so nothing was touched.
