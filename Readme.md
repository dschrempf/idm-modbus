# idm-modbus

A Haskell library and command-line tools for iDM heat pumps with the
Navigator 10 controller, over Modbus TCP and over the controller's web
interface.

Most existing projects for these heat pumps guess at the register layout, and
say so; `doc/research.md` goes through them. This one takes its register table
from the manufacturer's parameter list, fills the gaps from the list of
registers the controller itself reports, and has checked every entry against a
running machine.

iDM printed that parameter list in the Navigator 10's Modbus manual,
document 812663 ("Modbus TCP Navigator 10"), for an older software, 20.23.
The machine serves that register map, with some additions and differences
that we measured and that the table records. The manual of the previous
controller, the Navigator 2.0, document 812170, prints the same list, with
three more rooms per zone module. The Navigator 10's firmware string,
`T_NAV10_20.24-…`, continues the Navigator 2.0's `20.x` version numbers.
Nobody has tried the library on a Navigator 2.0 yet.

Some registers are stored in an EEPROM, which wears out with every write.
`Persistence` in `IDM.Navigator.Register` tells you which ones. For that
reason a write goes to a `Target` whose type includes the cost of the write,
and only the few registers listed in `data/navigator-10-targets.tsv` can be
written at all.

## Status

The project is at an early stage. The table describes controller software
20.24-2608 and has 612 registers: 582 from revision 0 of 812663 and 30 from
the controller's register page `N2_GLTMON`. Every address in it has been read
on the machine. Reading works, both over Modbus and over the web backend.
Writing is supported for three targets, each tried on the machine:

- `PvSurplus` (74): the controller reads the value in kW and adds the heat
  pump's own draw back on top. Writing 0 therefore keeps a running charge
  going, and a negative value ends it.
- `PvTarget` (88): writes are accepted and read back, but none of the values
  tried so far had any effect on a PV run.
- `HeatPumpPowerLimit` (4108): a limit above the draw of the start program
  caps a PV run, and a limit below it ends the run. The value is lost when the
  controller restarts.

`doc/pv-control.md` collects what we know about the controller's PV control
and what is still open.

## Usage

    nix develop
    cabal build
    cabal run idm-dump -- HOST

`idm-dump` reads every register that the reference machine answered for, and
prints the address, access rights, EEPROM marking, value, unit and name of
each. Options:

- `--all` scans the whole parameter list instead. Use it to find out what
  your machine has installed.
- `--json` scans every address, including write-only ones, and prints the
  capture format of `captures/navigator-10-scan-*.json`: address, status,
  exception code, raw bytes, and the number those bytes encode, without
  further interpretation.
- `--watch SECONDS ADDRESS...` reads the given addresses every `SECONDS`
  seconds until you stop it, and prints one line per read in the same format,
  with a local timestamp.
- `--widths ADDRESS...` measures how many registers the value at each address
  takes up.

`idm-web` talks to the controller's web backend, the websocket its web
interface uses. It needs the web interface's PIN in `IDM_PIN`. Options:

- `--status` prints the user level, the controller's clock and any active
  notices.
- `--show SETTING...` reads settings by their ID in the settings tree. For
  example, 4768 holds the sensor values the web interface lists, including
  the refrigerant side, which Modbus does not expose.
- `--watch SECONDS SETTING...` polls the given settings repeatedly and prints
  one line per request. The answers are printed as received, except that
  anything identifying the machine is redacted.
- `--enter-fachmann` switches to the Fachmann (installer) level, using the
  code derived from the controller's clock. `--leave-fachmann` switches back.

`idm-write HOST ADDRESS VALUE` writes a value to one of the targets in
`data/navigator-10-targets.tsv` and reads it back. It refuses a target stored
in the EEPROM unless you pass `--eeprom`, and without that flag does not even
read it. With the flag, it reads the current value first and writes nothing
if it already matches. A confirmed write only means that the register holds
the new value, not that the controller acts on it.

Three of the scripts in `tools/` are for taking measurements, not for
everyday use:

- `tools/webprobe.py` records what the web backend answers. It only sends
  read requests.
- `tools/drivepv.py` writes a schedule, fixed before the run, to 74, 88 and
  4108 through `idm-write`, while `idm-dump --watch` runs alongside.
- `tools/runtable.py` lines up what was written with what the controller did.

All of these programs read the controller's software version first. Writes
and changes of the user level only go ahead if it matches the version the
table describes, in `data/navigator-10-software.tsv`. Reads work on any
version but warn if it differs, and every capture records the version.

Before you can connect, you need to switch Modbus TCP on in the controller: in
the service level, go to "Gebäudeleittechnik" and set "Modbus TCP" to "Ein".
The service code is today's day and month. The controller then answers on
port 502 with unit id 1.

## Layout

|                                           |                                                                                                                                                    |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `data/navigator-10-registers.tsv`         | the parameter list and the controller's register page, transcribed; the single source of truth                                                     |
| `data/navigator-10-enums.tsv`             | enumerated values, exactly as printed in the manual                                                                                                |
| `data/navigator-10-gltmon-parameters.tsv` | manufacturer's parameter IDs for registers the manual does not list, found by changing a setting and watching which register follows; hand-written |
| `data/navigator-10-targets.tsv`           | the registers that may be written, each with an English name; hand-written                                                                         |
| `data/navigator-10-software.tsv`          | the controller software the table describes, the only one writes are allowed on; hand-written                                                      |
| `data/navigator-10-web-2026-09-20.tsv`    | what the controller's web pages showed, copied from the screen by hand                                                                             |
| `captures/`                               | raw answers from a real machine, apart from what the parameter list already says; not in git; `captures/README.md` explains the files              |
| `tools/transcribe.py`                     | regenerates both TSVs and the targets module from the manual's PDF                                                                                 |
| `tools/webprobe.py`                       | records the web backend's answers, using reads only                                                                                                |
| `tools/drivepv.py`, `tools/runtable.py`   | write a fixed schedule to the PV targets, and line it up with what the controller did                                                              |
| `core/IDM/Modbus/TCP/Internal.hs`         | Modbus framing; `core/IDM/Modbus/TCP.hs` is the part a consumer can use, which can neither connect nor write                                       |
| `core/IDM/Navigator/Register.hs`          | the types that describe a register, and decoding                                                                                                   |
| `src/IDM/Navigator/Table.hs`              | the register table, parsed at compile time                                                                                                         |
| `src/IDM/Navigator/Software.hs`           | the controller's software version, as the table states it and as a session reads it                                                                |
| `src/IDM/Navigator/Client.hs`             | sessions and paced reads                                                                                                                           |
| `src/IDM/Navigator/Target.hs`             | the write targets; generated                                                                                                                       |
| `src/IDM/Navigator/Write.hs`              | writing, with the cost in the type                                                                                                                 |
| `core/IDM/Navigator/Write/Core.hs`        | what a write sends and what it results in, for any register; private to the package                                                                |
| `src/IDM/Navigator/Web.hs`, `Web/`        | the web backend: its protocol, a read-only session, and the user level                                                                             |
| `doc/research.md`                         | sources, community projects, open questions                                                                                                        |
| `doc/software-versions.md`                | the controller's software versions by date, and what each update changed                                                                           |
| `doc/pv-control.md`                       | the controller's PV control: what the sources say, and how to observe it                                                                           |
| `doc/verification-*.md`                   | one measurement each, dated; the title states the result                                                                                           |

To correct the table, put a newer revision of the manual in `manual/` and
re-run `tools/transcribe.py`. Git ignores `manual/`, since the document
belongs to the manufacturer. The script generates the two TSVs and
`src/IDM/Navigator/Target.hs`. Don't edit those by hand, or the next revision
of the manual can no longer be applied cleanly.

## Protocol quirks

- **32-bit floats arrive low word first.** This is the opposite of the usual
  Modbus convention, and the most common bug in community configurations.
- **A sensor that is not installed returns a placeholder instead of an
  error**: `-1.0` for a `FLOAT`, `-1` for a `UCHAR` (which arrives as a full,
  signed register), and `65535` for a `WORD`. The library returns `NoValue`
  for these, so a -1 does not end up in your temperature data. Where the
  placeholder could also be a real reading, such as -1 °C outdoors, it returns
  `NoValueOr` instead.
- **The Navigator stalls if you poll it too often.** Requests are spaced out
  by default.

## Home automation

Nothing uses this library yet. There are two options: a standalone daemon
built on the library, which is more likely, or an MQTT bridge to Home
Assistant using its discovery protocol, which is how most non-Python
integrations do it. Either would be a separate consumer of this package, and
the decisions about what the heat pump should do would be made there, not
here.

## No warranty

This software comes with **no warranty of any kind**. The authors take no
responsibility for what it does to your heat pump, your house, or anything
else; you use it at your own risk. It talks to the controller through
interfaces that the manufacturer documents only partly or not at all, it
writes registers that start and stop the compressor, and it can change the
controller's user level, which unlocks settings not meant for owners. If your
heat pump stops heating, breaks, or loses its warranty, that is your
responsibility, not ours.

## License

BSD-3-Clause.

Not affiliated with, endorsed by, or connected to iDM Energiesysteme GmbH. The
manufacturer's documents belong to them and are not redistributed here.
