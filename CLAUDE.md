# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

    nix develop                        # toolchain: cabal, HLS, ormolu, cabal-fmt
    cabal build
    cabal test                         # prints one line per check
    cabal run idm-dump -- HOST         # read the registers a reference machine answered for
    cabal run idm-dump -- HOST --all   # sweep the whole parameter list
    cabal run idm-dump -- HOST --json > captures/navigator-2.0-scan-YYYY-MM-DD-HHMM.json
    tools/webprobe.py HOST PIN > captures/navigator-2.0-webapi-YYYY-MM-DD-HHMM.json
    ormolu -i $(git ls-files '*.hs')   # formatting
    cabal-fmt -i idm-modbus.cabal

The test suite is a list of `(name, Bool)` pairs in `test/Main.hs`; there is no
per-test selection, and a new invariant is a new entry in `checks`. It needs no
heat pump: everything is decoded from literal byte strings.

Reaching a real machine needs Modbus TCP switched on in the controller (service
level, "Gebäudeleittechnik", "Modbus TCP" to "Ein"; the service code is the day
and month of the current date). Port 502, unit id 1.

## Architecture

The register table is data, not code, and it flows one way:

    manual/812170.pdf → pdftotext -layout → tools/transcribe.py
      → data/navigator-2.0-{registers,enums}.tsv → embedFile → IDM.Navigator.Table

`tools/transcribe.py` is the only thing that may write those two TSVs — editing
them by hand makes the next revision of the manual impossible to apply cleanly.
`data/navigator-2.0-web-*.tsv` is a different kind of file and is written by
hand: what the controller's own web pages showed, at the minute they were read.
It carries no addresses, so the mapping it tests is stated only in the register
table; the join is on the sensor designator a register name already holds. It
also folds in `data/navigator-2.0-scan-*.json`, a capture of what one machine
answered, to fill the `observed` column. The capture holds no transcribed data
of its own — `idm-dump --json` writes it, and it records only address, status,
exception code, raw bytes and the uninterpreted number, so a correction to the
table cannot leave it saying something else. A defect in a register name,
unit or range is therefore a defect in the transcription script, not in the
Haskell parser.

`data/navigator-2.0-webapi-*.json` is the third kind: what the controller's web
interface answered, captured rather than transcribed. `tools/webprobe.py`
writes it over the websocket the web interface itself uses, sending only the
three read commands the controller's own JavaScript names, `overview`, `detail`
and `traverse` — the protocol's `save` and `execute` must stay out of that
script, and so must the two reads that open the relay test and ask for user
level 4. It is the stronger witness of the two web sources, because the
settings it walks name their value with the manufacturer's own parameter
identifier, the `FW030` and `BV002` of the parameter list, so the join to the
register table is on the identifier the table already carries. It is also the
only source that carries time: the graph it captures says when the machine ran,
which is what a rise in a counter has to be attributed to. The capture is
verbatim but for the code that opens the controller and the strings that name
the machine, which are replaced by a visible marker. What the capture contains
depends on the user level the controller is left at; the script never raises
it. At Fachmann level the settings tree also holds controls — the relay test, a
reboot, resets — so the walk asks `detail` only of the item types in
`VALUE_ITEMS` and never opens the menus in `CLOSED_MENUS`; a new item type
stays unasked until someone has looked at what it is.

New captures of either kind go to `captures/`, which git ignores because the
repository is public; `captures/README.md` names the files. A capture moves to
`data/` only when a document in `doc/` rests on it.

`manual/` holds the manufacturer's PDFs and is ignored by git; copy them in
from the house documents to re-run the transcription. The list is printed
inconsistently — the same column appears in a different order on different
pages — so cells are read by the column they are printed in, taken from the
page heading, not by the order they appear in.

The four modules stack, each refusing to know the next one's business:

- `IDM.Modbus.TCP` — framing and sockets for the two read function codes.
  Returns raw bytes in wire order and a `Failure` for anything else.
- `IDM.Navigator.Register` — the manual's vocabulary as types, plus `decode`.
  Every distinction the manual draws in prose or a footnote is a constructor,
  so a caller cannot silently ignore it.
- `IDM.Navigator.Table` — parses the embedded TSVs; exposes `navigator20`,
  `readable`, `present`, `enumLabel`.
- `IDM.Navigator.Client` — pacing, and pairing a read with its enum label.

Read support only. Writing is deliberately absent: a third of the writable
registers live in an EEPROM rated at 300000 cycles, and that needs an interface
that makes the cost visible rather than an extra argument.

## Things the wire does that surprise people

- A 32-bit float arrives **low word first**, against the usual Modbus habit.
- An unfitted sensor answers with a sentinel (`-1.0`, `255`, `65535`), not an
  exception; `decode` returns `NotFitted` so a -1 never enters a temperature
  series. A `WORD` is two's complement where the parameter list documents a
  negative minimum for it, and there 65535 is a value rather than a sentinel:
  the pump control signals at 1104 to 1109 read it as "not being driven".
- The Navigator stalls when polled hard, hence `pollIntervalMicroseconds`.

`doc/research.md` records the sources and the open questions;
`doc/verification-2026-09-19.md` records the measurements the decoding rests
on, `doc/verification-2026-09-20.md` what the controller's own display says
about the same registers, and `doc/verification-2026-09-20-webapi.md` what its
web backend says about the settings, joined on the manufacturer's parameter
identifier. Claims about the machine belong there, with the measurement that
supports them.

## Conventions

- Documents go straight into `doc/`, not into the AI directory's `doc/`. They
  are part of the project's argument for why the table can be trusted, so they
  are written and reviewed like source. Plans, TODOs and scratch notes still go
  to the AI directory.
- Haddock header on every module: name, description, copyright, license.
- German register names and the manufacturer's identifiers (`FLOAT`, `FW030`,
  `B32`) are quoted verbatim; prose is US English.
