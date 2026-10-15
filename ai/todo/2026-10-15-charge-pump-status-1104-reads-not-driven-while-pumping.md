# Charge pump status 1104 reads not driven while pumping

## The discrepancy

1104, `Status Ladepumpe (M73)`, is the manual's register for the heat sink's
charge pump: `WORD`, `RO`, -1 to 100 %. The library decodes its `ffff` as
`DriveSignal NotDriven`. 1104 has read `ffff` in every capture: the ten scans
from 2026-09-19 to 2026-10-15, and all 73 reads of the watch of 2026-10-15
08:35. During that watch the machine heated, 1072 read a flow of 32–33 l/min,
and 1074, `Ladepumpe Wärmesenke Steuersignal`, read 93–97
(`doc/verification-2026-10-15-heat-sink.md`). So while the pump was driven at
about 95 %, the library said it was not driven.

The manual's register and the address missing from the manual can't both be
M73's signal. The 2026-09-20 finding that `ffff` on 1104 is -1 does not settle
which one is: the `Analogausgänge` page printed M73 at -1.0 then, beside 1104
at `ffff`, but 1074 was not being read
(`doc/verification-2026-09-20.md`, "A pump that is not driven").

## What would explain it

1. **1104 does not follow M73 on this machine.** It could be a register that
   software 20.24 or this configuration no longer updates, and 1074 carries
   the signal instead. The manual documents software 20.21-101 (`doc/research.md`,
   "Revision drift").
2. **1074 is not the signal the `Analogausgänge` page prints as M73.** In
   that case 1104 and the page agree, both at -1 while the pump runs on its
   digital output alone, which is what 2026-09-20 showed. Then 1074 is
   something else that shares the name.

## The measurement

This is the same run as `2026-10-15-charge-pump-signal-1074-unchecked-at-rest`:
watch 4782 `N2_ANALOGUE_OUTPUTS` and 12763 `N2_GLTMON` beside 1072, 1074 and
1104, while the machine heats, ideally across a start or stop. That note has
the commands.

- The page prints M73 near 1074's value while 1104 stays `ffff`: explanation 1.
- The page prints -1.0 while 1074 reads a percentage: explanation 2, and the
  1074 note's premise falls.

## The decision it leads to

If it is explanation 1, the table states something about 1104 that is true of
the manual and false of this machine. Its `observed` column says `present`,
which is true but not the whole story. Options:

1. A `Presence` constructor, written by `transcribe.py` from a capture, for a
   register that answers but does not follow the quantity it names. The
   evidence for it is a watch, not a scan, so this also means deciding how a
   watch enters the table.
2. Leave the table alone. Record the finding in `doc/`, and in the haddock of
   `Drive`, which now says that a `NotDriven` is a pump nothing calls for or
   one never installed. On this machine it may also be a pump driven at 95 %.

Either way the finding goes into `doc/research.md`'s open questions until the
run settles it, and into a dated document after.
