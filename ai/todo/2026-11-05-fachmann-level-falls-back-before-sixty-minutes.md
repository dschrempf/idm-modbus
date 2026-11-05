# The Fachmann level falls back before sixty minutes

On 20.24-1574 the Fachmann level held sixty minutes from the entry,
however often it was read (`doc/verification-2026-10-01-charge.md`). On
20.24-2608, on 2026-11-05, it fell back to Kunde 9 min 48 s after one entry
and 7.5 to 8 min after the next
(`captures/navigator-2.0-level-20.24-2608-2026-11-05-1636.log`), and held
for the walk of 18:59 to 19:10, eleven minutes, until left by hand
(`doc/software-versions.md`). Two durations two minutes apart are no fixed
timeout. What ends the level now is unknown: a time from the entry,
idleness at the display or the web interface, or something else. A remote
session by whoever updated the controller that afternoon would end it too
(`adapt-to-software-20-24-2608`, `beyond-this-update.md`).

Three claims still say sixty minutes: `CLAUDE.md` ("sixty minutes from the
entry"), the header of `IDM.Navigator.Web.Level`, and the help of `idm-web`.
No code assumes the hour. A `--watch` that relies on the level needs
renewing it sooner, and `fachmann-entry-right-after-leaving-is-ignored`
plans that renewal around the hour.

## How we might settle it

1. On several days, enter the level and read it every 30 s with
   `idm-web --status` until it falls back, as the log of 16:36 did; once at
   rest, once with a watch asking every 10 s, once with the display touched.
2. Correct the three claims to what step 1 finds, and record it in a dated
   `doc/`.
3. Re-check `fachmann-entry-right-after-leaving-is-ignored` against it.
