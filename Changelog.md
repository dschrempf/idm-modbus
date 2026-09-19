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

### Fixed

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

- Writing. A third of the writable registers are stored in an EEPROM rated for
  300000 cycles, so writes need an interface that makes the cost visible rather
  than an extra argument on a read function.
- Enumerations for every member of a register family. The manual prints the
  encoding once, for heating circuit A, and leaves B to G implicit.
