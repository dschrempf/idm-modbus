# The Fachmann level, held by the web watch

## Why there

5888 `N2_EVR_OVERVIEW` and 6245 `N2_MODULATION_OVERVIEW` answer at
Fachmann level only, and every PV run reads them in the web watch. The
drive writes over Modbus, which has no user level. So the level is a need
of the part that reads the web, and goes with it. If the web watch later
joins `idm-drive` as a web need (`rounds-and-needs.md`, "Not in this
design"), the level moves with it.

Today a run takes four commands for this: `--enter-fachmann`, the watch,
`--leave-fachmann`, and remembering the last one. Nothing renews the
level, and the controller ends it sixty minutes after the entry, however
often it was read meanwhile (`web-backend-and-captures`, "The user level").
A run that waits for its start and then charges for 40 minutes outlasts
that.

## `idm-web HOST --watch SECONDS [--reason] --fachmann SETTING...`

- **The level is read every round,** with a `StatusOverview` query, first
  in the round, before `--reason`'s overview. It is one request more per
  round, and its answer is not a line of its own: a level line is written
  only where the level changes.
- **On beginning,** it enters the level through `IDM.Navigator.Web.Level`,
  as `--enter-fachmann` does, from Kunde only. If the level is already
  Fachmann, it is left first, and the watch waits 30 s and enters, so the
  watch knows when the sixty minutes began. That also ends a Fachmann
  level a person opened at the display. The watch exits at once, having
  sent nothing, as a refused PIN makes it exit now, where:
  - the session is not on the software the table describes, so there is
    no `Writable`;
  - the level is neither Kunde nor Fachmann (`EntryDeclined`);
  - the level is Fachmann without the notice that would close it
    (`NoNotice`), so the watch cannot know when its sixty minutes began.
- **At 55 minutes from its entry,** it renews: it leaves, waits 30 s, and
  enters again. An entry seconds after a leave answered success and was
  ignored; one 20 s after took (2026-11-10,
  `captures/navigator-10-level-20.24-2608-2026-11-10-2056.log`). The 30 s
  leave a margin. The entry may wait for the hour to turn as well, when
  the controller's clock is that close to it (`enterFachmann`). The
  watch's reads go on in the pause: 4768, 10263 and the overview answer at
  Kunde, and 5888 and 6245 answer that the level does not reach them, as
  any read at Kunde does.
- **An entry that did not take** counts as a failed try: one that answered
  but left the level at Kunde, as on 2026-11-10, one the level declined,
  or one that failed.
- **If the level falls back on its own**, Kunde where Fachmann was
  entered, the watch writes it and enters again at the next round.
- **At most three tries in a row,** 30 s apart, so that repeated entries
  cannot run into `N2_USERLEVELINPUTBLOCKED`. After the third, the watch
  writes that it gave up, keeps reading at Kunde for the rest of the
  watch, and enters no more.
- **A session on other software** in mid-watch, after an update has
  restarted the controller, gives no `Writable`: the watch tries nothing
  and writes so, and the restart has ended the level anyway.
- **On every exit,** the end of the watch, SIGINT, SIGTERM or an exception,
  it leaves the level, with further signals ignored, as the drive does with
  its finals (`rounds-and-needs.md`, the drive's signals). At Kunde, after
  giving up, the leave sends nothing.

## The level line

Every change of level is a line in the webwatch, beside the read lines:

    {"captured": STAMP, "software": SOFTWARE, "level": CHANGE, "userLevel": LEVEL, "error": null}

- `captured` and `software` as in a read line.
- `level`: `entered`, `leaving` (a renewal begins), `renewed`,
  `fell-back`, `failed` (a try that did not take), `gave-up`,
  `not-writable`, or `left`.
- `userLevel`: the level the controller reported after the change, as
  `levelText` spells it.
- `error`: what went wrong, for `failed`; `null` otherwise.

The line has no `request` and no `responses`, so `runtable.py`'s
`read_web` skips it as it stands, and session 3 makes it mark the rounds
at Kunde (`event-log.md`).

`--enter-fachmann` and `--leave-fachmann` stay, for work at the display or
by hand.

## Where the code goes

- The 55 minutes, the 30 s and the three tries are constants, each
  documented where it is defined, citing the measurement.
- The decision of when to renew and when to re-enter is a pure function
  over the time since the entry, the level the last round read, the tries
  so far and whether the session is writable. It goes in a private
  sublibrary, `fachmann`, so that `test/Main.hs` reaches it: a test suite
  cannot import a module of an executable. `app-web` depends on it.
- It is tested in `checks`: the renewal at 55 minutes, re-entering after a
  fallback, an entry that answered but did not take as a failed try,
  giving up after three tries and trying no more, no try without a
  `Writable`.
- `IDM.Navigator.Web.Level` keeps its two writes and does not change. The
  renewal is a use of them, not a third write.

## Open

Whether an entry sent while the level is Fachmann restarts the sixty
minutes. If it does, a renewal needs no leave and no gap. It is untested:
`enterFachmann` sends nothing at Fachmann (`AlreadyFachmann`), and trying
it means sending the code there, which `Level` refuses. Not needed for
this design; a measurement for later.

## Documentation

- `Changelog.md`: the option.
- `CLAUDE.md`: the command list gets `--watch … --fachmann`.
- `web-backend-and-captures`, "The user level": that the watch renews the
  level, and how.
- The PV runs' commands use it from then on. The clamp run's are in
  `does-88-set-the-export-the-pv-controller-holds`.
