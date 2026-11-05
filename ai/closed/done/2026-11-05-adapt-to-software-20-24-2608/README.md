# Adapt to software 20.24-2608

On 2026-11-05 at 16:09 the controller restarted with software
`T_NAV10_20.24-2608-g0c686ed41`, where everything in `doc/` and the table
were measured on 20.24-1574. `doc/software-versions.md` logs the versions and
what the reads of that afternoon found changed. This folder holds everything
that follows from it. It comes before session 6 of
`run-the-open-todos-in-six-sessions`: no write experiment on a table that
describes another software.

No other update went unseen between the readings of the version
(2026-09-19, 09-24, 09-29, 10-01, 11-05). Since 2026-09-19 the controller's
log (`N2_LOG_HISTORY` in `captures/navigator-2.0-webapi-20.24-2608-2026-11-05-1624.json`)
shows two restarts: 2026-09-23 08:40, after a user shutdown and between two
readings of 1574, and 2026-11-05 16:09. This holds only if every update
restarts the controller and the log keeps every restart. Who updated is
unknown, and it can't easily be prevented, so the guard checks every session
(`beyond-this-update.md`).

Order: the guard first, so that nothing writes on a version nobody checked.
Then rev. 12 of the manual, then the table, then the tools, then the
re-checks on the machine, which need the first four.

- `version-guard.md`: every session reads the software once; a write goes
  ahead only on the expected version, a read on any, and says which. Every
  capture records it. Done: built, tried on the machine, the consumers told.
- `manual-rev-12.md`: transcribe 812170 rev. 12 instead of rev. 10, on its
  own, before the rebuild. Done; 4126 and 4128, which rev. 12 drops, come
  back with the rebuild.
- `table-rebuild.md`: regenerate the table from captures of 2026-11-05,
  and bring code, tests and docs to 20.24-2608. Done: 722 registers, every
  one read on 2608, and the table states 2608, patch 0.
- `tool-fixes.md`: the sixty-minute level claim is wrong. Done: the
  refusal and the redaction of the myiDM ID.
- `rechecks.md`: what was re-checked on 2026-11-05, and what needs the machine
  running.
- `beyond-this-update.md`: the consumers, the newer manual found, and why
  updates stay unannounced.

## Closed on 2026-11-05

The update is handled: the guard, the table of revision 12 rebuilt for
20.24-2608, and the tool fixes. A review of the changes found and fixed
four things more:

- The myiDM identifier at 500, which the rebuild made a table row, went
  unredacted into `idm-dump`'s output and into the scan of 19:12 and the
  widths captures of 16:39 and 18:50. `idm-dump` now redacts any read
  that takes it in, and the three captures are redacted in place.
- `CLAUDE.md` still gave the sign of a `WORD` by its minimum alone.
- The open notes still asked what revision 12 answers. 1074 decodes as a
  `Drive` now, so `charge-pump-signal-1074-unchecked-at-rest` is closed.
  4108 is kW and volatile, which took its write away from
  `eeprom-guard-needs-exact-round-trip`.
- `idm-manager`'s notes still read the Smart Grid status at 1006, and
  still said every Modbus write refuses.

What needs the machine over days went to notes of its own:

- the Fachmann level's duration and the sixty-minute claims of
  `tool-fixes.md`: `fachmann-level-falls-back-before-sixty-minutes`;
- the behavior re-checks of `rechecks.md`:
  `recheck-control-behavior-on-20-24-2608`, and each item naming a note to
  that note (`power-limit-4108-semantics-unknown`,
  `controller-behavior-when-glt-values-stop-unknown`,
  `unit-of-pv-surplus-74-unsettled`,
  `charge-pump-status-1104-reads-not-driven-while-pumping`);
- the mail to iDM support of `beyond-this-update.md`:
  `ask-idm-support-for-812170-covering-20-24-2608`.
