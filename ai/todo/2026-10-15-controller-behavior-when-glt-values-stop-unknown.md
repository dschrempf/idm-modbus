# What the controller does when written values stop arriving is unknown

## The question

Several registers let a building management system replace a sensor or feed a
value: 1690 the outdoor temperature, 1692 the humidity, 1650–1662 the room
temperatures, 1716–1722 the store and hot water tank temperatures, 74 to 86
the PV and house values, 1696 the heating temperature request. 812170 asks
for them to be written cyclically — 1696 "every 10 minutes" — and says
nothing about what happens when they stop. Possible answers per register:
the controller falls back to its own sensor, holds the last value, uses the
default, or raises a fault.

It also names a menu parameter that gates some of them — "GLT
Außentemperatur" and "GLT Feuchtewert" for 1690 and 1692, "GLT Raumsensor"
for a circuit's room temperature, PV008 for 74 — and none for 1716–1722 or
1696.

A consumer that writes any of them must know what its own failure does to
the house. If the controller holds the last outdoor temperature, a crashed
consumer can stop the heating.

## Found on 2026-11-05

Software 20.24-2608 adds two settings to the PV menu. `SSYSPV031`
`N2_PVStaticHousepwrActive`, No/Yes, reads No; its help text says that
while it is No, `SSYSPV030` `N2_PVOffGridHousePower`, 0 to 10 kW, now 1.0,
stands in for the house consumption once the smart meter has sent nothing
for more than five hours (`doc/software-versions.md`). That is the first
stated fallback, for 82 at most. Whether a value written over Modbus counts
as the smart meter is for 74's test below to find out.

## How we might solve it

Per register, activated as a target together with this test:

1. Note the gate it needs, and whether setting the gate costs an EEPROM
   cycle; leave a sensor-replacing one ungated where possible.
2. Write a value distinct from the real one, cyclically, and confirm the
   controller uses it (`N2_GLTMON` shows the last value written).
3. Stop writing and watch the value the controller uses and its notices for
   longer than the cycle 812170 asks for.
4. Record each in a dated `doc/`, and restore the gates.

Start with 74, which a consumer will write first and which
`unit-of-pv-surplus-74-unsettled` already writes.

For 74, steps 1 and 2 are done (2026-11-05,
`doc/verification-2026-11-05-pv-surplus.md`): the gate is `PV008` at
`N2_GLTSF`, one EEPROM cycle, and the PV page showed the value written at
once. Step 3 is not: that run ended with 0 written by hand. With the store
below `PV006`, write 3.0 for a few minutes, stop, and watch the page's
`Überschuss`, 1090 and 1100 for longer than the five hours of `SSYSPV030`.

Planned for the night of 2026-11-06, after the run of
`pv-surplus-74-may-include-the-pumps-own-draw`: write 1.0 once and stop,
and watch 74 over Modbus, the page's `Überschuss`, 1090, 1100 and B38
overnight. B38 will stand near `PV006` then; a run that starts once it has
cooled shows the value held. `what-a-power-cycle-does-to-74-and-the-controller`
ends the watch.

Not run on 2026-11-06: the session ended after the own-draw test, and the
overnight watch waits for the next one. The last write of that day was
-0.5 at 11:37:15. A read of 74 after more than five hours says whether it
held the value or reset it, though not what the PV logic does with it.
