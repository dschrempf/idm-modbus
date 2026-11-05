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
  carry over, and the diff holds only what the manual changed. Done on
  2026-11-05; rev. 10 still transcribes to the table of before, byte for
  byte.
- 40 pages against 36, and the list is printed with columns in a
  different order on different pages. Expect the script to need changes,
  and check the column headings page by page. Three were needed. Rev. 12
  prints remarks directly below a name (1004, 1050, 1052, 1072, 1093, 1099),
  and only their type, 7.3 against 9.7 pt, tells them from a name that
  wraps, so the script takes the PDF and reads the height with
  `pdftotext -bbox` (decided 2026-11-05). Some defaults sit nearer the
  unit's heading (1498 to 1511, 1696), and 1104 prints the code -1.
- Review the diff: names, units, ranges, defaults, enumerations, addresses
  added or dropped. Rev. 12 still has 4112 as the `FLOAT`
  `Leistungsbegrenzung Kaskade`, and none of the 18 new `N2_GLTMON`
  addresses. Reviewed; `Changelog.md` and the revision drift section of
  `doc/research.md` list the changes. Two need a decision or a consumer:
  - 4126 `thermische Leistung (Durchflusssensor)` and 4128
    `Wärmemenge gesamt` are gone from rev. 12, but the `N2_GLTMON` page of
    1574 lists both, and `idm-manager`'s notes plan the COP on 4126. Both
    read on 2608, and its page lists them. Decided 2026-11-05: they are
    kept, as page rows, which needs their width measured; the table follows
    the manual until the rebuild (`table-rebuild.md`).
  - `Smart Grid Status` moves from 1006 to 90, with Red, Yellow, Green and
    Supergreen for the EVU labels; 1006 is now `Variabler Eingang`.
    `idm-manager`'s notes read the Smart Grid state at 1006.
  - Rev. 12 moves the pump signals' -1 from the minimum into the default.
    Decided 2026-11-05: a `WORD` is signed also where a read-only
    register's default is negative, so 1104 to 1109 keep `NotDriven` and
    1074 gains it, while 86 keeps its sentinel.
- Some of the 24 `gltmon` rows may now be in the manual. Check how the
  script treats an address that both sources name, and whether
  `data/navigator-2.0-gltmon-parameters.tsv` still joins. Eight are: 88,
  1068 to 1074, 4108, 4112, 4124. The carried-over rows used to replace the
  manual's. Decided 2026-11-05: the manual's row stands unless the width
  measured contradicts its datatype, which keeps 1072 the page's `FLOAT`
  (rev. 12 prints a `UCHAR`). The joins, 1520 to 1540, are untouched.
- With the transcription, the claims that the table is rev. 10's move to
  rev. 12: `doc/research.md` (the authoritative source, the revision drift
  section, the source list), the header of `IDM.Navigator.Table`, and the
  note on `DWord` in `IDM.Navigator.Register`, once rev. 12 is checked for
  it. Done; rev. 12 prints no `DWORD`. Two stay as they are: the `Changelog.md` entries already released,
  and `doc/verification-2026-09-19.md`, which says what was measured against
  rev. 10. `Changelog.md` gets the table change.
