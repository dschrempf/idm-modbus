# `idm-drive` replaces `drivepv.py`

`tools/drivepv.py` packs a phase into one argument, `2.0-4122/20/ein+720/0`,
and the clamp the next PV run needs would make that language worse. It also
tails the file of a separate `idm-dump --watch` and starts `idm-write`, a new
connection, for every write. The runs need the driver a lot, and the loop
under it is what idm-manager will need too. So the driver becomes Haskell:
a library loop that reads, for everyone, what each part of a program
needs; a schedule file; and an executable `idm-drive` that runs the
schedule.

## Decided on 2026-11-10

- **D1.** The driver is written in Haskell. The loop is interface and goes
  in the library. The schedule is a measurement and goes in a private
  sublibrary and the executable. New dependencies go into the cabal file,
  which `shellFor` brings into the dev shell. The Python tools get
  `python3` in the shell as well.
- **D2.** One persistent session. The driver reads 1100 and 4122 itself
  instead of tailing a watch file, and writes through `write`, not
  `idm-write`.
- **D3.** A schedule file, not a language on the command line and not
  options: `schedule-file.md`.
- **D4.** A JSONL event log: `event-log.md`.
- **D5.** `tools/drivepv.py` is deleted once `idm-drive` has made a run.
  The docs' "Reproducing" commands are not translated (R7).
- **D6.** Every part of a program names the registers it needs. The loop
  reads the union of those registers once per round and hands each part
  what it asked for. `idm-drive` gets the watch and the driver in one
  process, one session and one capture, and `idm-dump --watch` is the same
  loop with the watch alone: `rounds-and-needs.md`.
- **D7.** Build it right first, then run the clamp run with it. No
  stopgap in `drivepv.py`.

## Settled on 2026-11-10, after the proposal

1. **TOML**, read with `toml-parser`. It allows comments and is easy to
   write by hand; the flake's nixpkgs has 2.0.2.0, not marked broken
   (`schedule-file.md`).
2. **One output stream.** The reads keep the exact line format of
   `idm-dump --watch`, and an event is a line with an `event` field, which
   a reader of a watch skips (`event-log.md`).
3. **Schedules tracked in `schedules/`**, each doc citing its file by path
   (`schedule-file.md`).
4. **One shared period for every need to begin with**, the schedule's
   `round`. The design stays open to a period per need
   (`rounds-and-needs.md`, "Periods").
5. **The Fachmann level is held by the web watch, not the drive.** Only
   the web channel has a user level, and the drive writes over Modbus.
   `idm-web --watch --fachmann` enters the level, renews it, and leaves it
   on every exit. It is session 3b (`fachmann-in-the-web-watch.md`).

## Settled on 2026-11-10, after the review

- **R1.** A round is a list of reads, each with its own time and session.
  Writes are not part of a round: the drive reports each as an event
  (`rounds-and-needs.md`).
- **R2.** One primitive reads one round and hands the session back;
  `rounds` and `drive` are loops over it, and it is tested against a fake
  controller.
- **R3.** No new name clashes: the drive's end is `Finish r`, with the
  step's own reason, so `Ending` stays the lost connection's; the read's
  outcome is `Asked`, so `Outcome` stays the write's.
- **R4.** The library prints nothing. Rounds and drive report events
  through a callback, and the executables print them.
- **R5.** Signals are handled in the executable: handlers for SIGINT and
  SIGTERM from `unix` that set both to `Ignore`, and the finals in
  `finally`, under the interruptible mask, so their timeouts still work.
- **R6.** The start is the first round in which 1100 reads Ein, as in
  `drivepv.py` (`schedule-file.md`).
- **R7.** The old runs are not translated into schedules. The docs keep
  their `drivepv.py` commands and name the last commit that has it.
- **R8.** The renewal decision of the web watch goes in a private
  sublibrary, `fachmann`, which the test suite reaches.
- **R9.** `idm-drive` ships with the package; `CLAUDE.md` says why it is a
  measurement tool (`sessions.md`, session 5).
- **R10.** A web watch that fails to enter the level three times in a row
  keeps reading at Kunde and tries no more
  (`fachmann-in-the-web-watch.md`).

## Where it stands

Sessions 1 to 4 are merged (2026-11-10). Session 5 waits for the user to
start the runs on the machine: the dry run of `idm-drive` and the web watch
at `--fachmann` of more than 55 minutes. Settled while building:

- The loss of a round is `Dropped Ending`: `Ending` has a `Lost` (R3).
- A span (`every`, `for`, `after-start`) passes half a period early, at the
  round nearest it, since the 1100 read lands a moment early or late.
- `idm-drive` steps the schedule only in a round with a writable session,
  so a phase's 88, sent in its first round only, is not lost to a round
  that could not write.
- The rest each session's commit message or Haddock states: `driveWith` in
  IO, `SkipReason` `NoSession | SoftwareDiffers`, exit codes 0, 128+n and 1,
  and, in the web watch, an exit where the first connection fails, a
  `userLevel` of `null` for a failure on the wire, and no level read after
  giving up.

Reviewed on 2026-11-10, and the review's fixes merged the same day:

- An exception that interrupts a request ends the connection, as
  `Abandoned` (be28714). Its test, a loopback listener, is
  `test-that-an-interrupted-request-ends-the-connection`.
- Once the finals begin, nothing thrown stops them: a write or an opening
  that throws counts as the session lost, within the three openings; a
  report that throws is passed over and thrown again after them; and an
  exception in the finals of a drive that had finished makes it
  `Interrupted`, so a signal at the schedule's end still exits 128+n
  (0c015c7). A signal that lands while a report blocks is thrown again as
  the report's failure, and `idm-drive` then exits 1 (the Haddock of
  `driveWith`).
- The signal handler interrupts the drive also where its line cannot be
  written (916752c).
- The event lines are in `IDM.Navigator.Schedule.Log`, in the private
  sublibrary `schedule`, checked against `tools/fixtures/drive.jsonl`;
  the fixture was corrected where it departed from `event-log.md`
  (dc81cf1).
- A round that cannot write is not stepped, so outside the finals it
  leaves no `skip`, and a drive on other software runs until a signal
  (`event-log.md`; b7b33cc).
- Kept: a final whose read-back lost the connection goes again, though the
  controller acknowledged it.

## Files

- `rounds-and-needs.md`: the loop of D6 and what goes in the library. It
  covers reconnecting, the drive on top of it with its final values and
  signals, and why the schedule stays out of the library.
- `schedule-file.md`: the TOML format, its Haskell types, the pure step
  function the tests run, and the clamp run's schedule as the example.
- `event-log.md`: the lines `idm-drive` writes, and what `runtable.py`
  reads of them.
- `fachmann-in-the-web-watch.md`: `idm-web --watch --fachmann`, which
  enters the level, renews it before the controller's sixty minutes are up,
  and leaves it.
- `sessions.md`: the sessions, which of them can run in parallel, and what
  each one hands to the next.

## Outside this folder

- `pv-control-of-74-and-88`: its step 1, the clamp run, waits for this.
- idm-manager's `manager-inputs-outputs-and-algorithm-sketches`: "a pure
  function `plan`; IO only around it". The drive loop is that IO, and the
  manager's plan takes the schedule's place.
- idm-manager's `record-every-input-before-controlling`: a recorder that is
  a need beside the manager's own.
