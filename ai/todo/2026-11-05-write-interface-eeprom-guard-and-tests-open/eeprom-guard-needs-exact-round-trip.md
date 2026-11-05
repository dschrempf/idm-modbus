# The EEPROM guard needs an exact round trip

`write` sends nothing to an EEPROM target whose read equals `wire` of the
encoded value, byte for byte (`src/IDM/Navigator/Write.hs`, the `SEepromCycle`
branch). That only spares a cycle if the controller hands back exactly the
bytes it was sent. If it stores a setpoint at its own resolution, as a
`FLOAT` rounded to 0.1 or a whole number behind a `FLOAT`, then
`write t 21.3` reads back `21.299999` or `21.0`. Every repeat is then
`Sent (DidNotStick …)` and spends a cycle, which is the pattern the type
exists to stop. A consumer repeating a setpoint every minute would use up
the EEPROM in about seven months.

No write has gone to the machine yet. 74 is volatile, so its round trip
says nothing about the EEPROM registers.

## How we might settle it

1. On the machine, with the first EEPROM target listed: write a value the
   display can show, read it back with `idm-dump`, and compare the bytes.
   Then write a value off the display's resolution, e.g. 21.33 for a
   temperature setpoint, and compare again. Record it in a dated `doc/`.
   Each of the two writes costs one cycle.
2. If the bytes differ, compare decoded values instead, at the resolution
   the controller keeps. That resolution is not in the table, so it would
   be a measured fact entering the table, the question of session 4 of
   `run-the-open-todos-in-six-sessions`.

Option 2 without step 1 would guess a resolution. Step 1 alone is enough if
the bytes match.
