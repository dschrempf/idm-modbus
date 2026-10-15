# The EEPROM count is stated four times

"Eighty-eight registers" in `Readme.md`, `Changelog.md` ("Not yet") and the
`IDM.Navigator.Client` header; "a third of the writable registers" in
`CLAUDE.md` (88 of 266 `RW`; of all writable, 88 of 448). Pick one home and
reference it from the others.

Fixed on 2026-10-15: no prose states the count any longer. Readme, Changelog,
`IDM.Navigator.Client` and `CLAUDE.md` point to a register's `Persistence`,
and the table is the one source of which registers wear the EEPROM. The
count was already short: the 12 `RW` `gltmon` rows are `UnknownPersistence`,
which a writer must take for EEPROM. The 300000 cycles stay in
`Persistence`'s haddock and in `doc/research.md`, which cites the manual.
