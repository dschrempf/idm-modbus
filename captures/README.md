# Captures

What the house's machine answered, kept here and out of git. The captures in
`data/` are the ones a document in `doc/` cites; everything else lands here.
A capture moves to `data/` unchanged when a document starts to rest on it.

The names are those of `data/`, so the kind of capture is in the name:

    navigator-2.0-scan-YYYY-MM-DD-HHMM.json     idm-dump HOST --json
    navigator-2.0-webapi-YYYY-MM-DD-HHMM.json   tools/webprobe.py HOST PIN

The time is the local minute the capture started. A `webapi` capture is a list
of requests with the responses they drew. It may hold only part of the walk,
and it covers only what the user level exposed; its first `status` response
names that level.
