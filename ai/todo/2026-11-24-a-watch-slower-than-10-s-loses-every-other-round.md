# A watch slower than 10 s loses every other round

On 2026-11-24, `idm-dump HOST --watch 20` with eight registers failed
every other round. The round at 21:29:25 read all eight. The next, at
21:29:44.67, 18.3 s after the last read, answered the first read with
`"status": "error"` and wrote `connection closed`, and its other seven
read as errors with no software. The round after that opened a new
session and read all eight. The pattern repeated over two minutes
(`captures/navigator-10-watch-20.24-2608-2026-11-24-2129.jsonl`, and
`connection closed` in the `.stderr` beside it).

The reading so far: the controller closes a Modbus TCP connection after
some idle time between 10 s and 18 s, and `IDM.Navigator.Rounds` notices
only at the next read. Its rule is that "a lost connection ends the
session and the round, and the next round opens a new one" (`CLAUDE.md`),
so a round that finds the connection gone reads nothing.

No capture shows it, because every one so far ran at 10 s or faster:
the 20 watch captures from 2026-10-01 to 2026-11-11 at 5 or 10 s, and
every `idm-drive` schedule in `schedules/` at `round = 10`. Errors in two
of them (10-15 1418, 9 errors at 5 s; 11-07 2120, 11 errors at 10 s) have
some other cause, to check.

## Why it comes first

- The overnight watch of `what-ae026-governs-and-whether-it-runs-the-charge-pump`
  runs at 60 s; as things stand it would read every 120 s.
- The "Open" section of `doc/verification/2026-11-06-frost-protection.md`
  suggests a `--watch 60`.
- A schedule with a `round` above the timeout would have `idm-drive` skip
  every other round, and its step decide on stale reads.
- A consumer reading at a minute's pace, as a manager would, meets it
  first.

## To settle

1. **The timeout.** Watch at 11, 12, …, 18 s, a single register, and find
   where the failures begin. Whether a read at any pace keeps the
   connection open, or the controller closes it after a fixed lifetime,
   decides the fix too: a watch at 10 s for an hour with no error says
   idle.
2. **Whether `idm-web --watch` has the same**, on its websocket.
3. **The fix, a design choice to raise before building.** Options: reopen
   and retry once within the round when the first read finds the
   connection closed; close the session after each round and open one per
   round; or a keep-alive read below the timeout. `IDM.Modbus.TCP.Internal`
   ends the connection on a request that leaves the stream out of step,
   and a retry must not resend a write: only a read may retry.
4. A measurement in `doc/verification/`, the timeout in `doc/modbus.md`
   beside `pollIntervalMicroseconds`, and a check in `test/Main.hs` against
   the loopback listener that closes an idle connection.
