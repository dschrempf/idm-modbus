# The first scan's name lacks its minute

`captures/navigator-2.0-scan-2026-09-19.json` is the one capture without the
`-HHMM` that `captures/README.md` requires; `Changelog.md` and
`doc/verification-2026-09-19.md` cite it by that name. Renaming needs the
minute the capture started, which only Dominik may know (the file's mtime is
when it ended, and may have been touched since).
