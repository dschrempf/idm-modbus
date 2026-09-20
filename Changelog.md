# Changelog

## Unreleased

### Added

- Modbus TCP framing for the two read function codes.
- The Navigator 2.0 parameter list of document 812170 revision 10, transcribed
  to `data/navigator-2.0-registers.tsv`, embedded at compile time.
- Decoding that distinguishes a measurement from the sentinel an unfitted
  sensor returns, and that reads a temperature-carrying `WORD` as signed.
- `idm-dump`, which reads every register and prints it.
- The research behind all of this, in `doc/`.
- The 166 registers the parameter list marks `RW/RO`, an access right chapter
  4.1 never defines and the transcription used to skip: the energy management
  block at 74 to 86 — PV surplus, house consumption, battery charge level —
  and every zone module room temperature and humidity. The table now has 663
  registers rather than 497. `Access` gained `Supplied` for the marking, read
  as "the building management system may supply this value, and may read it
  back". This settles address 86, which `doc/research.md` had listed as
  documented nowhere: it is `Batteriefüllstand`.
- `Drive`, what a pump's control signal says: `NotDriven`, or `Driven` so many
  per cent. The controller's scale runs from -1, and `Driven 0` — a pump at its
  minimum speed — is not a pump at rest.
- A second verification, `doc/verification-2026-09-20.md`, checking the table
  against the controller's own display rather than against the machine alone,
  with the readings in `data/navigator-2.0-web-2026-09-20.tsv` and the two
  captures taken beside them.

### Changed

- The sign of a `WORD` follows the minimum the parameter list documents for it,
  not its unit. Registers documented from a negative minimum — the bivalence
  points from -90, the pump control signals from -1 — are two's complement, and
  65535 is a value they may hold rather than a sentinel. This replaces the
  special case for degrees Celsius instead of adding a second one, and a
  bivalence point set to -1 °C is no longer swallowed.

- `data/navigator-2.0-scan-2026-09-19.json` is a fresh sweep of all 663
  addresses: 232 answered, 431 refused, every refusal `IllegalDataAddress` and
  every one of them in the zone module block or write-only. It reproduces the
  earlier sweep of the 497 addresses then known, sentinel for sentinel.
- The same file holds what the machine said and nothing else: address, status,
  the exception code behind a refusal, the bytes, and the number those bytes
  spell. It used to repeat the parameter list's own columns, transcribed a
  second time and wrong in 19 of them — the same defects as the table, plus a
  few of its own. `idm-dump --json` writes
  the format, so the capture is reproducible; `IDM.Navigator.Register.asWritten`
  reads bytes without applying the conventions the manual leaves out, which is
  what a capture must record if it is to be the evidence for them.

### Fixed

- Addresses 1104 to 1109 reported a fitted pump as absent. They are pump
  control signals documented from -1, so their 65535 means "not being driven",
  which the controller's display confirms for the charge pump M73 while showing
  it running. A pump nothing calls for and a pump never installed answer alike,
  and the library no longer pretends to tell them apart.
- `enumLabel` reached only the register the manual prints an enumeration
  beside, so the operating mode of heating circuits B to G, their active mode,
  and compressors 2 to 4 had no labels. `tools/transcribe.py` now shares an
  enumeration across the registers that differ only in the letter or digit
  ending their name and agree in everything else, and refuses to share where
  two of them carry enumerations of their own. Sixteen addresses became 45.
- `tools/transcribe.py` read the parameter list by the order of its cells,
  which the list does not keep. It now reads each cell by the column it is
  printed in. Sixty-six names were wrong — 59 cut short of their sensor
  designator, `Außentemperatur (B32)` down to `Außentemperatur (B3`, because a
  footnote marker is printed the same way, and 13 broken across two lines, so
  that addresses 1206, 1208 and 1210 all read `Kaskade / Gemittelte
  Vorlauftemperatur`. Twelve cascade registers lost their range and carried a
  number where the controller's parameter identifier belongs; nine more lost
  their unit.

### Not yet

- Writing. Eighty-eight registers are stored in an EEPROM rated for 300000
  cycles, so writes need an interface that makes the cost visible rather than
  an extra argument on a read function.
