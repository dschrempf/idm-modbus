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
for more than five hours (`doc/verification/2026-11-05-software-update.md`). That is the first
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

74 went first, as a consumer writes it first: steps 1 and 2 are done
(`doc/verification/2026-11-05-pv-surplus.md`), and step 3 is in
`pv-control-of-74-and-88`, `does-the-control-act-on-a-74-no-one-renews.md`.
The others follow, each when it is listed as a target.
