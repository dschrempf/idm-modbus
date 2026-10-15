# Charge pump signal 1074 unchecked at rest

## The question

Does register 1074 at rest mean "the pump is not driven", and if it does,
should the library decode it that way?

1074, `Ladepumpe Wärmesenke Steuersignal (% 0-10V/PWM)`, is missing from the
manual. It is one of the 24 `gltmon` rows the controller's register page,
12763 `N2_GLTMON`, lists
(`doc/verification-2026-10-14-gltmon.md`). The page states no datatype, so
`tools/transcribe.py` gives the row what the widths capture measured: one
register, datatype `one-register`. That datatype is deliberately
noncommittal. It is read unsigned and claims no sentinel, so `ffff` decodes to
`Measured (Count 65535)`.

## What the captures say

| When                     | Machine | 1074   | Witness                                              |
| ------------------------ | ------- | ------ | ---------------------------------------------------- |
| 2026-10-01 11:58         | ?       | unread | `N2_GLTMON` prints 1074 as `-1.0`                    |
| 2026-10-14 12:11         | at rest | `ffff` | scan; 1072, the flow rate, reads 0                   |
| 2026-10-15 08:35–08:47   | heating | 93–97  | watch and three scans; 1072 reads 32–33 l/min        |

Setting 4782, `N2_ANALOGUE_OUTPUTS`, prints `M73 Ladepumpe Wärmesenke
Steuersignal`, the same name as 1074, in %. Its footnote gives the scale of
every pump signal (`doc/verification-2026-09-20.md`, "A pump that is not
driven"): -1 not driven, 0 minimum speed, 100 maximum. Every webapi capture
that holds the page, 2026-09-20 to 2026-10-01, prints M73 at -1.0. That
includes 2026-09-20, when the `Digitalausgänge` page showed the pump on.

So far, then, `ffff` and -1 have only been seen on different days. No capture
holds 1074 together with either page, and none holds the page while 1074 read
93–97. The table therefore still reads 65535: a resemblance is not a source.

1104, `Status Ladepumpe (M73)`, is the manual's register for this pump. It
read `ffff` on every scan, including while 1074 read 93–97, so on this machine
it does not report M73's signal (`doc/verification-2026-10-15-heat-sink.md`).

## The measurement

Watch 1074 against both pages at the same time, at rest and ideally across
the start or stop of a heating run, where 1074 should switch between `ffff`
and a percentage at the moment the page switches between -1.0 and the same
percentage:

    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
    IDM_PIN=... cabal run idm-web -- HOST --watch 10 4782 12763 > captures/navigator-2.0-webwatch-YYYY-MM-DD-HHMM.jsonl
    cabal run idm-dump -- HOST --watch 10 1072 1074 1104 > captures/navigator-2.0-watch-YYYY-MM-DD-HHMM.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --leave-fachmann

Both pages were captured at Fachmann level. Whether Kunde level sees them is
untested.

## The decision it leads to

Suppose the run shows `ffff` where the page prints -1.0, and n where it prints
n. To decode 1074 as `DriveSignal`, its row needs three things the page does
not state:

- datatype `WORD`
- a minimum below 0, which is what makes `navigator` read a `WORD` as signed
- unit `%`. `meaning` builds a `Drive` only for `Percent`, and `% 0-10V/PWM`
  parses as `UnknownUnit`, so with a signed range alone 1074 would decode to
  `Count (-1)`.

At present the only hand-written input to a `gltmon` row is its parameter
identifier, `data/navigator-2.0-gltmon-parameters.tsv`. Options:

1. Widen that file, or add one beside it, to carry a measured datatype, range
   and unit for a `gltmon` row. `transcribe.py` would read it and refuse a
   datatype whose width contradicts the widths capture. The row would cite
   the measurement in a `doc/`.
2. Leave the row `one-register` and record the reading in the docs only. A
   consumer decodes 65535 itself.

Either way the run, and its outcome, go in a document in `doc/`.
