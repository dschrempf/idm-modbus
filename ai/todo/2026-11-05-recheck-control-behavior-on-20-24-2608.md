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
  (`charge-pump-status-1104-reads-not-driven-while-pumping`).
- `doc/verification-2026-11-05-floor.md`: the floor of 24 rps at 0.67 kW.
- `doc/verification-2026-10-01-charge.md`: a hot water charge.
- `doc/verification-2026-09-20.md`: the display against the registers.
- At Kunde level the legionella settings `FW045` and `FW046` and `N2_PING`
  no longer show, against
  `captures/navigator-10-webapi-20.24-1574-2026-09-20-2218.json`; at
  Fachmann level they do. Find out whether a setting changed since or the
  update hid them.

Re-checked by reads on 2026-11-05 already: every address, the settings
tree's ids and identifiers, the protocol, the Fachmann code, and the labels
of `systemMode` (`adapt-to-software-20-24-2608`, `rechecks.md`).
