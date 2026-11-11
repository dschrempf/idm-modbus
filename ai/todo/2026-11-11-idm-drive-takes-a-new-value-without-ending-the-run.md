# `idm-drive` takes a new value without ending the run

## The problem

A schedule is fixed when `idm-drive` starts, and every exit writes the
finals, 74 at -0.5 among them, which ends a PV run within seconds. The run
of 2026-11-11 (`doc/verification/2026-11-11-the-pv-control-holds-74-at-0-25.md`)
was steered by hand, a value of 74 at a time, and every change was a new
drive taking over from one ended with SIGKILL:

- nine captures for one run, eight of them without an `end` line;
- 4 to 11 s between the last write of one drive and the first of the next,
  and a new session each time;
- a schedule file per step, written during the run; two are kept in
  `schedules/`, the rest live only in the captures' `begin` lines;
- SIGKILL skips the finals by design, so a drive that fails to start leaves
  whatever the last one wrote standing.

Steering by hand found the target of +0.25 in half an hour; a schedule
fixed before would have needed a run per guess. The next runs on 74 will
want it again.

## Ways in

- **A socket.** A Unix domain socket beside the drive, its path in the
  `begin` line, taking a value of 74, 88 or 4108, or the next phase. Its
  permissions are the access control.
- **A file.** A phase whose value is read from a file each round, or the
  schedule read again on SIGHUP.
- Either way, a change is an event in the drive's stream, with the value
  and where it came from, so that `runtable.py` lines it up and one capture
  holds the run.

## To settle before building

- **Measurement or interface.** `CLAUDE.md` keeps `idm-drive` a
  measurement because its schedule is fixed before the run. A drive that
  takes values while it runs is a general driver a consumer could steer;
  is that still a measurement, or does it move into the package's interface?
- **Bounds.** What a value from outside may be: the register's range, or
  tighter, per run.
- **The finals.** Unchanged on every exit, or settable too.
- **`idm-drive-reads-the-web-watch-too`.** Both aim at one process and one
  capture per run; one design or two.
