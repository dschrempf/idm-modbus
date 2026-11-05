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
- `table-rebuild.md`: regenerate the table from the captures of 2026-11-05,
  and bring code, tests and docs to 20.24-2608.
- `tool-fixes.md`: `idm-web --show` misreports a refusal, the myiDM ID
  escapes redaction, and the sixty-minute level claim is wrong.
- `rechecks.md`: what was re-checked on 2026-11-05, and what needs the machine
  running.
- `beyond-this-update.md`: the consumers, the newer manual found, and why
  updates stay unannounced.
