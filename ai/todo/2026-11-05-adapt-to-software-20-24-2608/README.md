# Adapt to software 20.24-2608

On 2026-11-05 at 16:09 the controller restarted with software
`T_NAV10_20.24-2608-g0c686ed41`, where everything in `doc/` and the table
were measured on 20.24-1574. `doc/software-versions.md` logs the versions and
what the reads of that afternoon found changed. This folder holds everything
that follows from it. It comes before session 6 of
`run-the-open-todos-in-six-sessions`: no write experiment on a table that
describes another software.

Order: the guard first, so that nothing acts on a version nobody checked.
Then the table, then the tools, then the re-checks on the machine, which need
the first three.

- `version-guard.md`: every command that acts on the machine checks the
  software first and goes ahead only on the expected version. Design choices
  open.
- `table-rebuild.md`: regenerate the table from the captures of 2026-11-05,
  and bring code, tests and docs to 20.24-2608.
- `tool-fixes.md`: `idm-web --show` misreports a refusal, the myiDM ID
  escapes redaction, and the sixty-minute level claim is wrong.
- `rechecks.md`: what was re-checked on 2026-11-05, and what needs the machine
  running.
- `beyond-this-update.md`: so the next update is noticed: versions in every
  capture, the consumers, a newer manual, updates switched off.
