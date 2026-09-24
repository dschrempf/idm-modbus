# Move the tracked captures to captures/

New captures go to the untracked `captures/`, but the older ones still sit in
`data/`, tracked: `navigator-2.0-scan-*.json` and
`navigator-2.0-webapi-*.json`. Two homes for the same kind of file is the
inconsistency; the content is not sensitive enough to be the reason.

What rests on them, and has to change with the move:

- `tools/transcribe.py` takes `data/navigator-2.0-scan-2026-09-19.json` as
  its second argument to fill the `present` column of the register table.
  Once the scan is untracked, nobody else can regenerate that column; decide
  whether that is acceptable or whether the column needs a source that stays
  in the repository.
- `data/navigator-2.0-web-*.tsv` takes its `observed` column from a scan.
- `doc/verification-2026-09-19.md`, `doc/verification-2026-09-20.md` and
  `doc/verification-2026-09-20-webapi.md` cite the files by path.
- `CLAUDE.md`, `captures/README.md` ("moves to `data/` when a document rests
  on it"), the usage line of `tools/transcribe.py` and the Haddock of
  `app/Main.hs` name `data/` as their home.

The files stay in git history either way.
