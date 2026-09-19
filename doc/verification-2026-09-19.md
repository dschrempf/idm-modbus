# Verifying the parameter list against a running machine

2026-09-19. Every one of the 497 addresses in document 812170 revision 10 was
read once, sequentially, over one connection, with 150 ms between requests.
Read access only; nothing was written. The raw result is
`data/navigator-2.0-scan-2026-09-19.json`.

## The machine

| | |
|---|---|
| Model | iDM AERO ALM 2-8 |
| Controller | Navigator 2.0, firmware `T_NAV10_20.24-1574-g183d9b17a` |
| Heating circuits | A, C, D (D without a room unit) |
| Buffer | 300 l |
| Domestic hot water | 300 l |
| Zone modules | none |
| Solar, ISC, cascade, second heat generator | none |
| Modbus | port 502, unit id 1 |

## Result

| | |
|---|---|
| Answered | 226 |
| Refused with `IllegalDataAddress` | 271 |
| Any other failure | 0 |

**Every refusal is explained by the machine's configuration.** The refused set
is exactly the zone module block, addresses 2000 to 2649, which this house does
not have, plus 1999, which is write-only. Nothing in the documented address
layout is missing on firmware 20.24, and nothing answered that the manual does
not describe.

Addresses answered in these blocks:

    1000-1066  1090-1124  1147-1152  1200-1231  1350-1511
    1650-1662  1690-1722  1748-1762  1790-1792  1850-1874  4122-4128

## Readings that confirm the decoding

Taken while the system was in "hot water only" mode on a mild September
afternoon, compressor off.

| Address | Reading | Why it confirms something |
|---|---|---|
| 1000 | 21.59 °C | outdoor temperature; float, low word first |
| 1002 | 17.16 °C | averaged outdoor temperature |
| 1008 | 21.25 °C | buffer |
| 1012 / 1014 | 41.00 / 53.20 °C | hot water bottom and top, a plausible stratification |
| 1032 | 46 °C | hot water setpoint, exactly the documented default |
| 1005 | 4 | system mode, resolves to "Nur Warmwasser" via the enumeration |
| 1350 / 1354 / 1356 | 22.63 / 21.71 / 22.14 °C | flow temperature of circuits A, C, D |
| 1352, 1358-1362 | -1.0 | circuits B, E, F, G: not fitted |
| 1750 | 257.982 | total heat, and 1.080 + 256.902 + 0.0 for heating, hot water and defrost sums to it exactly |
| 4128 | 257.982 kWh | the same quantity under a second address |

## The three findings

### Absence is a value, not an error

An unfitted sensor answers normally, with a sentinel:

| Datatype | Sentinel | Highest documented real value |
|---|---|---|
| `FLOAT` | `-1.0` | — |
| `UCHAR` | `255` (and `254`, see below) | 95 |
| `WORD` | `65535` | 100 |

Because no documented maximum comes near, the sentinel cannot be mistaken for a
measurement. The library encodes this as `Reading a = NotFitted | Measured a`,
so a caller cannot average a -1 into a temperature series by accident.

Addresses 1714 and 1715, "Externe Anforderung Grundwasserpumpe", return `254`
rather than `255`. There is no groundwater pump here, so this is most likely a
second sentinel, but it could be a real value. Treated as absence for now.

### A temperature-carrying `WORD` is signed

| Address | Raw | Means |
|---|---|---|
| 1120 | 65531 | -5 °C, second heat generator bivalence point 1 |
| 1121 | 65516 | -20 °C, bivalence point 2 |
| 1104 | 65535 | not fitted — charge pump status, in percent |

So the same raw 16-bit pattern means "minus one degree" in one register and
"absent" in another, distinguished only by the unit. The library reads a `WORD`
as two's complement when the unit is degrees Celsius, and treats `65535` as
absence first. A bivalence point genuinely set to -1 °C would therefore be
misread; the protocol gives no way to avoid that.

### Function codes 3 and 4 are interchangeable

Both return identical data for every address tried, including 4122, which
812184 calls an input register. The library defaults to holding registers.

## And one trap

Settings do not reveal whether a heating circuit exists. Circuits B and E to G
are not installed, yet:

| Address | Circuit | Value |
|---|---|---|
| 1429 / 1433 | A / C | heating curve 0.4 |
| 1431 / 1437 | B / E | heating curve 1.2 — a factory default, not a sentinel |
| 1443 / 1446 | B / E | heating limit 15 °C, same as the real circuits |

Only read-only sensors (`-1.0`) and the active operating mode registers 1498 to
1504 (`255`) report absence. Any auto-detection must use those.

## Reproducing

    idm-dump 192.168.0.200 --all

sweeps the full parameter list; without `--all` it reads only the addresses
recorded as present here.
