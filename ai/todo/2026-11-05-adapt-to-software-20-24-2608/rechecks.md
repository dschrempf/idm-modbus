# Re-check on the machine for 20.24-2608

On 2026-11-05 at 16:09 the controller restarted with software
`T_NAV10_20.24-2608-g0c686ed41` and BE `1.0-4103-g7d7c51074`, where
everything in `doc/` was measured on 20.24-1574. `doc/software-versions.md`
logs the versions and what the reads of 16:17 to 16:41 found changed.

## Re-checked on 2026-11-05, by reads

- Every table address answers as before, at the same width, but 1999 and
  4112 (scan `…-2026-11-05-1617`).
- The settings tree has the same ids and parameter identifiers, plus
  `SSYSPV030` and `SSYSPV031`. The 26 settings that join to a register by
  parameter agree with it, `BV002` and `BV003` as two's complement.
- The protocol is still `jsonVersion` 11, and `overview`, `detail` and
  `traverse` answer as before.
- The Fachmann code from the clock still works.
- The web script names `systemMode` 3 `RD_HOLIDAY` and -1 `RD_OFF` as before.

## Behavior, on the machine

Each item names the note or document it re-checks. Run them after the guard
and the table are in place, so each run is recorded against 2608.

- The Fachmann level fell back after 9 min 48 s and after 7.5 to 8 min.
  Find what ends it: a fixed time from entry, idleness at the display, or
  something else. Then `tool-fixes.md` corrects the sixty minutes. Then
  `fachmann-entry-right-after-leaving-is-ignored` again.
- `power-limit-4108-semantics-unknown`: the page now calls 4108
  `Leistungsbegrenzung  (kW)`. 4112 became a register of its own at 0.0, with
  4110 `Sperre`, 4111, 4113 and 4114 `Sperre Booster 1/2`, all RW, beside it.
- `controller-behavior-when-glt-values-stop-unknown`: the new help text of
  `SSYSPV031` says that while it is No, `SSYSPV030` (now 1.0 kW) stands in
  for the house consumption once the smart meter has sent nothing for more
  than five hours. Whether a GLT-written value counts as the smart meter is
  for 6a to find out.
- `unit-of-pv-surplus-74-unsettled` and 6a generally: the PV menu has the two
  new settings.
- `doc/verification-2026-10-16-draw.md`: graph channels 112 and 365 are now
  named `N2_THERMAL_PERFORMANCE_POLY` and `…_FLOWSENSOR`. 4112 no longer
  stays at -1.0.
- `doc/verification-2026-10-16-charge-pump.md` (1074, 1104),
  `doc/verification-2026-11-05-floor.md` (24 rps, 0.67 kW) and
  `doc/verification-2026-10-01-charge.md`: control behavior, which an update
  may change. Re-run when a heating run is watched anyway.
- `doc/verification-2026-09-20.md`: the display against the registers.
- At Kunde level `FW045`, `FW046` and `N2_PING` no longer show; find out
  whether a setting or the update hid them.
