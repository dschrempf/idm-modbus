# How long the Fachmann level holds, and how to renew it

A long watch at Fachmann level must renew the level before it falls back,
and a renewal right after leaving can be ignored. Both are unsettled, and
the renewal depends on the duration.

## Where it stands

- Duration: sixty minutes on 20.24-1574; on 20.24-2608 it fell back after
  about 8 and 10 minutes on 2026-11-05, and held 73 minutes on 2026-11-06,
  left by hand. Activity at the display or the web interface may extend it.
  Three claims still say sixty minutes: `CLAUDE.md`, the header of
  `IDM.Navigator.Web.Level` and the help of `idm-web`.
- Renewal: an entry straight after leaving was ignored once; pauses of 20 s
  and 30 s took at the first attempt. Repeated wrong entries may block the
  code input (`N2_USERLEVELINPUTBLOCKED`); whether an ignored entry counts
  is unknown.

## Next, in order

1. Measure the duration: step 1 of
   `fachmann-level-falls-back-before-sixty-minutes.md`.
2. Measure the pause a renewal needs, and whether the code sent at Fachmann
   restarts the clock: `fachmann-entry-right-after-leaving-is-ignored.md`,
   "The measurement".
3. Correct the three claims, and build the renewal its options choose; a
   dated `doc/` for both measurements.

## Files

- `fachmann-level-falls-back-before-sixty-minutes.md`: the durations seen
  on 20.24-2608, and the measurement.
- `fachmann-entry-right-after-leaving-is-ignored.md`: the ignored entry, and
  the options for a renewal in the library.
