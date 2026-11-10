# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

    nix develop                        # toolchain: cabal, HLS, ormolu, cabal-fmt, pdftotext
    cabal build
    cabal test                         # prints one line per check
    cabal run idm-dump -- HOST         # read the registers a reference machine answered for
    cabal run idm-dump -- HOST --all   # sweep the whole parameter list
    cabal run idm-dump -- HOST --json > captures/navigator-10-scan-SOFTWARE-YYYY-MM-DD-HHMM.json
    cabal run idm-dump -- HOST --watch 10 1066 1012 > captures/navigator-10-watch-SOFTWARE-YYYY-MM-DD-HHMM.jsonl
    cabal run idm-dump -- HOST --widths 1534 1074 > captures/navigator-10-widths-SOFTWARE-YYYY-MM-DD-HHMM.json
    tools/transcribe.py manual/812663-rev0.pdf --scan SCAN [--webapi WEBAPI --widths WIDTHS]
    IDM_PIN=... tools/webprobe.py HOST > captures/navigator-10-webapi-SOFTWARE-YYYY-MM-DD-HHMM.json
    IDM_PIN=... cabal run idm-web -- HOST --status      # user level, clock, notices
    IDM_PIN=... cabal run idm-web -- HOST --show 4768   # a setting, read for a person
    IDM_PIN=... cabal run idm-web -- HOST --watch 10 4768 5888 > captures/navigator-10-webwatch-SOFTWARE-YYYY-MM-DD-HHMM.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann   # and --leave-fachmann
    cabal run idm-write -- HOST 74 3.0               # a target; --eeprom where it costs a cycle
    tools/drivepv.py HOST WATCH --final -0.5 2.0-4122/20/ein+720/0 2.0-4122/20/ein+1140/1.0 > captures/navigator-10-write-SOFTWARE-YYYY-MM-DD-HHMM.log
    tools/runtable.py WATCH --web WEBWATCH --writes WRITELOG   # a run lined up by time; --last for a status line
    ormolu -i $(git ls-files '*.hs' ':!src/IDM/Navigator/Target.hs')   # formatting; transcribe.py writes Target.hs
    cabal-fmt -i idm-modbus.cabal

The test suite is a list of `(name, Bool)` pairs in `test/Main.hs`; there is no
per-test selection, and a new invariant is a new entry in `checks`. It needs no
heat pump: everything is decoded from literal byte strings.

Reaching a real machine needs Modbus TCP switched on in the controller (service
level, "Gebäudeleittechnik", "Modbus TCP" to "Ein"; the service code is the day
and month of the current date). Port 502, unit id 1.

## Architecture

The machine is a Navigator 10, and the table is transcribed from 812663,
its Modbus manual, for software 20.23. 812170, the Navigator 2.0's manual,
prints the same parameter list but for the zone modules' rooms 7 to 9;
`doc/sources.md` says how the two differ and why the controller is the
Navigator 10.

The register table is data, not code, and it flows one way:

    manual/812663-rev0.pdf → pdftotext -layout and -bbox → tools/transcribe.py
      → data/navigator-10-{registers,enums}.tsv → splice → IDM.Navigator.Table
      → src/IDM/Navigator/Target.hs (with data/navigator-10-targets.tsv)

`tools/transcribe.py` is the only thing that may write those two TSVs and
`IDM.Navigator.Target` — editing them by hand makes the next revision of the
manual impossible to apply cleanly. A defect in a register name, unit or
range is a defect in that script, not in the Haskell parser. The hand-written
inputs are `data/navigator-10-targets.tsv`, the registers a write may go
to, `data/navigator-10-gltmon-parameters.tsv`,
`data/navigator-10-measured-enums.tsv`, the codes measured beside the
manual's, and `data/navigator-10-software.tsv`. Listing a target goes with trying on the
machine that a write to it takes effect. Note `table-transcription`: what the
script reads, refuses and writes; read it before running or changing it, or
adding a target.

The table describes one software of the controller,
`data/navigator-10-software.tsv`. A write and a change of the user level go
ahead only on it, a read on any. Every session reads the software when it
opens and when it reconnects, and every capture records it;
`doc/software-versions.md` says where each channel reads it.

What the machine answered lives in `captures/`, which git ignores because the
repository is public; `captures/README.md` names the files, and a document in
`doc/` cites a capture by its path there. No capture holds what names the
machine: the myiDM identifier, `myIdmAddress`, and the strings a web page
prints for it are redacted. `manual/` holds every manufacturer's document
the repository cites, so that it needs no other copy, and is ignored by git
too, as is `community/`, clones of the projects the
"Community work" of `doc/sources.md` names. They are evidence to weigh,
not code to run, and a document cites one by its upstream name, not by
its path there.

The web backend is a second channel. `tools/webprobe.py` and
`IDM.Navigator.Web` send only its reads, `overview`, `detail` and `traverse`:
`save` and `execute` stay out of them, but for the two writes of
`IDM.Navigator.Web.Level`. Note `web-backend-and-captures`: what its captures
are evidence for, which `detail` requests the probe may send at Fachmann
level, and how the user level behaves; read it before changing either or
reading a web capture as evidence.

The modules stack, each refusing to know the next one's business:

- `IDM.Modbus.TCP.Internal` — framing and sockets for the two read function
  codes and the two write ones, 6 and 16. Returns raw bytes in wire order and
  a `Failure` for anything else. A request that leaves the stream out of
  step — no answer in time, an answer to another request — ends the
  connection, and later requests fail unsent. `IDM.Modbus.TCP` is what a
  consumer may reach of it: neither connecting nor writing.
- `IDM.Navigator.Register` — the manual's vocabulary as types, plus `decode`
  and its inverse `encode`. Every distinction the manual draws in prose or a
  footnote is a constructor, so a caller cannot silently ignore it.
- `IDM.Navigator.Table` — parses the TSVs at compile time, so a row that does
  not parse fails the build; exposes `navigator10`, `readable`, `present`,
  `enumLabel`, `navigator10Software`, the software the table describes, and
  `myIdmAddress`, the register no capture holds.
- `IDM.Navigator.Software` — a version as the table states it and as each
  channel reads it, and whether the two agree.
- `IDM.Navigator.Client` — sessions, pacing, and pairing a read with its enum
  label. A `Session` reads the software when it opens; `writable` gives the
  `Writable` that `write` needs only on the software the table describes.
- `IDM.Navigator.Target` — generated: `Target (c :: Cost)`, a constructor per
  target, and `targetRegister`, total.
- `IDM.Navigator.Write` — `write`, whose `Outcome c` carries the cost. An
  EEPROM write reads first and sends nothing when the value is held already;
  a volatile one always sends. Both read back. The decision is `writeWith`
  in `IDM.Navigator.Write.Core`, over any register and any monad, so the
  test suite runs it against a fake controller in `State`. It lives with
  the framing and `IDM.Navigator.Register` in `core/`, the private
  sublibrary `core`, which the library re-exports but for that module and
  `IDM.Modbus.TCP.Internal`: a consumer reaches a register only through a
  target, and a connection only through a session.

The web backend has a stack of its own beside it, joined to the first only by
`Host` and by the parameter identifier:

- `IDM.Navigator.Web` — the protocol's vocabulary: `Query`, which has a
  constructor for each read and none for `save` or `execute`, and parsers that
  hand back an answer they do not recognize rather than read it as empty.
- `IDM.Navigator.Web.Connection` — the websocket; sends any JSON, so the
  package does not expose it.
- `IDM.Navigator.Web.Session` — sends a `Query` and nothing else. Reads the
  software when it opens, and gives the `Writable` the two writes of the
  level need.
- `IDM.Navigator.Web.Level` — the two writes: entering the Fachmann level,
  with a code spelled from the controller's clock, from Kunde only, and
  leaving it. The level is the controller's, not the connection's, and the
  controller ends it too, sixty minutes from the entry.

Writing some registers wears out an EEPROM (a register's `Persistence`), so
the cost is in the type of every target and every outcome rather than in an
extra argument, and `idm-write` refuses an EEPROM target without `--eeprom`.
A confirmed write says the register stored the value, not that the controller
acts on it; checking that is the consumer's concern.

The package is an interface to the controller and stays one: it reads, it
sets the user level, and it writes. Deciding what the heat pump should
do — from a PV surplus, a meter, a tariff, the household's appliances — belongs
to its consumers, and no such strategy goes in here, not even as an example. A
write of the surplus register 74, of its target 88, or of the power limit 4108
is interface; computing any of them is not.
A schedule fixed before a run, written to see how the controller responds,
is a measurement and not a strategy: `tools/drivepv.py` writes one, and
`tools/runtable.py` lines up what it wrote with what the controller did.

## Things the wire does that surprise people

- A 32-bit float arrives **low word first**, against the usual Modbus habit.
- An unfitted sensor answers with a sentinel (`-1.0` for a `FLOAT`,
  `-1` for a `UCHAR`, `65535` for a `WORD`), not an
  exception; `decode` returns `NoValue` so a -1 never enters a temperature
  series. A `FLOAT` whose documented range does not rule -1 out — most
  document none — decodes it to `NoValueOr`, since -1 °C is a temperature;
  the caller decides. A `WORD` is two's complement where the parameter list documents a
  negative minimum for it, or a negative default for a read-only one, and
  there 65535 is a value rather than a sentinel: the pump control signals at
  1074 and 1104 to 1109 read it as "not being driven".
- A `UCHAR` arrives as a whole register, `ffff` and not `00ff`, and the
  controller reads it as a signed word: it prints the `fffe` of 1714 and 1715
  as -2. At 1005 `ffff` is no sentinel but the operating mode "Aus", a code
  the manual does not print; its range, widened to -1, says so.
- The Navigator stalls when polled hard, hence `pollIntervalMicroseconds`.

`doc/` holds topic documents, each the current knowledge on its topic and
its open questions; `doc/README.md` lists them. `doc/verification/DATE-SLUG.md`
holds the measurements, one per file, its finding in its title; a topic
document cites one for every claim about the machine. A new measurement goes
into `doc/verification/`, and what it changes into the topic documents, so
that they never read as a log. `doc/software-versions.md` dates the
controller's software, so it says which software a measurement was made on.

## Conventions

- Documents go straight into `doc/`, not into the AI directory's `doc/`. They
  are part of the project's argument for why the table can be trusted, so they
  are written and reviewed like source. Plans, TODOs and scratch notes still go
  to the AI directory.
- A change a user or consumer can see — a target, a module's exports, an
  executable's arguments or output, a tool — goes into `Changelog.md` under
  "Unreleased", and into `Readme.md` where the README states what it changes:
  its status lists the targets and what the machine showed for each. A
  measurement that changes what a target does updates both.
- Haddock header on every module: name, description, copyright, license.
- German register names and the manufacturer's identifiers (`FLOAT`, `FW030`,
  `B32`) are quoted verbatim; prose is US English.
