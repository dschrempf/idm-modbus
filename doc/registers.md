# Registers

What single registers hold on this machine, where that is more than, or
other than, the parameter list says. The rules that hold for every register
are in [modbus.md](modbus.md); what the PV control does with the registers it
reads is in [pv-control.md](pv-control.md).

## Sensors and the heat sink

### The display agrees

The sensors read within the display's rounding of what the web interface
prints beside the same designator: B32 at 1000, B38 at 1008, B41 and B48 at
1012 and 1014, B37 at 1060, B45 at 1066, the circuits' flows at 1350 to 1356
and rooms at 1364 to 1368. The sensors the sensor page leaves out are the
registers that answer -1.0. Settings off their default agree too, which a
wrongly named register would have to do by accident: 1033 and 1034 at 36 and
44, the heating curves at 0.4, and only circuit D, the one switched off,
reading 0 at its mode ([2026-09-20](verification/2026-09-20.md)). Nineteen
settings join on the parameter identifier the web backend sends, and all
agree ([2026-09-20-webapi](verification/2026-09-20-webapi.md)).

1112, the valve M63, which the list leaves unenumerated, reads 0 for
"Heizen" and 1 for hot water.

### The heat pump's own flow and return

1050 and 1052, `Wärmepumpen Vorlauftemperatur (B33)` and `Rücklauftemperatur
(B34)`, answer -1.0, though the sensor page prints both, as the intermediate
circuit's B33/B113 and B34/B114 ([2026-09-20](verification/2026-09-20.md)).
On a machine with a separating heat exchanger the manual sends a reader of
them to the heat sink registers below. The table keeps both `present`,
because they answer.

### The heat sink, 1066 to 1074

None of these is in revision 10; 1068 to 1074 are on the controller's
register page, and revision 12 prints them. Read beside the sensor page while
the machine heated, each tracks its designator within the display's rounding
([2026-10-15-heat-sink](verification/2026-10-15-heat-sink.md)):

| Address | Designator                            | Notes                                     |
| ------- | ------------------------------------- | ----------------------------------------- |
| 1066    | B45 Ladefühler                        | in the list                               |
| 1068    | B124 Rücklauftemperatur Wärmesenke    |                                           |
| 1070    | B125 Vorlauftemperatur Wärmesenke     |                                           |
| 1072    | B2 Durchfluss Wärmesenke              | a `FLOAT`, though the manual says `UCHAR` |
| 1074    | M73 Ladepumpe Wärmesenke Steuersignal | one register, see below                   |

### The charge pump: 1074, not 1104

1074 follows M73's control signal as the analog output page prints it, read
for read, through heating, hot water, defrost and rest, on 20.24-1574 and
20.24-2608: `ffff` is -1, "not driven", and a value is percent of the pump's
speed range. 0 is a state of its own, minimum speed: the first four to five
minutes of a hot water charge stand there with no flow at 1072. The
controller's register page prints 1074 as signed too.

1104, `Status Ladepumpe (M73)`, reads `ffff` throughout, with the pump at
100 %; the table decodes it as `DriveSignal NotDriven`, which is wrong while
the pump runs ([2026-10-16-charge-pump](verification/2026-10-16-charge-pump.md),
[2026-11-09-heating-run-as-on-1574](verification/2026-11-09-heating-run-as-on-1574.md)).
The table still reads 1074 as a one-register count, 65535 at rest: its
`gltmon` row states no datatype, range or unit.

### 1449 and the flow temperature limits, 1520 to 1540

1449 to 1455, `Sollvorlauftemperatur HK x (Konstant-HK)`, are `HKA03` and its
siblings, not the maximum flow temperature: moving the maximum moved none of
them ([2026-09-20](verification/2026-09-20.md)). The minimum and maximum flow
temperature per circuit are outside the list, `FLOAT`s on the register page,
joined to their identifiers by moving each setting
([2026-10-15-flow-temperature](verification/2026-10-15-flow-temperature.md)):

| Address | Parameter                                    |
| ------- | -------------------------------------------- |
| 1520    | `HSA05`, Minimale Vorlauftemperatur Heizen A |
| 1524    | `HSC05`, by elimination                      |
| 1526    | `HSD05`                                      |
| 1534    | `HSA04`, Maximale Vorlauftemperatur Heizen A |
| 1538    | `HSC04`                                      |
| 1540    | `HSD04`                                      |

Circuits B and E to G answer at 1522, 1528 to 1532, 1536 and 1542 to 1546,
which the page does not list and the table leaves out.

## Power and energy

### 4122

`Aktuelle Leistungsaufnahme Wärmepumpe` is the inverter's motor power: it
follows the modulation page's `motor power` to its decimal through heating,
hot water, defrost and the start, on both softwares
([2026-10-16-draw](verification/2026-10-16-draw.md),
[2026-11-09-heating-run-as-on-1574](verification/2026-11-09-heating-run-as-on-1574.md)).
812184 calls it a model output, and the register page a polynomial "falls kein
Wert vom Inverter vorhanden ist"; this machine has the inverter's. The fan,
the pumps and the controller are not in it. At standstill it reads 0.0, with
`PV008` set too, not the forecast 812184 describes; the forecast is on the
PV page ([pv-control.md](pv-control.md)).

### 4126 and 1790

4126, `thermische Leistung (Durchflusssensor)`, is computed from the heat
sink: divided by the flow at 1072 and the spread from 1068 to 1070 it gives
4.12 to 4.26 kJ/(kg·K), median 4.186, the specific heat of water. It reads 0
while the charge pump stands at its minimum with no flow, though the
compressor runs, and goes negative in a defrost, to about -7.8 kW
([2026-10-15-heat-sink](verification/2026-10-15-heat-sink.md),
[2026-10-16-draw](verification/2026-10-16-draw.md)). 1790 equals 4126 in every
read ([2026-10-01-charge](verification/2026-10-01-charge.md)).

### The Wärmemenge counters, 1746 to 1762

1746, `Elektrische Leistungsaufnahme (gesamt)`, from the register page, is a
`FLOAT` in kWh, as the manual's counters are
([2026-10-14-gltmon](verification/2026-10-14-gltmon.md)).

The heat counters add up among themselves: 1748 Heizen, 1754 Warmwasser and
1756 Abtauung sum to 1750 Gesamt, which 4128 repeats. Over a charge, 1754 is
the running integral of 4126, to 0.6 %
([2026-10-01-charge](verification/2026-10-01-charge.md)).

They disagree with the controller's statistics page by a factor near 1.19,
not by the fixed offset a reset would leave, and the factor holds within a
single charge: 8.494 kWh against 10.25, 11.228 against 13.17. On the day of
2026-10-01 the page's runtime and electrical energy agree with the registers
and only its heat differs. No register carries the page's figure. The page
has a defect the registers lack — a day booked with hot water heat and no
runtime — so it is no witness against them
([2026-09-20-webapi](verification/2026-09-20-webapi.md),
[2026-10-01-charge](verification/2026-10-01-charge.md)). What the page
computes as heat is open.

## Settings and states

### 1005, the operating mode

The manual prints the codes 0, 1, 2, 4 and 5 within a range of 0 to 5. The
web backend offers -1 and 3 besides, which its translations label "Aus",
without frost protection, and "Urlaub", and over Modbus "Aus" reads `ffff`
and "Urlaub" 3 ([2026-10-15-web-app](verification/2026-10-15-web-app.md)).
`data/navigator-10-measured-enums.tsv` adds both and widens the range to -1,
so `ffff` decodes to "Aus" here, not to no value.

### 1714 and 1715

The two external pump requests answer `fffe`, which the register page prints
as -2, where every other unfitted `UCHAR` answers `ffff`. The library treats
-1 and -2 alike as no value. Whether -2 means "no external request" or "no
such pump" this machine, which has neither pump, cannot tell, and the web app
names the registers without saying
([2026-10-15-web-app](verification/2026-10-15-web-app.md)).

### The energy management block, 74 to 88

74 to 86 are the block an inverter or energy manager supplies, `RW/RO`
([modbus.md](modbus.md#the-access-right-rwro)); 88 `PV-Zielwert` is a `FLOAT`
of revision 12. All answer. The floats read 0.0 while nothing feeds them,
and 86 `Batteriefüllstand` reads `ffff`, the sentinel, on a machine without a
battery ([2026-09-19](verification/2026-09-19.md)). 74 is in kW; what the
controller does with 74 and 88 is in [pv-control.md](pv-control.md).

### 4108 to 4114, the power limits

4108 `Leistungsbegrenzung Wärmepumpe`, a `FLOAT` in kW, reads -1.0 by default,
at rest and in every mode. It is volatile
([2026-11-07-restart](verification/2026-11-07-restart.md)) and caps or ends a
PV run ([pv-control.md](pv-control.md#the-power-limit-at-4108)). No setting
in the web backend joins it; the translations hold the key
`N2_POWER_LIMIT_HEATPUMP`, but no setting carries it. `EV003`, the response to
the grid operator's lock contact, offers a power limit whose parameter, 4.2 kW
by default, is not in any capture; 4108's -1.0 speaks against its being that
parameter ([2026-10-15-web-app](verification/2026-10-15-web-app.md)).

4112, the manual's `FLOAT` `Leistungsbegrenzung Kaskade`, was two registers
wide on 20.24-1574. On 20.24-2608 4110 to 4114 each answer alone, and the
register page names 4110 `Sperre`, 4113 `Sperre Booster 1` and 4114 `Sperre
Booster 2`, and 4111 and 4112 not at all; the table leaves 4112 out
([software-versions.md](software-versions.md)).

### The software version

On 20.24-2608, 522, 524 and 526 read the major, minor and patch number, 24,
2608 and 0, one register each. 528 `Software Version (Build Info)` reads 0,
and 4116 `Firmware Version IDM`, which the page prints as the version string,
reads a float near 10⁻¹²; the table leaves both out. 4120, which
Xerolux/idm-heatpump-api reads as `firmware_version`, answers exception 02
as one register or two, by function code 3 and 4
([2026-11-09-firmware-register](verification/2026-11-09-firmware-register.md)).
Where each channel reads the version is in
[software-versions.md](software-versions.md).
