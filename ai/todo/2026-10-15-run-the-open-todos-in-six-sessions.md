# Run the open todos in six sessions

The eleven todos of 2026-10-15 share a few things they wait for: the machine
heating, the write interface, several days of data. They group into six
sessions. What each item needs stays in its own note; this note holds only
the grouping and the order.

## Order

1 and 5 can start now. 2 waits for a long heating run. 4 comes after 1 and 2,
6 after 5, and 3 runs in the background.

## 1. Desk: no heating, no writes

- `operating-mode-3-and-minus-1-at-1005-unlabeled`: the web JavaScript and
  its translations, for `systemMode` 3 and -1.
- `uchar-254-at-1714-and-1715-may-be-minus-two`: the same files, for -2;
  then its steps 1 and 2 (dated doc, `research.md`, the decision on decoding
  a `UCHAR` from the whole word).
- `power-limit-4108-semantics-unknown`, step 1, first half: search the
  existing webapi captures for a setting matching 4108 or 4112.

Only needs the machine reachable.

Done on 2026-10-15: 1005 answered, -2 left to iDM support, no setting for
4108; see each note. One finding for session 4: 1714/1715 found no label, so
of the four questions there, three remain. And one for session 4 to decide
first: 1005 reads `ffff` in "Aus", so `decode` takes the machine switched off
for no value.

## 2. One long heating run, read-only, Fachmann level

- `charge-pump-signal-1074-unchecked-at-rest` and
  `charge-pump-status-1104-reads-not-driven-while-pumping`: one run, as the
  notes say.
- `least-draw-at-heating-modulation-floor-unknown`: also a long heating run
  at Fachmann level.
- `power-limit-4108-semantics-unknown`, step 1, second half: 12763 is
  watched anyway and lists 4108 and 4112.

The run should be long, for the floor, and cross a start or stop, for 1074.
Merged:

    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann     # again every 60 min
    IDM_PIN=... cabal run idm-web -- HOST --watch 10 4782 12763 6245 > captures/navigator-2.0-webwatch-YYYY-MM-DD-HHMM.jsonl
    cabal run idm-dump -- HOST --watch 10 1072 1074 1090 1100 1104 4108 4112 4122 4126 > captures/navigator-2.0-watch-YYYY-MM-DD-HHMM.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --leave-fachmann

The least-draw note asks for 30 s; whether the Navigator keeps up with nine
registers every 10 s is untested.

## 3. Passive capture over days

- `page-heat-exceeds-waermemenge-registers-by-1-19`: `idm-dump --watch 600`
  of 1746, 1748, 1750, 1754 and 1100 across several heating midnights, then a
  webapi capture; the regressions after.

Start it after session 2: two Modbus clients polling at once is untested
against the stall.

## 4. Design: how a measured fact enters the table

Four notes end at the same question, what of a source other than the manual
`tools/transcribe.py` takes in:

- 1074, option 1: a measured datatype, range and unit for a `gltmon` row.
- 1104, option 1: a `Presence` constructor, and how a watch enters the table.
- 1005: an enum code the manual does not print.
- 1714/1715: the same shape, if session 1 finds a label.

`facts-from-812184-have-no-home-in-the-table` was dropped for prose on
2026-09-20, on the premise that nothing in the table is typed by hand.
`data/navigator-2.0-gltmon-parameters.tsv` has since broken that premise.
Either reopen it with that as what has changed, or choose prose for all four
again.

That note also says 812184 calls 4122 a model output, while
`least-draw-at-heating-modulation-floor-unknown` says nothing yet says which;
session 2 settles it.

## 5. Code: the write interface

- `write-interface-with-eeprom-cost-visible`: no machine, independent of 1–4.

## 6. Write experiments

- **6a, register 74:** `unit-of-pv-surplus-74-unsettled`, and
  `controller-behavior-when-glt-values-stop-unknown` for 74. Both need
  `N2_PV_SIGNAL` at `N2_GLTSF`, one EEPROM cycle.
- **6b, the requests:** `what-glt-requests-1710-1712-1713-do-unsettled`,
  then the 4108 limit write of `power-limit-4108-semantics-unknown` during a
  run, once its persistence is known.

The other registers of the "values stop" note follow, a few per later write
session.

Open: whether 6a waits for session 5 or Dominik allows a one-off write
outside the library, which would let it run first.
