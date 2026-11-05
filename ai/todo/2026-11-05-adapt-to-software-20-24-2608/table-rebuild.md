# Rebuild the table for 20.24-2608

Done on 2026-11-05. `data/navigator-2.0-software.tsv` states 20.24-2608,
patch 0, so a write goes ahead on the machine as it runs now. The table has
722 registers, 30 of them from `N2_GLTMON`, all `present` or `absent`, none
`untested`.

## The captures

All read on 2608 and recording it:

- `captures/navigator-2.0-widths-20.24-2608-2026-11-05-1850.json`: every
  address the page lists, 133. The widths of 1574 were not reused.
- `captures/navigator-2.0-webapi-20.24-2608-2026-11-05-1859.json`: a full
  walk at Fachmann level, holding both `N2_GLTMON` and the settings tree, which
  the join check needs. No earlier capture of 2608 held both. It holds the
  myiDM ID unredacted (`tool-fixes.md`).
- `captures/navigator-2.0-scan-20.24-2608-2026-11-05-1912.json`: `idm-dump
  --json` on the rebuilt table, 722 addresses. The old rows read as at 16:17;
  every new one answers.

## Decided on 2026-11-05, and built

- **Width rule.** An address is one register wide where the next one answers
  on its own; before, only a refused read of two decided that, which a
  register followed by another never gives. This decides 4110 to 4114.
- **A contradicted manual row goes** even where the page names nothing in its
  place: 4112, the manual's `FLOAT` `Leistungsbegrenzung Kaskade`, is out of
  the table. So that the rows carried over drop it too, a manual row two
  registers wide whose second register is a page row goes as well. Without
  captures, the script writes the same table byte for byte.
- **Nameless rows stay out**: 68, 70, 72, 80, 4111, 4112.
- **`true` and `false` count as values**: 4113 and 4114 are rows. 528 and
  4116, whose values are text, stay out.
- **A name without a unit keeps its parentheses.** The page prints the name, a
  space, and `(unit)` or nothing, so `Softwaretype (bitcodiert) ` has no unit.
- **The alarm codes** at 1950 to 1958 are plain one-register rows; a type of
  their own is `alarm-codes-1950-to-1958-as-a-type`.
- 4108 keeps the manual's name, `Leistungsbegrenzung Wärmepumpe`, though the
  page now prints `Leistungsbegrenzung`: the manual's row stands where the
  width agrees.

## What changed with it

- `test/Main.hs`: 30 page rows, none `untested`, 4112 gone with 4113 one
  register wide, the unit split at 520 and 4126.
- `CLAUDE.md`, `doc/research.md`, `doc/software-versions.md` (the restarts in
  the log, the rebuild's captures), `Changelog.md`, the docstring of
  `tools/transcribe.py`.
- `Target.hs` regenerates unchanged; 74 is still the one target.

## Left to others

- 1714 and 1715 are `UCHAR`s documented 0 to 100 % with a default of -1
  since rev. 12; `decode` still takes any negative byte as no value
  (`uchar-254-at-1714-and-1715-may-be-minus-two`).
- A new dated document takes what the re-checks find, and
  `doc/software-versions.md` points to it (`rechecks.md`).
