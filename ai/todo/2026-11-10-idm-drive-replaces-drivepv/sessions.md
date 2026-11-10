# Sessions

Sessions 1 to 3 need nothing from each other but the types and formats
pinned in `rounds-and-needs.md`, `schedule-file.md`, `event-log.md` and
`fachmann-in-the-web-watch.md`, "The level line", and 3b needs nothing
from any of them. All four can run at once, each in its own worktree, and
each commits before it returns. Session 4 joins 1 and 2, and session 5
needs the machine.

    1 rounds   ─┐
    2 schedule ─┼─ 4 idm-drive ── 5 machine, then delete drivepv.py ── clamp run
    3 tools    ─┘                 │
    3b fachmann ──────────────────┘

Conflicts to expect when merging:

- `idm-modbus.cabal`: 1 adds modules to the library, 2 and 3b each add a
  private sublibrary and a dependency of the test suite on it.
- `test/Main.hs`: 1, 2 and 3b append to `checks`.
- `lib/idm-modbus/IDM/Navigator/Table.hs`: 2 only, so none.
- `app/dump/Main.hs`: 1 only; 2 leaves it alone (`schedule-file.md`).

Merge 1 first, then 2, then 3b.

## 1. Library: rounds and capture

- `IDM.Navigator.Rounds` and `IDM.Navigator.Capture`, from `watch` and
  `watchLine` in `app/dump/Main.hs`, with `Asked`, `Round`, `RoundEvent` and
  `readRound` as `rounds-and-needs.md` pins them.
- `readRound` generic over its requests, and `checks` against a fake
  controller: a loss in mid-round, the reopening in the next round, a
  failed opening, the order of first mention.
- `idm-dump --watch` rebuilt on `rounds`, its lines printed from
  `ReadDone`, with unchanged output, checked by `checks` entries over
  literal samples.
- On the machine, optional and read-only: a short `idm-dump --watch` before
  and after the change, with the same line shape.
- Changelog: the two modules. Readme only if it names `watch`'s internals,
  which it doesn't.

## 2. Schedule: format, parser, step

- The private sublibrary `schedule`: the types, the TOML parser
  (`toml-parser` in the cabal file; check that `nix develop -c cabal build`
  finds it, and how it reports a leftover key), and `step`.
- The check that an address is readable, moved into
  `IDM.Navigator.Table` (`schedule-file.md`).
- The `checks` entries of `schedule-file.md`.
- `schedules/pv-clamp-0-1.toml`, the example, so the next run has its
  file.
- No `IDM.Navigator.Drive` yet. `step`'s `Command` is a local type until
  session 4 joins the two.

## 3. Tools, against the formats only

- `runtable.py` reads a drive file, and marks the level lines of a
  webwatch, as `event-log.md` says. It is tested on hand-written fixtures,
  made from the tables there and from "The level line", and still on an
  old watch and write log from `captures/`.
- `python3` in the dev shell's `nativeBuildInputs`, for the tools.
- No schedules for the old runs: they are not translated (`README.md`,
  R7).

## 3b. The Fachmann level in the web watch

- `idm-web --watch --fachmann`, as `fachmann-in-the-web-watch.md` says:
  the private sublibrary `fachmann` with the pure renewal decision and its
  `checks`, the option, and the level lines.
- `app/web/`, the new sublibrary, `idm-modbus.cabal` and `test/Main.hs`,
  besides the documents that file names.
- On the machine: a watch at `--fachmann` of more than 55 minutes, which
  shows one renewal and the leave at the end. The renewal it fixes is a
  measurement, and goes in a dated `doc/`. It can be the web watch of
  session 5's dry run, if that one runs long enough.

## 4. `idm-drive`, after 1 and 2

- `IDM.Navigator.Drive`: `Command` over `Target 'Free`, `Drive r`,
  `Finish r`, `DriveEvent`, the finals in `finally`, and the writable
  check per round.
- `app/drive/Main.hs`: the schedule's two needs, the watch and the driver,
  joined into one `drive`; `--check`; the events of `event-log.md`; the
  handlers for SIGINT and SIGTERM, with `unix`, in the executable only.
- `step`'s local `Command` replaced by the library's, and `registerArg`
  in `app/dump/Main.hs` pointed at the check in `IDM.Navigator.Table`.
- `checks`: the finals in order 88, 4108, 74; the finals after an
  exception from the step, against the fake controller of session 1; no
  command to an EEPROM target. The last follows from the type, so it may
  be left out.
- Changelog for the module and the executable. Readme, "measurement tools",
  names `idm-drive` beside `drivepv.py` until session 5.

## 5. On the machine, then the switch

- A dry run that cannot start the pump, beside the web watch at
  `--fachmann` if 3b is in: B38 above `PV006`, or a constant
  `surplus = -0.5`. Run it for a few rounds, end it with SIGTERM, and see in
  the drive file that the finals went out in order and read back. Send a
  second SIGTERM during the finals and see that they still complete. The
  reconnect is covered by session 1's `checks`, and the run does not force
  one.
- Delete `tools/drivepv.py`. The eight docs whose "Reproducing" calls it
  keep their commands, and each says that `drivepv.py` was deleted after
  commit X, where `git show X:tools/drivepv.py` recovers it, X the last
  commit that has it.
- `CLAUDE.md`: the commands, the architecture list, and the measurement
  paragraph, which says why `idm-drive` is a measurement tool though it
  ships with the package and computes 74 from 4122: it runs a schedule
  fixed before the run, as `drivepv.py` did, and its step stays in the
  private sublibrary `schedule`. Also `Readme.md`, `Changelog.md` and
  `captures/README.md`.
- Close this note into `closed/done`. Rank the clamp run first again in
  `todo/README.md`.

Then the clamp run, `pv-control-of-74-and-88`, step 1, with
`schedules/pv-clamp-0-1.toml`.
