# Captures

What the house's machine answered, kept here and out of git. A document in
`doc/` cites a capture by its name here, and `tools/transcribe.py` takes a
scan to fill the register table's `observed` column, and a webapi capture with
a widths capture to add the registers the controller's own list names.

The kind of capture is in the name:

    navigator-2.0-scan-YYYY-MM-DD-HHMM.json       idm-dump HOST --json
    navigator-2.0-watch-YYYY-MM-DD-HHMM.jsonl     idm-dump HOST --watch SECONDS ADDRESS...
    navigator-2.0-widths-YYYY-MM-DD-HHMM.json     idm-dump HOST --widths ADDRESS...
    navigator-2.0-webapi-YYYY-MM-DD-HHMM.json     tools/webprobe.py HOST
    navigator-2.0-webwatch-YYYY-MM-DD-HHMM.jsonl  idm-web HOST --watch SECONDS SETTING...
    navigator-2.0-webui-YYYY-MM-DD-HHMM/          curl, below
    navigator-2.0-level-YYYY-MM-DD-HHMM.log       idm-web HOST --leave-fachmann, --enter-fachmann

The time is the local minute the capture started. A `webapi` capture is a list
of requests with the responses they drew. It may hold only part of the walk,
and it covers only what the user level exposed; its first `status` response
names that level.

A `watch` capture is a line per read, each a `scan` entry with a `time` field:
the local time, with its offset, at which the read was asked. A read that got
no answer, because the connection was lost or not yet made again, is a line
with status `error` all the same, so a gap in the series is in the file.

A `widths` capture is a list of reads, three for each address given: the
address as one register, as two, and the address after it as one. An entry
carries `quantity` and no `value`, since no datatype is known to spell the
bytes as a number.

A `webwatch` capture is a line per request, each an entry of a `webapi`
capture — `request`, `captured`, `responses` — with the time to the
millisecond and an `error`, null unless nothing came back.

A `level` log is what `idm-web` printed when it changed the user level
during a watch, each change after the laptop's time. It says which stretch of
a `webwatch` capture was asked at which level.

A `webui` capture is a directory of the web interface's own files, as the
controller serves them over HTTP on port 80, each at its path on the server
and beside a `.headers` file with the response headers it came with. It holds
only the files a document cites. `index.html` names the script it loads:

    for p in index.html main-LF3VJISP.js assets/translations/{de,en}.json; do
      curl -sS -D "DIR/$p.headers" -o "DIR/$p" "http://HOST/$p"
    done
