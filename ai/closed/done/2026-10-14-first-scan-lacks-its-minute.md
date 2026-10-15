# The first scan's name lacks its minute

`captures/navigator-2.0-scan-2026-09-19.json` is the one capture without the
`-HHMM` that `captures/README.md` requires; `Changelog.md` and
`doc/verification-2026-09-19.md` cite it by that name. Renaming needs the
minute the capture started, which only Dominik may know (the file's mtime is
when it ended, and may have been touched since).

Fixed on 2026-10-15: renamed to `navigator-2.0-scan-2026-09-19-1503.json`,
and its two citations follow. The file is byte for byte the scan committed in
c6c2dce at 15:08:52, with mtime 15:05:21; a sweep of 663 addresses at 150 ms
takes at least 100 s, and the scans of 2026-10-15 ended within two minutes of
their starting minute, so it started between about 15:03:20 and 15:03:40.
