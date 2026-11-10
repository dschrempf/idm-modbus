# Modbus on the Navigator 10

What the controller does on the wire that the manual does not say, or says
wrong, and what the library makes of it. What a single register means is in
[registers.md](registers.md).

Reaching the machine takes "Modbus TCP" "Ein" under "Gebäudeleittechnik" at
service level; it answers on port 502, unit id 1. Every address of 812663
was read on this machine: of its 582, 262 answer and 320 refuse with
exception 02, all of them in the zone module block from 2000 on, which the
machine lacks (`captures/navigator-10-scan-20.24-2608-2026-11-06-2120.json`,
the `observed` column of `data/navigator-10-registers.tsv`). 1999, write-only,
refused on 20.24-1574 and reads `0000` since 20.24-2608
([2026-09-19-scan](verification/2026-09-19-scan.md),
[2026-11-05-software-update](verification/2026-11-05-software-update.md)).
Addresses the manual does not describe answer as well: the controller's own
list names them ([sources.md](sources.md#the-controllers-own-list)).

## Reading

### Word order

A 32-bit float occupies two consecutive registers, **low word first**,
against the usual Modbus habit; it is the most common bug in community
configurations. Read so, the settings agree bit for bit with the double the
web backend hands over: 1429 `cccd3ecc` is 0.4000000059604645 on both
channels ([2026-09-20-webapi](verification/2026-09-20-webapi.md)).

### Function codes 3 and 4

Both return the same data for every address tried, including 4122, which
812184 calls an input register, and 74, which it calls a holding register.
They refuse alike too: 4120 answers exception 02 to both
([2026-09-19-scan](verification/2026-09-19-scan.md),
[2026-11-09-firmware-register](verification/2026-11-09-firmware-register.md)).
The library reads holding registers, function code 3, since a write needs
them.

### Absence is a value

An unfitted sensor does not fail to answer: it answers a sentinel. `decode`
returns `NoValue` for it, so a -1 never enters a temperature series.

| Datatype | Sentinel              | On the wire    |
| -------- | --------------------- | -------------- |
| `FLOAT`  | -1.0                  | `0000bf80`     |
| `UCHAR`  | -1, and -2 at two     | `ffff`, `fffe` |
| `WORD`   | 65535, where unsigned | `ffff`         |

The sentinel says that a register holds no value, not that the hardware is
missing: 1050 and 1052 answer it for the fitted B33 and B34
([registers.md](registers.md#the-heat-pumps-own-flow-and-return)).

Where a sentinel could be a reading, the documented range decides:

- **`FLOAT`.** No `FLOAT` documents a negative minimum, most document no
  range, and -1 °C is an outdoor temperature; 1002 arrives rounded to
  hundredths and stands at -1.00 whenever the average does. So -1.0 is
  `NoValue` only where a documented range excludes it, and `NoValueOr`, no
  value or -1, elsewhere ([2026-09-19-scan](verification/2026-09-19-scan.md)).
- **`WORD`.** A `WORD` is two's complement where the parameter list
  documents a negative minimum for it, or a negative default for a read-only
  one, and there 65535 is -1, a value. The bivalence points 1120 and 1121
  read `fffb` and `ffec`, which the controller prints as -5 and -20 °C beside
  `BV002` and `BV003`; the pump signals 1104 to 1109, documented from -1 in
  revision 10 and with a default of -1 since, read `ffff` for "not driven"
  ([2026-09-20-display](verification/2026-09-20-display.md),
  [2026-09-20-webapi](verification/2026-09-20-webapi.md)). Every `WORD`
  documented from 0 up stays at or below 100, so there 65535 cannot be a
  reading. 86 `Batteriefüllstand`, supplied by the building management
  system, defaults to -1 too, and holds it until something is supplied, so
  there `ffff` stays the sentinel.
- **`UCHAR`.** A `UCHAR` arrives as a whole register, and the controller
  reads it as a signed word: of 84 that answer, 67 have a high byte of `00`,
  15 read `ffff` and 1714 and 1715 `fffe`; none reads `00ff`. The register
  page prints `fffe` as -2. `decode` takes any negative `UCHAR` for no value
  unless its range admits it. 1005 is the one whose range does: `ffff` is the
  operating mode "Aus" there
  ([2026-10-15-web-app](verification/2026-10-15-web-app.md),
  [registers.md](registers.md#1005-the-operating-mode)).

A target is not a sensor: an idle circuit's `Sollvorlauftemperatur`, 1378 to
1390, reads 0.0, and the controller prints 0.0. Zero there is a value
([2026-09-20-webapi](verification/2026-09-20-webapi.md)).

### What the registers cannot tell

**The heating circuits a machine has.** The settings of a circuit that does
not exist hold plausible factory defaults, heating curve 1.2 and heating
limit 15 °C, not sentinels. The sensors and the active operating modes, 1498
to 1504, do not settle it either: circuit B, the machine's internal heating
circuit, exists and reads -1.0 and `ffff` there exactly as the missing E to
G do. Auto-detection finds the circuits that have sensors on them, not the
circuits ([2026-09-20-display](verification/2026-09-20-display.md)).

**Whether a pump is fitted.** A fitted pump not being driven and a pump never
installed answer the same `ffff` at 1104 to 1109.

**That a setting is in range.** 1034 holds 44 °C, which the display shows
too, against a documented range of 46 to 53. A range check built from the
table would reject a value the controller holds.

### Enumerations

The manual prints an enumeration once per family: the operating modes beside
heating circuit A, 1393, and B to G bare. `tools/transcribe.py` shares an
encoding across registers that are alike but for the letter or digit ending
their name — heating circuits B to G, compressors 2 to 4, the rooms of a
zone module — or the number of the zone module inside it, so `enumLabel`
reaches every member ([2026-09-20-display](verification/2026-09-20-display.md)).
Codes the manual does not print but the machine answers are in
`data/navigator-10-measured-enums.tsv`.

### Pacing

The Navigator stalls when polled hard: one user's integration, reading in
blocks of up to 32 registers, failed when it polled more often than every
22 s, and an iDM service partner advises 60 s
([sources.md](sources.md#community-work)). The library paces single
reads at `pollIntervalMicroseconds`. Watches here read a dozen registers
every 10 s, one request each, for hours without a failure, two connections
at once included.

## Writing

### The access right `RW/RO`

127 registers of 812663 carry `RW/RO`, which the introduction to chapter 4,
defining `RO`, `RW` and `W`, does not: the energy management block at 74 to
88 and every zone module room value. The table reads it as "supplied": the
building management system may write it and read it back, as the worked
examples of chapter 4.3 do. For the PV block a menu setting gates it, `PV008`, which is
not addressable; with `PV008` at "Gebäudeleittechnik/Smartfox" a write to
74 takes effect ([pv-control.md](pv-control.md)). Whether a write takes
effect elsewhere without its menu parameter at "Ja" is untested.

### EEPROM

Registers marked with a star are written straight into the controller's
EEPROM, which the manual rates at 300000 write cycles; a starred setpoint
adjusted once a minute is worn out in about seven months. The star is a
register's `Persistence`, the cost is in the type of every target, and an
EEPROM write reads first and sends nothing when the value is held already.

A volatile register is not held across a restart. 4108, unstarred, read
-1.0, its default, from the first read after a `System Neustart`, where 3.0
had been written ([2026-11-07-restart](verification/2026-11-07-restart.md)).

### What a write does

A volatile `FLOAT` round-trips byte for byte: 3.0 written to 74 reads back
`00004040`. A write on its own connection beside a polling watch stalls
nothing ([2026-11-05-pv-surplus](verification/2026-11-05-pv-surplus.md)).
The controller does not drop a written value as stale: 74 read -0.5 8 h 10
min after the last write, and 4108 held 3.0 unrenewed until the restart six
minutes later. What the control does with a value nobody renews is open
([pv-control.md](pv-control.md#a-value-no-one-renews)).

### A restart

A restart from the display drops every value a building management system
wrote that was watched, 74, 88 and 4108, and the `GLT Value` of 12763 empties.
Modbus answers again about 10 s after the controller closes the connection,
and for another 20 to 30 s answers the sentinels of an unfitted sensor, with
no exception. Settings stand
([2026-11-07-restart](verification/2026-11-07-restart.md)). A consumer that
wants a written value writes it again after a restart.
