# Documentation

What is known about the iDM Navigator 10 and its two channels, Modbus TCP and
the web backend, and from where. Each document states the current
knowledge on its topic and cites the measurement behind each claim; what is
still open closes it.

| Document                                     | What it covers                                                               |
| -------------------------------------------- | ---------------------------------------------------------------------------- |
| [sources.md](sources.md)                     | the manufacturer's documents, the controller's register list, community work |
| [modbus.md](modbus.md)                       | the wire: word order, sentinels, signedness, enumerations, writes, a restart |
| [registers.md](registers.md)                 | what single registers hold, where it differs from the manual                 |
| [web-backend.md](web-backend.md)             | the websocket: protocol, user level, request reason, graphs                  |
| [heat-pump.md](heat-pump.md)                 | the machine: speeds and draws, starts, hot water, defrost, frost protection  |
| [pv-control.md](pv-control.md)               | the PV control: 74, 88 and 4108, what starts, steers and stops a run         |
| [software-versions.md](software-versions.md) | the controller's software by date, and what each update changed              |

## Measurements

`verification/` holds the measurements, one per file, named by date and
finding, `verification/DATE-SLUG.md`; the title states the result. Each
records what was set, what was captured and how to reproduce it. A
measurement a later one corrects carries a note pointing there; the topic
documents carry the current state. The first three,
[2026-09-19](verification/2026-09-19.md), [2026-09-20](verification/2026-09-20.md)
and [2026-09-20-webapi](verification/2026-09-20-webapi.md), checked the table
against the machine, its display and its web backend. The captures they cite
are in `captures/`, which git ignores; `captures/README.md` names the files.
