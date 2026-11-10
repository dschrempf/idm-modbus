# A PV hot water charge on 74 is untested

## The question

The runs on 74 so far charged the heating store, with `PV002`
`N2_DHW_HEATING` at No (`doc/verification/2026-11-05-pv-surplus.md`). A
consumer may want hot water charged the same way, in the warm hours. 812184
says a hot water charge started on PV runs to its end whatever the surplus
does after, to `PV005`. Not known on this machine:

- What `PV005` reads, and whether it raises the tank above its setpoint at
  1032 or only charges to it.
- What the charge draws. At its floor of 40 % a hot water charge drew 1.5 to
  1.7 kW (`doc/verification/2026-10-01-charge.md`), more than twice the
  heating floor, so the threshold on the PV page is higher too.
- Which goes first with `PV001` and `PV002` both Yes, and whether a store
  charge resumes after the hot water charge.
- How a PV charge sits with the controller's own hot water time program and
  legionella run.

## How we might solve it

After the store charge questions on 74 are settled:

1. Read the PV menu at Fachmann level; set `PV002` to Yes, at one EEPROM
   cycle, and note `PV005`.
2. With the tank below `PV005`, write a surplus above the page's hot water
   threshold every minute, then stop writing once the charge runs. Watch
   1090, 1100, 4122, B48, B41 and the page.
3. Record it in a dated `doc/`, and restore `PV002` unless the consumer
   wants it.
