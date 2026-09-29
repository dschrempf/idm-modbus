# idm-modbus

Modbus TCP for iDM heat pumps with Navigator 2.0 control, in Haskell.

The point of this library is not that it talks Modbus — plenty of things do.
The point is that its register table is a transcription of the manufacturer's
own parameter list, and that every claim in it has been checked against a
running machine. Existing projects in this space are frank about guessing;
`doc/research.md` says which parts and why.

Reading only, for now. Eighty-eight registers are stored in an EEPROM the
manufacturer rates at 300000 cycles, and that deserves an interface
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
what your own machine has fitted. With `--json` it sweeps every address,
write-only ones included, and writes the capture format of
`captures/navigator-2.0-scan-*.json`: address, status, exception code, bytes,
and the number those bytes spell, uninterpreted. With `--watch SECONDS
ADDRESS...` it reads the given addresses every so many seconds until
interrupted, and writes a line per read in the same format, stamped with the
local time.

`idm-web` reads the controller's web backend, the websocket its own web
interface uses, with the web interface's PIN in `IDM_PIN`. `--status` prints
the user level, the controller's clock and the notices standing; `--show
SETTING...` reads settings by the id of the settings tree, e.g. 4768 for the
sensor values the web interface lists, among them the refrigerant side that
Modbus does not carry. `--watch SECONDS SETTING...` asks them round after
round and writes a line per request, verbatim but for what names the machine.
`--enter-fachmann` opens the Fachmann level with the code of the controller's
clock, and `--leave-fachmann` closes it again.

Before anything will answer, Modbus TCP has to be switched on in the
controller: service level, "Gebäudeleittechnik", "Modbus TCP" to "Ein". The
service code is the day and month of the current date. Port 502, unit id 1.

## Layout

| | |
|---|---|
| `data/navigator-2.0-registers.tsv` | the parameter list, transcribed; the single source of truth |
| `data/navigator-2.0-enums.tsv` | enumerated values, as literally printed in the manual |
| `captures/` | what a real machine answered, and nothing the list already says; kept out of git |
| `tools/transcribe.py` | rebuilds both TSVs from the manual's extracted text |
| `src/IDM/Modbus/TCP.hs` | framing |
| `src/IDM/Navigator/Register.hs` | what a register is, and how to decode one |
| `src/IDM/Navigator/Table.hs` | the table, embedded at compile time |
| `src/IDM/Navigator/Client.hs` | reading, paced |
| `src/IDM/Navigator/Web.hs`, `Web/` | the web backend: its vocabulary, a read-only session, and the user level |
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

## No warranty

This software comes with **no warranty of any kind**, and the authors take no
responsibility for what it does to your heat pump, your house, or anything
else. You use it entirely at your own risk. It talks to a controller through
interfaces the manufacturer documents only in part or not at all, and it can
change the controller's user level, which unlocks settings that are not meant
for the owner. If your heat pump stops heating, breaks, or loses its warranty,
that is on you, not on us.

## Licence

BSD-3-Clause.

Not affiliated with, endorsed by, or connected to iDM Energiesysteme GmbH. The
manufacturer's documents are theirs and are not redistributed here.
