# `idm-drive` reads the web watch too

A PV run is two processes today: `idm-drive` over Modbus, and
`idm-web --watch --reason --fachmann` beside it. Each has its own session
and its own capture, and `runtable.py` lines the two up by time. The
design of `idm-drive` (2026-11-10) left the web channel out: it is a second
channel, with its own session and the Fachmann level. A need on it is the
same idea as `IDM.Navigator.Rounds`, applied to `IDM.Navigator.Web.Session`.

The goal is one process and one capture per run. The drive's rounds also
read the web watch's settings, and the drive holds the Fachmann level.

## To settle before building

- **Period.** Does the web need share the schedule's `round`, or get a
  period of its own? `IDM.Navigator.Rounds` keeps a period per need open
  (`Need` is abstract).
- **Lines.** How do the web watch's read lines and level lines go into the
  drive's stream? `runtable.py` then reads them there instead of from
  `--web`.
- **The level.** The renewal decision of the private sublibrary `fachmann`
  moves into the drive, and leaving the level joins the finals. What does
  the drive do when it gives up on the level? The web watch keeps reading
  at Kunde.
- **Two sessions.** The drive's writes need a Modbus `Writable`, and the
  level needs a web one. Each channel reads the software on its own.
- **`idm-web --watch`.** Does it stay as a standalone command?
- **Renewal without a gap.** It is untested whether an entry sent while the
  level is Fachmann restarts the sixty minutes. If it does, a renewal needs
  no leave and no 30 s pause. `enterFachmann` sends nothing at Fachmann
  (`AlreadyFachmann`), so the test means sending the code there, which
  `IDM.Navigator.Web.Level` refuses.

## Outside this note

- `idm-drive-replaces-drivepv`, done.
- The clamp run of `pv-control-of-74-and-88` does not wait for this: it
  runs the two processes.
