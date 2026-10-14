# 1449 is not the maximum flow temperature

Moving that setting to 42, 43 and 44 on circuits A, C and D changed no register
at all. The conclusion rests on the change having taken while it was made,
which was never confirmed on the display.

Redoing it means writing a setting, so it is a decision for Dominik, not
something to run unasked. The web backend can now confirm the other half
cheaply: `tools/webprobe.py` reads the settings tree, so a capture before and
after the change says whether the controller took it, without trusting the
display.

Settled on 2026-10-14 without writing anything. The controller's own register
page, `N2_GLTMON`, puts `Maximale Vorlauftemperatur Heizen` at 1534, 1538 and
1540 and leaves 1449 off, and the settings tree names the setting `HSA04`
where 1449 is `HKA03`. A scan read 45.0 at all three. The rows are in the
table now, with the source `gltmon`; `doc/verification-2026-10-14-gltmon.md`
holds the measurements.
