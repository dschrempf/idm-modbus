# Transcribe the table from 812663

## Outcome, 2026-11-09

Done. Decided with Dominik: the script reads 812663 alone, so rooms 7 to 9
leave the table; `decide-how-a-measured-fact-enters-the-table` stays a change
of its own, so this diff stays checkable. With the scan of 2026-11-05 19:12,
the widths of 18:50 and the walk of 18:59, rev. 12 still regenerates today's
files byte for byte; 812663 removes the 110 rows of rooms 7 to 9 and their
140 enumerations, and nothing else; `Target.hs` is unchanged. 812663's thumb
index, 9 to 13 at the page edge, entered the rows until the script cropped
the page to `TYPE_AREA`. The footnote under 1050 and 1052 is in no column of
the table.

The table is transcribed from 812170 rev. 12, the Navigator 2.0's manual.
812663 rev. 0 is the Navigator 10's own, and the table should rest on it.
Its parameter list is rev. 12's row for row but for two things
(`doc/research.md`, "The authoritative source"):

- the zone modules have rooms 1 to 6; rooms 7 to 9, 2044 to 2649 in part,
  are gone. The table marks them `absent` on this machine anyway.
- the footnote under 1050 and 1052 sends a reader to 1070, not 1068.

So the regenerated TSVs should differ from today's in those rows and in
nothing else; a wider difference is a defect in the script's reading of
the new PDF.

## Steps

1. Read `table-transcription` first.
2. Run `tools/transcribe.py manual/812663-rev0.pdf` with today's scan,
   webapi and widths captures, and diff the TSVs and `Target.hs`. 812663 is
   36 pages to rev. 12's 40, so the page layout, column order and the type
   heights that tell a remark from a name may need the script's attention.
3. Name the document wherever 812170 rev. 12 is named as the table's
   source: `tools/transcribe.py`'s docstring, the Haddock of
   `IDM.Navigator.Table` and of the source constructor in
   `IDM.Navigator.Register`, `CLAUDE.md`'s data flow, `Readme.md`,
   `doc/research.md`, `table-transcription`.
4. `Changelog.md`: the source document, and the rows that went.

## Design to settle with Dominik before step 2

- Whether rooms 7 to 9 leave the table, or stay as rows of 812170 for a
  Navigator 2.0 that has them. The table describes the Navigator 10, which
  argues for leaving.
- Whether the script keeps reading 812170 too, for a Navigator 2.0, or
  reads 812663 alone.
- With them, `decide-how-a-measured-fact-enters-the-table`: the same
  script takes in a source other than the manual.
