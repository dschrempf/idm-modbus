# Does the control act on a 74 no one renews?

Step 3 of `controller-behavior-when-glt-values-stop-unknown` for 74: what
the controller does once a consumer stops writing a surplus. A consumer that
dies after writing one must not leave the pump charging. Steps 1 and 2 are
done, and the register keeps its value past `SSYSPV030`'s five hours
(`doc/pv-control.md`, "A value no one renews"); what the control does with
it is not known.

## The test

Overnight, with the store below `PV006`: write a value that starts a
charge once, 1.7 or above (1.0 did not), and stop writing. Watch 74 over
Modbus, the PV page's `Überschuss`, 1090, 1100 and B38 for longer than five
hours. B38 will stand near `PV006` after the first charge; a run that
starts once it has cooled shows the value acted on. A restart from the
display drops 74 to 0; a power cycle is not needed for the test.
