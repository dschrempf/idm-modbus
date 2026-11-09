# Re-check control behavior on 20.24-2608

The update of 2026-11-05 left the registers and the settings tree as they
were, but for what `doc/software-versions.md` lists. What the documents
measured of the machine's behavior was measured on 20.24-1574, and an update
may change control behavior without changing a register. Re-check each when
a heating run is watched anyway, and record the outcome in a new dated
document that `doc/software-versions.md` points to.

- `doc/verification-2026-10-16-draw.md`: graph channels 112 and 365, both
  `T20x_QACT` before, are now `N2_THERMAL_PERFORMANCE_POLY` and
  `…_FLOWSENSOR`. Its 4112, which stayed at -1.0, is gone; 4113 and 4114
  are locks (`power-limit-4108-semantics-unknown`).
- `doc/verification-2026-10-16-charge-pump.md`: 1074 is M73's signal, now
  from the manual too, and 1104 does not follow it
  (`charge-pump-status-1104-reads-not-driven-while-pumping`). It is prose
  in `doc/research.md`'s open questions and in the haddock of `Drive`
  (`decide-how-a-measured-fact-enters-the-table`); if it holds here too,
  weigh again a `Presence` constructor for a register that answers but does
  not follow its quantity, which takes 1104 out of `present`.
- `doc/verification-2026-11-05-floor.md`: the floor of 24 rps at 0.67 kW.
- `doc/verification-2026-10-01-charge.md`: a hot water charge.
- `doc/verification-2026-09-20.md`: the display against the registers.
Re-checked by reads on 2026-11-05 already: every address, the settings
tree's ids and identifiers, the protocol, the Fachmann code, and the labels
of `systemMode` (`adapt-to-software-20-24-2608`, `rechecks.md`). Settled
from the captures on 2026-11-09: `FW045` and `FW046` went with `FW044` Off,
on 20.24-1574, and `N2_PING` never went (`doc/software-versions.md`).
