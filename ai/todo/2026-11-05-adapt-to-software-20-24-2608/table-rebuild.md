# Rebuild the table for 20.24-2608

## The table

- Run `tools/transcribe.py manual/812170-rev12.txt --scan
  captures/navigator-2.0-scan-20.24-2608-2026-11-05-1617.json --webapi
  captures/navigator-2.0-webapi-20.24-2608-2026-11-05-1636.json --widths
  captures/navigator-2.0-widths-20.24-2608-2026-11-05-1639.json`. The webapi capture of
  1636 holds `N2_GLTMON`; that of 1624 lost the level before reaching it.
- Expected: the 18 new `gltmon` addresses (500, 506, 508, 520 to 528, 1174,
  1950 to 1958, 4110, 4111, 4113, 4114); 4112 one register wide, no longer
  `Leistungsbegrenzung Kaskade`; 4108 renamed; 1999 `present`.
- 4111 and 4112 have no name on the page. Check how the script treats an
  empty name; 68, 70, 72 and 80 are a precedent.
- `data/navigator-2.0-gltmon-parameters.tsv` must still join; the script
  refuses a join the new capture contradicts.
- Record the software the table describes, written by the script (see
  `version-guard.md`, choice 1). That needs the version in a capture the
  script reads. `N2_SERVICE_INFO` is in the webapi capture of 1624, not
  1636, so either the script takes it from there or a new capture holds both.
- 500, the myiDM ID, becomes a row like the others. The table records no
  value: `observed` is `present` or `absent`. The scans that hold the value
  are git-ignored, and having it on the laptop is fine. Its value stays out
  of every tracked file (`tool-fixes.md`).

## Code and tests

- `test/Main.hs`: checks naming 4112 or a `gltmon` count.
- The target 74 is unchanged, but `$(costAt …)` and `$$(registerOf …)`
  rebuild with the table.
- Decide whether 1950 to 1958 get a type of their own, alarm codes joined
  to the notice names `N2_…`.

## Documents

- `CLAUDE.md`, `Readme.md` and `doc/research.md`: register counts (663 and
  682), and anything that states 1574 as now. `doc/research.md` also gets
  the sources: the Loxone mirror gone, rev. 12 on LoxWiki, rev. 7 on the
  forums.
- `doc/software-versions.md`: the restarts in the log since 2026-09-19,
  which show that no update went unseen between readings (`README.md`).
- The dated `verification-*.md` documents stay as they are: they say what
  held on 1574. A new dated document takes what the re-checks find, and
  `doc/software-versions.md` points to it.
- `Changelog.md`: the table change, and the guard.
