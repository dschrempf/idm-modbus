# Move the transcription to 812170 rev. 12

Decided on 2026-11-05: the table is transcribed from rev. 12 (software
20.23-515) instead of rev. 10 (20.21-101), as a step of its own before
`table-rebuild.md`, so that the manual's diff can be reviewed apart from the
update's. Where rev. 12 was found, and its md5: `beyond-this-update.md`.

- Done on 2026-11-05. The PDF is filed with the house documents. `manual/`
  holds `812170-rev12.{pdf,txt}` and, renamed, `812170-rev10.{pdf,txt}`; the
  `.txt` files are `pdftotext -layout` output. Tracked files name rev. 12
  only: the commands in `CLAUDE.md` and `tools/transcribe.py`, and the
  citation in `doc/verification-2026-09-20.md`, now
  `manual/812170-rev12.txt:486`, which prints 1034 as rev. 10 did. Until the
  transcription below runs, the table is still rev. 10's.
- Run `tools/transcribe.py` on rev. 12 without `--scan`,
  `--webapi` and `--widths`: the `observed` column and the `gltmon` rows then
  carry over, and the diff holds only what the manual changed.
- 40 pages against 36, and the list is printed with columns in a
  different order on different pages. Expect the script to need changes,
  and check the column headings page by page.
- Review the diff: names, units, ranges, defaults, enumerations, addresses
  added or dropped. Rev. 12 still has 4112 as the `FLOAT`
  `Leistungsbegrenzung Kaskade`, and none of the 18 new `N2_GLTMON`
  addresses.
- Some of the 24 `gltmon` rows may now be in the manual. Check how the
  script treats an address that both sources name, and whether
  `data/navigator-2.0-gltmon-parameters.tsv` still joins.
- With the transcription, the claims that the table is rev. 10's move to
  rev. 12: `doc/research.md` (the authoritative source, the revision drift
  section, the source list), the header of `IDM.Navigator.Table`, and the
  note on `DWord` in `IDM.Navigator.Register`, once rev. 12 is checked for
  it. Two stay as they are: the `Changelog.md` entries already released,
  and `doc/verification-2026-09-19.md`, which says what was measured against
  rev. 10. `Changelog.md` gets the table change.
