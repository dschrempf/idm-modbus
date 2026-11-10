# The heat pump

How the machine behaves, as far as a consumer of the registers needs to
know: its configuration, the compressor's speeds and draws, a start, a hot
water charge, frost protection. What the PV control adds is in
[pv-control.md](pv-control.md).

## The installation

|                                                                   |                                                                        |
| ----------------------------------------------------------------- | ---------------------------------------------------------------------- |
| Model                                                             | iDM AERO ALM 2-8, R290                                                 |
| Controller                                                        | Navigator 10 ([software-versions.md](software-versions.md))            |
| Heating circuits                                                  | A, C, D (D without a room unit), and B, the machine's internal circuit |
| Heat sink                                                         | an intermediate circuit and a safety heat exchanger to the house side  |
| Buffer                                                            | 300 l                                                                  |
| Domestic hot water                                                | 300 l                                                                  |
| Zone modules, solar, ISC, cascade, second heat generator, cooling | none                                                                   |

## The compressor's speed and draw

The modulation settings are percent of a speed, 1.2 rps per percent: the
defrost's `IV007` at 65 % ran at 78.0 rps, and the heating floor, `IV003` at
20 %, held 24.0 rps
([2026-11-05-floor](verification/2026-11-05-floor.md)). The draw is 4122,
the inverter's figure ([registers.md](registers.md#4122)).

| State                                              | Speed, rps | 4122, kW  |
| -------------------------------------------------- | ---------- | --------- |
| Heating floor, at 8.3 °C outdoors and 27.8 °C flow | 24.0       | 0.61–0.72 |
| Start program, every mode                          | 50.4       | 0.9–1.4   |
| Hot water, held at the floor of the charge         | 39.9       | 1.5–1.7   |
| Heating, unrestricted                              | 101–120    | 2.5–3.5   |
| Top, in a PV run                                   | 120        | about 4   |

At the heating floor the compressor gave 2.8 kW of heat, a coefficient of
performance of about 4.1. Colder air or a warmer flow draws more at the same
speed; the floor was measured at one point. The heating cap, `IV002`, is
untested: set to 50 %, 60 rps, it did not bind in the one run that lowered
it, which never asked for more than the start program's speed.

## A start and a stop

On a request 1090 turns to the mode, and in the same round the charge pump's
signal at 1074 rises to 100. The compressor, 1100, starts 50 s later and the
signal drops to 60; 4122 leaves 0 a round after that. The start program
then holds 50.4 rps for three to four minutes, in heating, hot water and PV
runs alike ([2026-10-16-charge-pump](verification/2026-10-16-charge-pump.md),
[2026-11-09-heating-run-as-on-1574](verification/2026-11-09-heating-run-as-on-1574.md)).
At a stop the compressor and the mode stop together, and the pump's signal
goes to -1 a round later, the flow with it.

A heating run without the PV loop comes down to the floor on its own once
the flow nears its target, and held it for seven minutes
([2026-11-05-floor](verification/2026-11-05-floor.md)). A circuit requests
heat once its flow has stood below its set flow for its add-on time, `HKx59`,
15 min here; the operator gives the margin as 1 K
([2026-11-09-heating-run-as-on-1574](verification/2026-11-09-heating-run-as-on-1574.md)).

The compressor's minimum runtime is 10 minutes (setting 5412, `WP010`) and
its minimum standstill 10 minutes (5419); the PV control does not always
keep the first ([pv-control.md](pv-control.md#what-stops-a-run)).

## Hot water

The charge pump stands at its minimum, with no flow at 1072, for the first
four to ten minutes of a charge while the compressor heats the intermediate
circuit; 4126 reads 0 meanwhile.

**A charge ends at the refrigerant circuit's limit, not at a time limit.**
Every charge from 2026-09-17 to 09-28 left the top of the tank at 59.0 to
59.7 °C, from different starts and against targets of 60 to 64 °C, after
different durations. Sampled every 10 s, a charge to 64 °C throttled the
compressor from a condensation temperature of about 60 °C, held it at 39.9
rps for its last 58 minutes, and stopped with the condensation temperature
at 69.4 °C; nothing reported a fault. 812199 gives the R290 circuit 70 °C,
lowered to 55 °C at -20 °C outdoors. The tank top ends ten degrees below
because the heat passes the intermediate circuit and the safety heat
exchanger first ([2026-10-01-charge](verification/2026-10-01-charge.md)).
So a legionella target of 60 °C, `FW045`'s lowest, is out of reach of the
heat pump alone on this tank. The charge that took the top from 44 to 60 °C
gave 2.7 units of heat per unit of electricity.

## Defrost

1090 reads 8 `Abtauung`; the compressor runs up to 78 rps, and 4126 goes
negative, to about -7 to -8 kW, heat taken from the heat sink's water
([2026-10-16-draw](verification/2026-10-16-draw.md)). The request reason is
absent during it ([web-backend.md](web-backend.md#the-request-reason)).

## Frost protection

Below `AE025`, 3 °C, each circuit with its frost protection on, `HSx40`,
runs its pump with a flow target of 10 °C, whatever its mode: circuit D,
switched off, ran too, until `HSD40` was turned off. The target is not
`AE026`'s 20 °C. It keys on a current temperature, B32 or B37, not the
average at 1002, and asks nothing of the heat pump while the flows stay
above 10 °C. A circuit not in frost protection reads 0.0 at its target
([2026-11-06-frost-protection](verification/2026-11-06-frost-protection.md)).
Only the system's mode "Aus", -1 at 1005, is documented to stop it. Where it
lets go, and what `AE026` governs, is open.
