# Does the control act on a 74 no one renews?

Step 3 of `controller-behavior-when-glt-values-stop-unknown` for 74: what
the controller does once a consumer stops writing a surplus. A consumer that
dies after writing one must not leave the pump charging. That note holds the
question for every register a building management system writes, and the
`SSYSPV030` fallback of 2026-11-05.

## The test

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

On 2026-11-06 at 19:47, 74 read -0.5, 8 h 10 min after the last write: the
register keeps the value past `SSYSPV030`'s five hours. What the control
does with it is still open; an evcc user reports that the controller kept
acting overnight on the last value written
(`doc/pv-control.md`). Decided on 2026-11-06 to run the overnight test on a
later night, as a consumer that dies after writing a surplus must not leave
the pump charging. Write a value that starts a charge, as 1.0 did not: 1.7
or above.
