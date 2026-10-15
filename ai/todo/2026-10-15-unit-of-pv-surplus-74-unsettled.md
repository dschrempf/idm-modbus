# The unit of the PV surplus at 74 is unsettled

## The question

74, `Aktueller PV-Überschuss` (`FLOAT`, `RW/RO`, volatile), is printed in kW
by 812170 and 812184 rev. 13. `N2_GLTMON` prints it as `Überschuss (kW)`.
Community integrations (the evcc discussions) write watts (`doc/research.md`,
"The unit of address 74"). Every source that states a unit says kW, so the
table's kW stands. But nothing has
shown which unit the controller acts on, and a consumer that writes the
surplus will act on the answer.

## Why it can't be read off

On this machine 74 reads 0.0, and the PV signal setting `SSYSPVSIGNAL`
(setting 5335 / 13223, `N2_PV_SIGNAL`) is `N2_NONE`
(`captures/navigator-2.0-webapi-2026-10-01-1158.json`). Without a PV source
configured, the controller has no reason to look at 74. Looking at a stored
number shows only that it is stored, not how it is scaled.

## How we might solve it

This needs two writes, so it waits until writing exists or until you decide
on a one-off write outside the library:

1. Set `N2_PV_SIGNAL` to `N2_GLTSF` (key 5), the building management option.
   This is an EEPROM setting, so it costs one cycle. A consumer that feeds
   the surplus needs it set anyway.
2. Write 74 = 3.0. Read as kW, that is more than the machine draws, and the
   PV function should engage: watch the PV status and setpoint raises on the
   web backend. Read as W, it is nothing, and the PV function stays idle.
   74 is volatile, so the write costs no EEPROM cycle.
3. Write 74 = 0 again, and record the outcome in a dated `doc/`.

Once settled, the outcome belongs to the write interface's documentation of
74 as well as to `doc/research.md`.
