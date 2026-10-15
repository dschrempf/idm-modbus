# What the requests 1710, 1712 and 1713 do is unsettled

## The question

Three volatile `BOOL` registers let a building management system ask the
controller to run. 812170 says this much:

- 1710 `Anforderung Heizen`: in a system that only manages its store and
  runs no heating control, the heat request comes through 1710, with the
  target from 1694. It "should be written cyclically, so the request is there
  again after the display or the machine restarts".
- 1712 `Anforderung Warmwasserladung`: starts a charge regardless of the tank
  temperature, and only withdrawing the request ends it.
- 1713 `Ext. Ansteuerung „Einmalige WW-Ladung“`: must be ended with 0.

Not said:

- Does 1710 start a store charge on a machine whose circuits run on their own
  time program and heating curve, or only on a pure store system?
- Does 1712 respect the setpoint 1032, or the refrigerant limit, and what
  ends a charge whose request is never withdrawn?
- Does 1713 end its charge at the setpoint by itself, so that the 0 only
  re-arms it?
- Does a request survive a restart of the controller, which the advice to
  write 1710 cyclically suggests it does not?
- What do 1091–1093, the demands, show while a request stands?

A consumer that drives the heat pump through these registers needs every
answer, and the second one is a safety question: a consumer that dies after
writing 1712 = 1 leaves the request standing.

## How we might solve it

Once writing exists (`write-interface-with-eeprom-cost-visible`); all three
are volatile, so no EEPROM cycle is spent:

1. With the tank below its setpoint, write 1713 = 1 and watch 1090, 1093,
   B48/B41 and the web backend until the charge ends; then write 0.
2. The same with 1712 = 1, withdrawn after a few minutes; then once more,
   left standing, to see what ends it — watched throughout, ready to
   withdraw.
3. With the circuits idle above the heating limit, write 1710 = 1 and watch
   1090, 1091, B38 and the store's target.
4. Record each in a dated `doc/`, and the answers in the documentation of
   the write interface.
