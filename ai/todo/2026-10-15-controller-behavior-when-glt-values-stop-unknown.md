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

## How we might solve it

Per register, once writing exists (`write-interface-with-eeprom-cost-visible`):

1. Note the gate it needs, and whether setting the gate costs an EEPROM
   cycle; leave a sensor-replacing one ungated where possible.
2. Write a value distinct from the real one, cyclically, and confirm the
   controller uses it (`N2_GLTMON` shows the last value written).
3. Stop writing and watch the value the controller uses and its notices for
   longer than the cycle 812170 asks for.
4. Record each in a dated `doc/`, and restore the gates.

Start with 74, which a consumer will write first and which
`unit-of-pv-surplus-74-unsettled` already writes.
