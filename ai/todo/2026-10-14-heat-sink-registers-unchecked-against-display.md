# Heat sink registers unchecked against the display

1068, 1070 and 1072 are named after the heat sink's return, flow and flow rate
on the controller's register page, and answer. Whether they are B124, B125 and
B2 needs a web reading and a register reading at the same minute: an
`idm-dump --watch` beside an `idm-web --watch` of `N2_SENSORS` (4768) while the
machine runs. 4768 needs Fachmann level, which means entering it, so it is
Dominik's call. If they match, `doc/verification-2026-09-20.md`'s claim that
no flow, return or flow rate is on Modbus falls entirely, and a coefficient of
performance becomes possible.
