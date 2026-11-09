# idm-modbus

Modbus TCP for iDM heat pumps with Navigator 2.0 control, in Haskell.

The point of this library is not that it talks Modbus — plenty of things do.
The point is that its register table is a transcription of the manufacturer's
own parameter list, completed from the controller's own list of the registers
it serves, and that every claim in it has been checked against a running
machine. Existing projects in this space are frank about guessing;
`doc/research.md` says which parts and why.

Writing some registers wears out an EEPROM — a register's `Persistence`, in
`IDM.Navigator.Register`, says whether — so a write goes to a `Target` whose
type states its cost, and only to the few targets listed in
`data/navigator-2.0-targets.tsv`.

## Status

Early. The table describes controller software 20.24-2608: 722 registers, 692
from revision 12 of the parameter list, document 812170, and 30 from the
controller's register page `N2_GLTMON`; every address in it was read on the
machine. The read path works, over Modbus and over the web backend. Writing
exists for three targets, each tried on the machine:

- `PvSurplus`, 74: the controller reads it in kW and adds its own draw back,
  so 0 keeps a running charge running and a negative value ends it.
- `PvTarget`, 88: written and read back, but no value tried so far moved a PV
  run.
- `HeatPumpPowerLimit`, 4108: a limit above the draw of the start program
  caps a PV run; one below the draw ends it. It does not survive a restart.

`doc/pv-control.md` collects what is known about the controller's PV control
and what is still open.

## Use

    nix develop
    cabal build
    cabal run idm-dump -- HOST

`idm-dump` reads every register that a reference machine answered for and
prints address, access right, EEPROM marking, value, unit and name. With
`--all` it sweeps the entire parameter list instead, which is how you find out
what your own machine has fitted. With `--json` it sweeps every address,
write-only ones included, and writes the capture format of
`captures/navigator-2.0-scan-*.json`: address, status, exception code, bytes,
and the number those bytes spell, uninterpreted. With
`--watch SECONDS ADDRESS...` it reads the given addresses every so many
seconds until interrupted, and writes a line per read in the same format,
stamped with the local time. With `--widths ADDRESS...` it measures how many registers wide the
value at each address is.

`idm-web` reads the controller's web backend, the websocket its own web
interface uses, with the web interface's PIN in `IDM_PIN`. `--status` prints
the user level, the controller's clock and the notices standing;
`--show SETTING...` reads settings by the id of the settings tree, e.g. 4768
for the sensor values the web interface lists, among them the refrigerant side
that Modbus does not carry. `--watch SECONDS SETTING...` asks them round after
round and writes a line per request, verbatim but for what names the machine.
`--enter-fachmann` opens the Fachmann level with the code of the controller's
clock, and `--leave-fachmann` closes it again.

`idm-write HOST ADDRESS VALUE` writes a target, one of the addresses in
`data/navigator-2.0-targets.tsv`, and reads it back. A target stored in the
EEPROM is not touched without `--eeprom`, not even read; with it, it is read
first and left alone if it holds the value already. A confirmed write says the
register holds the value, not that the controller acts on it.

Three scripts in `tools/` serve measurements rather than use.
`tools/webprobe.py` captures what the web backend answers, sending only its
reads. `tools/drivepv.py` writes a schedule fixed before the run to 74, 88 and
4108 through `idm-write`, beside a running `idm-dump --watch`;
`tools/runtable.py` lines up what was written with what the controller did.

Each of them first reads the controller's software. A write, and a change of
the user level, goes ahead only on the software the table describes,
`data/navigator-2.0-software.tsv`; a read goes ahead on any, warns where it
differs, and every capture records it.

Before anything will answer, Modbus TCP has to be switched on in the
controller: service level, "Gebäudeleittechnik", "Modbus TCP" to "Ein". The
service code is the day and month of the current date. Port 502, unit id 1.

## Layout

| | |
|---|---|
| `data/navigator-2.0-registers.tsv` | the parameter list and the controller's register page, transcribed; the single source of truth |
| `data/navigator-2.0-enums.tsv` | enumerated values, as literally printed in the manual |
| `data/navigator-2.0-gltmon-parameters.tsv` | the parameter identifier of a register the manual does not list, where a moved setting showed it; written by hand |
| `data/navigator-2.0-targets.tsv` | the registers a write may go to, with an English name each; written by hand |
| `data/navigator-2.0-software.tsv` | the controller software the table describes, the only one a write goes to; written by hand |
| `data/navigator-2.0-web-2026-09-20.tsv` | what the controller's web pages showed, read off the screen; written by hand |
| `captures/` | what a real machine answered, and nothing the list already says; kept out of git; `captures/README.md` names the files |
| `tools/transcribe.py` | rebuilds both TSVs from the manual's PDF, and the targets module |
| `tools/webprobe.py` | captures the web backend's answers, reads only |
| `tools/drivepv.py`, `tools/runtable.py` | write a fixed schedule to the PV targets, and line it up with what the controller did |
| `core/IDM/Modbus/TCP/Internal.hs` | framing; `core/IDM/Modbus/TCP.hs` is the part a consumer may reach, neither connecting nor writing |
| `core/IDM/Navigator/Register.hs` | what a register is, and how to decode one |
| `src/IDM/Navigator/Table.hs` | the table, parsed at compile time |
| `src/IDM/Navigator/Software.hs` | the controller's software, as the table states it and as a session reads it |
| `src/IDM/Navigator/Client.hs` | a session, and reading, paced |
| `src/IDM/Navigator/Target.hs` | the targets of a write, generated |
| `src/IDM/Navigator/Write.hs` | writing, at a cost the type states |
| `core/IDM/Navigator/Write/Core.hs` | what a write sends and comes to, for any register; private to the package |
| `src/IDM/Navigator/Web.hs`, `Web/` | the web backend: its vocabulary, a read-only session, and the user level |
| `doc/research.md` | sources, community projects, open questions |
| `doc/software-versions.md` | the controller's software by date, and what an update changed |
| `doc/pv-control.md` | the controller's PV control: what the sources say, and how to watch it |
| `doc/verification-*.md` | one measurement each, dated; its title states what it found |

Correcting the table means re-running `tools/transcribe.py` against a newer
revision of the manual, which goes in `manual/`, ignored by git because the
document is the manufacturer's. The script writes the two TSVs and
`src/IDM/Navigator/Target.hs`, and none of them should be edited by hand —
that would make the next revision impossible to apply cleanly.

## Three things that bite

- **A 32-bit float arrives low word first.** Against the usual Modbus habit,
  and the most common bug in community configurations.
- **An unfitted sensor answers with a sentinel, not an error**: `-1.0` for a
  `FLOAT`, `-1` for a `UCHAR`, which arrives as a whole signed register, and
  `65535` for a `WORD`. This library returns `NoValue` rather than letting a
  -1 into your temperature series, and `NoValueOr` where the sentinel is also
  a value the register may hold: -1 °C outdoors.
- **The Navigator stalls when polled hard.** Requests are paced by default.

## Home automation

Not yet connected to anything. Two routes are open: a daemon of its own,
built on this library, which is the likelier one, or an MQTT bridge to Home
Assistant using its discovery protocol, which is what the rest of the
non-Python ecosystem does. Either is a consumer of this package, and what it
decides the heat pump should do stays there.

## No warranty

This software comes with **no warranty of any kind**, and the authors take no
responsibility for what it does to your heat pump, your house, or anything
else. You use it entirely at your own risk. It talks to a controller through
interfaces the manufacturer documents only in part or not at all, it writes
registers that start and stop the compressor, and it can change the
controller's user level, which unlocks settings that are not meant for the
owner. If your heat pump stops heating, breaks, or loses its warranty,
that is on you, not on us.

## License

BSD-3-Clause.

Not affiliated with, endorsed by, or connected to iDM Energiesysteme GmbH. The
manufacturer's documents are theirs and are not redistributed here.
