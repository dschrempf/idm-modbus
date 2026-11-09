# Run the open todos in six sessions

The eleven todos of 2026-10-15 share a few things they wait for: the machine
heating, the write interface, several days of data. They group into six
sessions. What each item needs stays in its own note; this note holds only
the grouping and the order.

## Order

1, 2 and 5 are done, and 6a has an entry of its own. 4 and 6b can start
now; 3 has not started.

## 1. Desk: no heating, no writes

Done on 2026-10-15: 1005 answered and measured, -2 left to iDM support, no
setting for 4108; see `operating-mode-3-and-minus-1-at-1005-unlabeled`,
`uchar-254-at-1714-and-1715-may-be-minus-two`,
`power-limit-4108-semantics-unknown`, and session 4 below.

## 2. One long heating run, read-only, Fachmann level

Done on 2026-10-16 and 2026-11-05. 1074 and 1104 settled
(`doc/verification-2026-10-16-charge-pump.md`); 4122 is the inverter's
figure, and 4108 and 4112 stay at -1.0 in every mode
(`doc/verification-2026-10-16-draw.md`); the floor is 24.0 rps at 0.67 kW
(`doc/verification-2026-11-05-floor.md`). A round of nine registers took
about 1.5 s at 10 s, and no read failed. Renewing the level found
`fachmann-entry-right-after-leaving-is-ignored`.

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
`data/navigator-10-gltmon-parameters.tsv` has since broken that premise.
Either reopen it with that as what has changed, or choose prose for all three
again; prose leaves the 1005 defect standing.

That note also says 812184 calls 4122 a model output. Session 2 found it the
inverter's figure on this machine (`doc/verification-2026-10-16-draw.md`).

## 5. Code: the write interface

Done on 2026-11-05: built, with 74 the one target; see
`write-interface-with-eeprom-cost-visible`, now closed. Each later write
experiment activates its register in `data/navigator-10-targets.tsv` as it
begins.

## 6. Write experiments

`adapt-to-software-20-24-2608` came first: the controller was updated on
2026-11-05, and every write waited for the version guard and the rebuilt
table. Both are done; a write goes ahead on 20.24-2608.

- **6a, registers 74 and 88:** from 2026-11-07 an entry of its own,
  `pv-control-of-74-and-88`, whose README orders the runs. It takes in the
  test of 74 of `controller-behavior-when-glt-values-stop-unknown`.
- **6b, the requests:** `what-glt-requests-1710-1712-1713-do-unsettled`,
  then the 4108 limit write of `power-limit-4108-semantics-unknown` during a
  run. Revision 12 prints 4108 volatile, so it costs no EEPROM cycle.

The other registers of the "values stop" note follow, a few per later write
session.

Before the first EEPROM target is listed:
`eeprom-guard-needs-exact-round-trip`, whose round trip that write measures.
The code items of `write-interface-eeprom-guard-and-tests-open` were done on
2026-11-05.

On 2026-11-05 a write beside a polling watch stalled nothing
(`doc/verification-2026-11-05-pv-surplus.md`). Untested, and for these
sessions to watch: writing while session 3's watch polls too. The stall
that watch is kept apart from session 2 for may hit a write as well.

## Closed on 2026-11-09

Sessions 1, 2 and 5 done; 6a became `pv-control-of-74-and-88`. The rest went
to `order-of-the-open-todos`, which orders every open todo, not only those of
2026-10-15: session 3 is `page-heat-exceeds-waermemenge-registers-by-1-19`,
session 4 `decide-how-a-measured-fact-enters-the-table`, 6b
`what-glt-requests-1710-1712-1713-do-unsettled` and the 4108 runs of
`pv-control-of-74-and-88`. Its caveat on writing while another client polls
went with session 3 into that note.
