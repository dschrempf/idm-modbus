# Captures

What the house's machine answered, kept here and out of git. A document in
`doc/` cites a capture by its name here, and `tools/transcribe.py` takes a
scan to fill the register table's `observed` column, and a webapi capture with
a widths capture to add the registers the controller's own list names.

The kind of capture is in the name:

    navigator-2.0-scan-SOFTWARE-YYYY-MM-DD-HHMM.json       idm-dump HOST --json
    navigator-2.0-watch-SOFTWARE-YYYY-MM-DD-HHMM.jsonl     idm-dump HOST --watch SECONDS ADDRESS...
    navigator-2.0-widths-SOFTWARE-YYYY-MM-DD-HHMM.json     idm-dump HOST --widths ADDRESS...
    navigator-2.0-webapi-SOFTWARE-YYYY-MM-DD-HHMM.json     tools/webprobe.py HOST
    navigator-2.0-webwatch-SOFTWARE-YYYY-MM-DD-HHMM.jsonl  idm-web HOST --watch SECONDS SETTING...
    navigator-2.0-webui-SOFTWARE-YYYY-MM-DD-HHMM/          curl, below
    navigator-2.0-level-SOFTWARE-YYYY-MM-DD-HHMM.log       idm-web HOST --leave-fachmann, --enter-fachmann
    navigator-2.0-show-SOFTWARE-YYYY-MM-DD-HHMM.txt        idm-web HOST --show SETTING...
    navigator-2.0-write-SOFTWARE-YYYY-MM-DD-HHMM.log       idm-write HOST ADDRESS VALUE, or tools/drivepv.py

The time is the local minute the capture started. `SOFTWARE` is the
controller's software as `doc/software-versions.md` spells it, `20.24-2608`.
The captures from before captures recorded their software were named after
the fact, by the controller's log: `20.24-1574` before the restart of
2026-11-05 at 16:09, `20.24-2608` after it.

A capture also records the software as its session read it. A scan or a
widths capture is an object, `software` beside `entries`, the list of reads;
its `software` is like a read, `status` and `exception`, with `major`,
`minor` and `patch` where registers 522, 524 and 526 answered. A webapi
capture is likewise `software` beside `entries`, and its `software` is the
string `N2_SYSTEM_INFO` prints, or an object with the `error` that kept it
from being read. Each line of a watch and a webwatch carries the `software`
of the session it was read on, null where there was none. What `idm-web`
prints, and so a level log or a show, starts with a `software` line. A
capture from before is a bare list and records none.

No capture holds the myiDM identifier, which names the machine. A read that
takes in a register of it, 500 or 501, records `"<redacted>"` for its `raw`
and its `value`, and a webapi capture has the same marker where a page
prints it.

The entries of a `webapi` capture are requests with the responses they drew.
It may hold only part of the walk, and it covers only what the user level
exposed; its first `status` response names that level.

A `watch` capture is a line per read, each a `scan` entry with a `time` field:
the local time, with its offset, at which the read was asked. A read that got
no answer, because the connection was lost or not yet made again, is a line
with status `error` all the same, so a gap in the series is in the file.

The entries of a `widths` capture are reads, three for each address given: the
address as one register, as two, and the address after it as one. An entry
carries `quantity` and no `value`, since no datatype is known to spell the
bytes as a number.

A `webwatch` capture is a line per request, each an entry of a `webapi`
capture — `request`, `captured`, `responses` — with the time to the
millisecond and an `error`, null unless nothing came back.

A `level` log is what `idm-web` printed when it changed the user level
during a watch, each change after the laptop's time. It says which stretch of
a `webwatch` capture was asked at which level.

A `show` capture is what `idm-web --show` printed, after the laptop's
time: the settings as they stood before, during and after an experiment that
changed them.

A `write` log is what `idm-write` printed, a line per write, each after the
laptop's time.

A `webui` capture is a directory of the web interface's own files, as the
controller serves them over HTTP on port 80, each at its path on the server
and beside a `.headers` file with the response headers it came with. It holds
only the files a document cites. `index.html` names the script it loads:

    for p in index.html main-LF3VJISP.js assets/translations/{de,en}.json; do
      curl -sS -D "DIR/$p.headers" -o "DIR/$p" "http://HOST/$p"
    done
