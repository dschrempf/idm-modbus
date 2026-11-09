# Decide how a measured fact enters the table

`tools/transcribe.py` takes the table from the manual, a scan, a webapi
capture and a widths capture; `data/navigator-10-gltmon-parameters.tsv` is
the one hand-typed input. Several findings are true of the machine and not
in the manual, and the table has no way to take them in. The measurements
are done; what is left is the decision, and with it a defect.

## The cases

- **1005, two enum codes.** -1 "Aus" and 3 "Urlaub", from the web app's
  script and measured over Modbus. "Aus" arrives as `ffff`, so -1 is a value
  of 1005, not its sentinel, and `decode` reads a switched-off machine as no
  value; the manual's range, 0 to 5, cannot tell it otherwise. The defect
  stands: `data/navigator-10-enums.tsv` has neither code. Fix this first.
  `operating-mode-3-and-minus-1-at-1005-unlabeled.md`.
- **1104, a register that answers but does not follow M73.** Settled by a
  watch, explanation 1; the options are a `Presence` constructor, which
  means deciding how a watch enters the table, or prose in `doc/` and the
  haddock of `Drive`.
  `charge-pump-status-1104-reads-not-driven-while-pumping.md`.
- **The resolution an EEPROM `FLOAT` is stored at.** Only if the first EEPROM
  write reads back other bytes (`eeprom-guard-needs-exact-round-trip`,
  option 2).

## What to decide

`facts-from-812184-have-no-home-in-the-table` was dropped for prose on
2026-09-20, on the premise that nothing in the table is typed by hand.
`data/navigator-10-gltmon-parameters.tsv` has since broken that premise.
Either reopen it with that as what has changed, or choose prose for all the
cases again; prose leaves the 1005 defect standing. That note also says
812184 calls 4122 a model output; on this machine it is the inverter's figure
(`doc/verification-2026-10-16-draw.md`).

`transcribe-the-table-from-812663` moved the script to 812663 and left this
decision to a change of its own. Read `table-transcription` first.

## Files

- `operating-mode-3-and-minus-1-at-1005-unlabeled.md`: how -1 and 3 were
  found, and the reads that show -1 is a value.
- `charge-pump-status-1104-reads-not-driven-while-pumping.md`: the watch
  that settled 1104, and the two options for the table.

## Done 2026-11-09

`facts-from-812184-have-no-home-in-the-table` stays dropped: its facts are
read from a document, which no capture can confirm, and they stay prose. A
fact measured on the machine is decided apart from it:

- **1005.** A third hand-written input,
  `data/navigator-10-measured-enums.tsv`, with the document holding each
  code's evidence. `tools/transcribe.py` adds the codes to the enums table,
  widens the range to -1 to 5, and refuses a code the manual prints. A
  `UCHAR` reads a negative word inside its range as a value. Its rows carry
  no software: re-measuring every finding at each update is not feasible.
- **`Code`.** So that a -1 never stands bare, a new column `scale`, derived
  from the labels, gives `Register` its `registerScale`, and `decode` gives
  an enumeration a `Code` rather than a `Count`. 1104's labels mark points of
  a scale and 1712 is a `BOOL`, so neither is an enumeration.
- **1104.** Prose: `doc/research.md`'s open questions and the haddock of
  `Drive`. It was measured on 20.24-1574 only; the re-check is in
  `recheck-control-behavior-on-20-24-2608`.
- **The resolution of an EEPROM `FLOAT`** waits in
  `eeprom-guard-needs-exact-round-trip`.
