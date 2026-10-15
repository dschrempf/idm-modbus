# Heat sink registers unchecked against the display

1068, 1070 and 1072 are named after the heat sink's return, flow and flow rate
on the controller's register page, and answer. Whether they are B124, B125 and
B2 needs a web reading and a register reading at the same minute: an
`idm-dump --watch` beside an `idm-web --watch` of `N2_SENSORS` (4768) while the
machine runs. 4768 needs Fachmann level, which means entering it, so it is
Dominik's call. If they match, `doc/verification-2026-09-20.md`'s claim that
no flow, return or flow rate is on Modbus falls entirely, and a coefficient of
performance becomes possible.

Done on 2026-10-15, at Fachmann level while the machine heated: 1068, 1070 and
1072 are B124, B125 and B2, within the display's rounding over 73 rounds, and
4126 is their product with the specific heat of water
(`doc/verification-2026-10-15-heat-sink.md`). 1074 read 93 to 97 where 1104
read "not driven"; what 1074's `ffff` at rest means stays open, in
`2026-10-15-charge-pump-signal-1074-unchecked-at-rest`.
