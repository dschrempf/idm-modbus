# Work the open todos in eight sessions

The 20 todos of 2026-10-14, grouped so that one session covers one area of
code and makes the decisions its notes leave open. Order: 3, 1, 2, 4, 5, 6, 7;
8 fits anywhere. Close this entry when the last session is done; a todo added
later joins a session here or stands alone.

## 1. Websocket session correctness

Done on 2026-10-14.

`Web/Connection.hs`, `Web/Session.hs`. Both concern how `collect`, `drain` and
`guarded` wait, and the notes cite each other.

- `2026-10-14-late-answer-taken-for-a-repeat-sent-before-it-came`
- `2026-10-14-patience-timeout-duplicates-collect-deadline`

## 2. User level

Done on 2026-10-14: `enterFachmann` refuses at a level other than Kunde,
and each function returns a type of its own, `Entry` and `Exit`.

`Web/Level.hs` and `idm-web`'s report, which then changes once. After 1:
`Level` uses `drain`.

- `2026-10-14-fachmann-code-stale-at-the-turn-of-the-hour`
- `2026-10-14-enter-fachmann-at-an-unknown-level`
- `2026-10-14-level-change-conflates-unsent-and-unanswered`

## 3. Modbus client timeout and transaction id

Done on 2026-10-14: `connect` takes a `Patience`, and a read that leaves the
stream out of step ends the connection, `Ended` and then `Unsent`.

`Modbus/TCP.hs`. First, because `~/nix/config` is about to be the caller the
note warns of.

- `2026-10-14-modbus-client-has-no-timeout-or-transaction-check`

## 4. What a reading means

Done on 2026-10-14: `NotFitted` is `NoValue`, a `FLOAT` -1.0 is `NoValueOr`
where no documented range excludes it, and `Unitless` is gone.

`Register.hs`, public API. `Unit` is the other breaking change to its types;
the redundant case is in the function the sentinel fix rewrites.

- `2026-10-14-float-sentinel-swallows-averaged-outdoor-temperature`
- `2026-10-14-notfitted-overclaims-absence`
- `2026-10-14-unit-has-two-ways-to-say-none`
- `2026-10-14-table-header-claims-every-row-from-the-manual`, its "while
  there" half: `navigator`'s `(OneRegister, Count _)` case

## 5. Table pipeline

`Table.hs`, `tools/transcribe.py`, `test/Main.hs`. After 4, so a splice that
parses the table parses the final types; 4 and 5 can share one Changelog
entry. The zone-module fix regenerates the enums TSV, which the new count
check should cover.

- `2026-10-14-table-drops-unparseable-rows-silently`
- `2026-10-14-table-header-claims-every-row-from-the-manual`, the header half
- `2026-10-14-zone-modules-2-to-10-carry-no-enum-labels`

## 6. Web parsing against webprobe

`Web.hs`, `tools/webprobe.py`, `CLAUDE.md`. In each, the Haskell and the
Python side disagree, and one position goes.

- `2026-10-14-info-rows-keep-html-entities`
- `2026-10-14-redaction-differs-between-haskell-and-python`
- `2026-10-14-setting-detail-fence-differs-between-webprobe-and-library`

## 7. On the machine

Needs Dominik, the machine running, and Fachmann level. After 2, so entering
the level works, and after 6, so `idm-web --watch 4768` shows clean labels.

- `2026-10-14-heat-sink-registers-unchecked-against-display`
- `2026-10-14-gltmon-rows-not-joined-to-parameter-identifiers`: the webapi
  walk for 1520 to 1526, whether to write to settle 1534, and where the join
  rule lives

## 8. Housekeeping

Mostly Dominik's answers.

- `2026-10-14-eeprom-count-stated-four-times`
- `2026-10-14-first-scan-lacks-its-minute`
- `2026-10-14-house-address-remains-in-git-history`
