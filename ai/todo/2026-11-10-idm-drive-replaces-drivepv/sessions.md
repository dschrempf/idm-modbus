# Sessions

Sessions 1 to 3 need nothing from each other but the types and formats
pinned in `rounds-and-needs.md`, `schedule-file.md` and `event-log.md`,
and 3b needs nothing from any of them. All four can run at once, each in
its own worktree, and each commits before it returns. Session 4 joins 1
and 2, and session 5 needs the machine.

    1 rounds   ─┐
    2 schedule ─┼─ 4 idm-drive ── 5 machine, then delete drivepv.py ── clamp run
    3 tools    ─┘                 │
    3b fachmann ──────────────────┘

Conflicts to expect when merging: `idm-modbus.cabal` (1 and 2 touch
different stanzas) and `test/Main.hs` (both append to `checks`). Merge 1
first, then 2.

## 1. Library: rounds and capture

- `IDM.Navigator.Rounds` and `IDM.Navigator.Capture`, from `watch` and
  `watchLine` in `app/Main.hs`.
- `idm-dump --watch` rebuilt on `rounds`, with unchanged output, checked by
  `checks` entries over literal samples.
- `python3` in the dev shell's `nativeBuildInputs`.
- On the machine, optional and read-only: a short `idm-dump --watch` before
  and after the change, with the same line shape.
- Changelog: the two modules. Readme only if it names `watch`'s internals,
  which it doesn't.

## 2. Schedule: format, parser, step

- The private sublibrary `schedule`: the types, the TOML parser
  (`toml-parser` in the cabal file; check that `nix develop -c cabal build`
  finds it), and `step`.
- The `checks` entries of `schedule-file.md`.
- `schedules/pv-clamp-0-1.toml`, the example, so the next run has its
  file.
- No `IDM.Navigator.Drive` yet. `step`'s `Command` is a local type until
  session 4 joins the two.

## 3. Tools and docs, against the formats only

- `runtable.py` reads a drive file, as `event-log.md` says. It is tested on
  a hand-written fixture, made from the table there, and still on an old
  watch and write log from `captures/`.
- Each "Reproducing" command of `drivepv.py` in `doc/` becomes a schedule
  in `schedules/`, named for its run. That covers eight docs, and the
  command list in `CLAUDE.md`. The doc text changes in session 5, when
  `drivepv.py` goes, so the files sit unused until then. Session 4's parse
  check covers them.

## 3b. The Fachmann level in the web watch

- `idm-web --watch --fachmann`, as `fachmann-in-the-web-watch.md` says:
  the pure renewal decision with its `checks`, the option, and the lines it
  writes.
- `app-web/` and `test/Main.hs` only, besides the documents that file
  names. The merge conflicts with 1 and 2 are in `test/Main.hs` alone.
- On the machine: a watch at `--fachmann` of more than 55 minutes, which
  shows one renewal and the leave at the end. The renewal it fixes is a
  measurement, and goes in a dated `doc/`. It can be the web watch of
  session 5's dry run, if that one runs long enough.

## 4. `idm-drive`, after 1 and 2

- `IDM.Navigator.Drive`: `Command` over `Target 'Free`, the finals, the
  signals (`unix`), and the writable check per session.
- `app-drive/Main.hs`: the schedule's two needs, the watch and the driver,
  joined into one `drive`; `--check`; the events of `event-log.md`.
- `step`'s local `Command` replaced by the library's.
- `checks`: the finals in order 88, 4108, 74; no command to an EEPROM
  target. The second follows from the type, so it may be left out.
- Changelog for the module and the executable. Readme, "measurement tools",
  names `idm-drive` beside `drivepv.py` until session 5.

## 5. On the machine, then the switch

- A dry run that cannot start the pump, beside the web watch at
  `--fachmann` if 3b is in: B38 above `PV006`, or a constant
  `surplus = -0.5`. Run it for a few rounds, end it with SIGTERM, and see in
  the drive file that the finals went out in order and read back. The
  reconnect is the code `watch` has now, moved, and the run does not
  force one.
- Delete `tools/drivepv.py`. Switch the docs' "Reproducing" sections to
  `idm-drive HOST schedules/….toml`, and update `CLAUDE.md` (the commands,
  the architecture list, the measurement paragraph), `Readme.md`,
  `Changelog.md` and `captures/README.md`.
- Close this note into `closed/done`. Rank the clamp run first again in
  `todo/README.md`.

Then the clamp run, `pv-control-of-74-and-88`, step 1, with
`schedules/pv-clamp-0-1.toml`.
