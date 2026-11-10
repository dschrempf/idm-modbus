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

- **On beginning,** it enters the level through `IDM.Navigator.Web.Level`,
  as `--enter-fachmann` does, from Kunde only. If the level is already
  Fachmann, it is left first, and the watch waits 30 s and enters, so the
  watch knows when the sixty minutes began.
- **At 55 minutes from its entry,** it renews: it leaves, waits 30 s, and
  enters again. An entry seconds after a leave answered success and was
  ignored; one 20 s after took (2026-11-10,
  `captures/navigator-10-level-20.24-2608-2026-11-10-2056.log`). The 30 s
  leave a margin. The rounds in the pause are written as lines that say
  the level was being renewed, so the gap is in the capture.
- **If the level falls back on its own**, Kunde where Fachmann was
  entered, the watch logs it and enters again at the next round. It tries
  at most three times in a row, 30 s apart, so that repeated entries cannot
  run into `N2_USERLEVELINPUTBLOCKED`.
- **On every exit,** the end of the watch, SIGINT, SIGTERM or an exception,
  it leaves the level, with further signals ignored, as the drive does with
  its finals.
- **Every change of level is a line in the webwatch:** entered, renewed,
  fell back, left. `runtable.py` can then mark the gaps in 5888 and 6245.

`--enter-fachmann` and `--leave-fachmann` stay, for work at the display or
by hand.

## Where the code goes

- The 55 minutes, the 30 s and the three tries are constants in `app-web`,
  each documented where it is defined, citing the measurement.
- The decision of when to renew and when to re-enter is a pure function
  over the time since the entry and the level the last round read. It is
  tested in `checks`: the renewal at 55 minutes, re-entering after a
  fallback, giving up after three tries.
- `IDM.Navigator.Web.Level` keeps its two writes and does not change. The
  renewal is a use of them, not a third write.

## Documentation

- `Changelog.md`: the option.
- `CLAUDE.md`: the command list gets `--watch … --fachmann`.
- `web-backend-and-captures`, "The user level": that the watch renews the
  level, and how.
- The PV runs' commands use it from then on. The clamp run's are in
  `does-88-set-the-export-the-pv-controller-holds`.
