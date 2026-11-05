# Run the open todos in six sessions

The eleven todos of 2026-10-15 share a few things they wait for: the machine
heating, the write interface, several days of data. They group into six
sessions. What each item needs stays in its own note; this note holds only
the grouping and the order.

## Order

1, 2 and 5 are done. 4 and 6 can start now, and 3 runs in the background.

## 1. Desk: no heating, no writes

- `operating-mode-3-and-minus-1-at-1005-unlabeled`: the web JavaScript and
  its translations, for `systemMode` 3 and -1.
- `uchar-254-at-1714-and-1715-may-be-minus-two`: the same files, for -2;
  then its steps 1 and 2 (dated doc, `research.md`, the decision on decoding
  a `UCHAR` from the whole word).
- `power-limit-4108-semantics-unknown`, step 1, first half: search the
  existing webapi captures for a setting matching 4108 or 4112.

Only needs the machine reachable.

Done on 2026-10-15: 1005 answered and measured, -2 left to iDM support, no
setting for 4108; see each note, and session 4 below.

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

Run on 2026-10-16, 07:45 to 10:30, at 10 s; a round of nine registers takes
about 1.5 s, and no read failed. It caught a heating run from 08:10 to 08:55,
then a hot water charge with a defrost. Settled: 1074 and 1104
(`doc/verification-2026-10-16-charge-pump.md`), 4122 is the inverter's
figure, and 4108 and 4112 stay at -1.0 in every mode
(`doc/verification-2026-10-16-draw.md`). Not settled: the heating floor, as
the run never slowed below 101 rps. The next run caps heating at 50 % and
lowers the heating curve, as `least-draw-at-heating-modulation-floor-unknown`
says; it is the one item of this session left, and its watch is the second Modbus client
session 3 waits for. Renewing the level found
`fachmann-entry-right-after-leaving-is-ignored`.

Done on 2026-11-05, 11:13 to 12:33: capped at 50 % with circuit C's curve
lowered, the run held the floor, 24.0 rps at 0.67 kW
(`doc/verification-2026-11-05-floor.md`). Session 2 is closed.

## 3. Passive capture over days

- `page-heat-exceeds-waermemenge-registers-by-1-19`: `idm-dump --watch 600`
  of 1746, 1748, 1750, 1754 and 1100 across several heating midnights, then a
  webapi capture; the regressions after.

Start it after session 2: two Modbus clients polling at once is untested
against the stall.

## 4. Design: how a measured fact enters the table

Two notes end at the same question, what of a source other than the manual
`tools/transcribe.py` takes in. A third, 1074, was settled by revision 12 of
the manual on 2026-11-05 (`charge-pump-signal-1074-unchecked-at-rest`).

- 1104, option 1: a `Presence` constructor, and how a watch enters the table.
- 1005: two enum codes the manual does not print, -1 "Aus" and 3 "Urlaub",
  measured over Modbus in session 1. "Aus" arrives as `ffff`, so -1 is a
  value of 1005, not its sentinel, and `decode` reads a switched-off machine
  as no value. The manual's range, 0 to 5, cannot tell `decode` otherwise.
  Fix this first.

1714/1715 dropped out: session 1 found no label for -2.

`facts-from-812184-have-no-home-in-the-table` was dropped for prose on
2026-09-20, on the premise that nothing in the table is typed by hand.
`data/navigator-2.0-gltmon-parameters.tsv` has since broken that premise.
Either reopen it with that as what has changed, or choose prose for all three
again; prose leaves the 1005 defect standing.

That note also says 812184 calls 4122 a model output. Session 2 found it the
inverter's figure on this machine (`doc/verification-2026-10-16-draw.md`).

## 5. Code: the write interface

- `write-interface-with-eeprom-cost-visible`: no machine, independent of 1–4.

Done on 2026-11-05: built, with 74 the one target; see the note, now closed.
Each later write experiment activates its register in
`data/navigator-2.0-targets.tsv` as it begins.

## 6. Write experiments

`adapt-to-software-20-24-2608` came first: the controller was updated on
2026-11-05, and every write waited for the version guard and the rebuilt
table. Both are done; a write goes ahead on 20.24-2608.

- **6a, register 74:** `unit-of-pv-surplus-74-unsettled`, and
  `controller-behavior-when-glt-values-stop-unknown` for 74. Both need
  `N2_PV_SIGNAL` at `N2_GLTSF`, one EEPROM cycle.
- **6b, the requests:** `what-glt-requests-1710-1712-1713-do-unsettled`,
  then the 4108 limit write of `power-limit-4108-semantics-unknown` during a
  run. Revision 12 prints 4108 volatile, so it costs no EEPROM cycle.

The other registers of the "values stop" note follow, a few per later write
session.

Before the first EEPROM target is listed:
`eeprom-guard-needs-exact-round-trip`, whose round trip that write measures.
6a's write of 74 adds what a volatile `FLOAT` says about it. The code items
of `write-interface-eeprom-guard-and-tests-open` were done on 2026-11-05.

6a also sets the PV menu for a store charge, the house's use of the surplus;
see `unit-of-pv-surplus-74-unsettled`.

6a ran on 2026-11-05, 21:04 to 21:42: 74 is in kW, the charge stops at
`PV006`, and a write beside a polling watch stalled nothing
(`doc/verification-2026-11-05-pv-surplus.md`). Left of it: what 74 does when
the writes stop, step 3 of `controller-behavior-when-glt-values-stop-unknown`,
and `pv-surplus-74-may-include-the-pumps-own-draw`.

Untested, and for these sessions to watch: writing while a second Modbus
client polls. Session 3's watch is the second client, and the stall it is kept
apart from session 2 for may hit a write too.
