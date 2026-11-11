# `idm-drive` replaces `drivepv.py`

**Done, 2026-11-11.** The dry run held on the machine: a SIGTERM ended a
run with the finals written in order and read back, and a second one did
not cut them short
(`doc/verification/2026-11-11-idm-drive-writes-its-finals-through-a-second-sigterm.md`,
with `schedules/dry-run.toml`). `tools/drivepv.py` is deleted; the eight
verifications name 7bc8367d7f42, the last commit that has it, and the run
of `what-ended-the-run-capped-at-1-0-before-pv006` is
`schedules/pv-limit-1-0.toml`. What follows is the plan as it stood.

`idm-drive` and `idm-web --watch --fachmann` are built, merged and reviewed,
and the web watch's renewal of the level has been measured on the machine
(`doc/verification/2026-11-11-the-web-watch-renews-the-fachmann-level.md`).
What is left: running `idm-drive` on the machine, then switching from
`tools/drivepv.py`. The clamp run, step 1 of `pv-control-of-74-and-88`
with `schedules/pv-clamp-0-1.toml`, waits for both.

## 1. A dry run on the machine

Waits for the user to start it.

- A schedule that cannot start the pump: B38 above `PV006`, or a constant
  `surplus = -0.5`. No schedule has been written for it yet. Running the web
  watch at `--fachmann` beside it is optional.
- Run it for a few rounds, end it with SIGTERM, and check in the drive file
  that the finals went out in the order 88, 4108, 74 and read back.
- Send a second SIGTERM during the finals, and check that they still
  complete.
- The run does not need to force a reconnect: `checks` cover it.

## 2. Delete `tools/drivepv.py`

- The eight verifications whose "Reproducing" calls it keep their commands:
  the old runs are not translated into schedules. Each one says that
  `drivepv.py` was deleted after commit X, the last commit that has it, and
  that `git show X:tools/drivepv.py` recovers it. They are
  `doc/verification/` 2026-11-06-pv-surplus-loop,
  2026-11-07-pv-target, 2026-11-07-pv-target-ignored,
  2026-11-07-power-limit, 2026-11-08-power-limit-cap,
  2026-11-09-power-limit-floor, 2026-11-09-power-limit-held-at-1-0 and
  2026-11-10-pv-loop-at-0-1-min-swings.
- `what-ended-the-run-capped-at-1-0-before-pv006` plans its run with
  `drivepv.py`. It needs a schedule in `schedules/` and an `idm-drive`
  command, with `--watch --fachmann` in place of `--enter-fachmann`.
- `CLAUDE.md` needs three changes:
  - The command list: `idm-drive` and `idm-drive --check` in place of
    `drivepv.py`.
  - The architecture list: it names neither `IDM.Navigator.Rounds`,
    `IDM.Navigator.Capture` nor `IDM.Navigator.Drive`, and neither of the
    private sublibraries `schedule` and `fachmann`.
  - The measurement paragraph: it should say why `idm-drive` is a
    measurement tool even though it ships with the package and computes
    74 from 4122. It runs a schedule fixed before the run, as `drivepv.py`
    did, and its step stays in the private sublibrary `schedule`.
- `Readme.md`: in "measurement tools", put `idm-drive` in `drivepv.py`'s
  place and state as done what "is to take the place of" promises. Update
  the table row too.
- `Changelog.md`: the deletion.
- `captures/README.md`: add the drive capture,
  `navigator-10-drive-SOFTWARE-YYYY-MM-DD-HHMM.jsonl`, and note that the
  write log of `tools/drivepv.py` is the old runs' log.
  `runtable.py --writes` stays for those logs.

## 3. Close

Close this note into `closed/done`. Rank the clamp run first in
`todo/README.md`.
