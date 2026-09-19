# idm-modbus

Modbus TCP for iDM heat pumps with Navigator 2.0 control, in Haskell.

The point of this library is not that it talks Modbus — plenty of things do.
The point is that its register table is a transcription of the manufacturer's
own parameter list, and that every claim in it has been checked against a
running machine. Existing projects in this space are frank about guessing;
`doc/research.md` says which parts and why.

Reading only, for now. A third of the writable registers are stored in an
EEPROM the manufacturer rates at 300000 cycles, and that deserves an interface
that makes the cost visible rather than a boolean argument.

## Status

Early. The table is complete and verified, the read path works, writing is not
implemented.

## Use

    nix develop
    cabal build
    cabal run idm-dump -- 192.168.0.200

`idm-dump` reads every register that a reference machine answered for and
prints address, access right, EEPROM marking, value, unit and name. With
`--all` it sweeps the entire parameter list instead, which is how you find out
what your own machine has fitted.

Before anything will answer, Modbus TCP has to be switched on in the
controller: service level, "Gebäudeleittechnik", "Modbus TCP" to "Ein". The
service code is the day and month of the current date. Port 502, unit id 1.

## Layout

| | |
|---|---|
| `data/navigator-2.0-registers.tsv` | the parameter list, transcribed; the single source of truth |
| `data/navigator-2.0-enums.tsv` | enumerated values, as literally printed in the manual |
| `data/navigator-2.0-scan-*.json` | what a real machine answered, unedited |
| `tools/transcribe.py` | rebuilds both TSVs from the manual's extracted text |
| `src/IDM/Modbus/TCP.hs` | framing |
| `src/IDM/Navigator/Register.hs` | what a register is, and how to decode one |
| `src/IDM/Navigator/Table.hs` | the table, embedded at compile time |
| `src/IDM/Navigator/Client.hs` | reading, paced |
| `doc/research.md` | sources, community projects, open questions |
| `doc/verification-2026-09-19.md` | the measurements the decoding rests on |

Correcting the table means re-running `tools/transcribe.py` against a newer
revision of the manual, which goes in `manual/`, ignored by git because the
document is the manufacturer's. Nothing is generated into `src/`, and the TSVs
should not be edited by hand — that would make the next revision impossible to
apply cleanly.

## Three things that bite

- **A 32-bit float arrives low word first.** Against the usual Modbus habit,
  and the most common bug in community configurations.
- **An unfitted sensor answers with a sentinel, not an error**: `-1.0`,
  `255` or `65535` depending on datatype. This library returns `NotFitted`
  rather than letting a -1 into your temperature series.
- **The Navigator stalls when polled hard.** Requests are paced by default.

## Home Assistant

Not yet connected. The intended route is an MQTT bridge using Home Assistant's
discovery protocol, which is what the rest of the non-Python ecosystem does.

## Licence

BSD-3-Clause.

Not affiliated with, endorsed by, or connected to iDM Energiesysteme GmbH. The
manufacturer's documents are theirs and are not redistributed here.
