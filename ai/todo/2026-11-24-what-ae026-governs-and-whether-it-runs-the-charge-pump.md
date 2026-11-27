# What `AE026` governs, and whether it runs the charge pump

`AE026` `N2_FROST_PROTECTION_FLOW_TEMP`, 5755, 20 °C, beside `AE025` at
3 °C. The overnight watch of 2026-11-26 settled two parts
(`doc/verification/2026-11-26-below-ae025-the-charge-pump-ran-only-for-a-circuits-request.md`):
the outdoor unit's frost protection of 812199 §5.7 does not start M73 on
B33 or B34 below `AE026`, and 4789's M73 reads 100 whether the pump runs
or not, so 1074 and 1072 are the witnesses. `doc/heat-pump.md`'s frost
protection section carries both.

## What is left

Whether it keys on the heat sink, B124/B125: 812199 §1.8 requires a
heating-side minimum of 20 °C for the defrost, which is what the web
interface says `AE026` secures. That night C's requests at 02:28 and
04:56 heated B125 before it fell below 21.7 °C. It falls about 0.7 K an
hour from 25.5 °C, so it needs about eight hours below `AE025` without a
heating request, which C's timetable did not give.

The same two watches as on 2026-11-26 answer it, reading only; the
commands are in the measurement's "Reproducing". What a night without a
request needs is a setting change of C's (its night setback, or its
mode), at an EEPROM cycle each way, to be agreed before.

Also open, cheaply: what fills the intermediate circuit of the
`CF085` separation kit, brine or water (812199 §5.8; the kit's papers).
