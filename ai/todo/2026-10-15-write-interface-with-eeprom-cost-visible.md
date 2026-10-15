# A write interface that makes the EEPROM cost visible

## The question

The package reads and sets the user level, and nothing else. A consumer that
manages the heat pump needs writes: the requests 1710, 1712 and 1713, the PV
surplus at 74, and now and then an operating mode or setpoint. `CLAUDE.md`
keeps writing out until an interface makes the cost of an EEPROM write
visible rather than leaving it to an extra argument: a register's
`Persistence` says which writes cost one of the controller's 300,000 cycles.

## How we might solve it

1. Function codes 6 (one register) and 16 (several) in `IDM.Modbus.TCP`,
   returning the same `Failure` as the reads.
2. A write in `IDM.Navigator.Client` whose type depends on `Persistence`: a
   volatile write and an EEPROM write are different functions or take
   different evidence, so a caller can't write an EEPROM register without
   saying so in the code. The `unknown` persistence of the `gltmon` rows has
   to be one or the other until measured, and the cautious choice is EEPROM.
3. Encoding as the inverse of `decode`: low word first for `FLOAT`, two's
   complement where the minimum is negative, the range checked before
   sending.
4. Read back after writing, and report a value that did not stick.

A write budget — how many EEPROM writes a day — is a strategy and belongs to
the consumer; the package may offer at most a hook that counts.

The first writes worth making with it are already waiting:
`unit-of-pv-surplus-74-unsettled` and
`what-glt-requests-1710-1712-1713-do-unsettled`.
