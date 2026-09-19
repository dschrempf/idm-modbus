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

### Not yet

- Writing. A third of the writable registers are stored in an EEPROM rated for
  300000 cycles, so writes need an interface that makes the cost visible rather
  than an extra argument on a read function.
- Enumerations for every member of a register family. The manual prints the
  encoding once, for heating circuit A, and leaves B to G implicit.
