# The EEPROM guard needs an exact round trip

`write` sends nothing to an EEPROM target whose read equals `wire` of the
encoded value, byte for byte (`writeWith` in
`lib/core/IDM/Navigator/Write/Core.hs`, the `SEepromCycle` branch). That
only spares a cycle if the controller hands back exactly the bytes it was
sent. If it stores a setpoint at its own resolution, as a `FLOAT` rounded
to 0.1 or a whole number behind a `FLOAT`, then `write t 21.3` reads back
`21.299999` or `21.0`. Every repeat is then `Sent (DidNotStick …)` and
spends a cycle, which is the pattern the type exists to stop. A consumer
repeating a setpoint every minute would use up the EEPROM in about seven
months.

The controller takes a `FLOAT` as sent: each write of 3.0 to 74 read back
`00004040`, and 0.0 `00000000`
(`doc/verification/2026-11-05-pv-surplus.md`). Whether it rounds on storage
is open: 74 is volatile, and no EEPROM write has gone to the machine yet.

Only a `FLOAT` raises the question; an integer datatype has no finer value
to round away. Every `FLOAT` 812663 stars belongs to a heating circuit or
zone module family, which `tools/transcribe.py` refuses as a target. The
`FLOAT` targets it would admit at an EEPROM cost are the cascade powers
4132, 4136 and 4140 of `N2_GLTMON`, whose persistence is unknown and which
this machine, without a cascade, may ignore. Which write settles the
question is open.

## How we might settle it

1. On the machine, with the first EEPROM target listed: write a value the
   display can show, read it back with `idm-dump`, and compare the bytes.
   Then write a value off the display's resolution, e.g. 21.33 for a
   temperature setpoint, and compare again. Record it in a dated
   `doc/verification/`. Each of the two writes costs one cycle.
2. If the bytes differ, compare decoded values instead, at the resolution
   the controller keeps. That resolution is not in the table, so it would
   be a measured fact entering the table. For codes,
   `decide-how-a-measured-fact-enters-the-table` chose a hand-written input
   that `tools/transcribe.py` joins, citing its evidence; a resolution
   would follow it.

Option 2 without step 1 would guess a resolution. Step 1 alone is enough if
the bytes match.
