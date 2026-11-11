# `idm-drive` writes its finals in order on SIGTERM, and through a second one

2026-11-11, evening, on 20.24-2608. Two dry runs of `idm-drive` with
`schedules/dry-run.toml`, to see on the machine what the checks see
against a fake controller: that a SIGTERM ends a run with the finals
written to 88, 4108 and 74 in this order, each read back, and that a
second SIGTERM during the finals does not cut them short. Times are the
host's.

Both held: each run wrote its three finals in order, each `confirmed`,
and ended with `why: signal` and exit status 143, 128 and SIGTERM.

## What was done

The schedule holds 74 at -0.5, an import the PV control does not start
the pump on, 88 at 0.0 and 4108 at -1.0, for at most 600 s, and has the
same values as its finals. A read just before the runs found the three
registers at those values and the compressor off, 1100 at 0, so the runs
left the machine as they found it.

- From 21:06:22, a run ended by one SIGTERM 45 s after its start
  (`captures/navigator-10-drive-20.24-2608-2026-11-11-2106.jsonl`).
- From 21:08:20, a run ended by a SIGTERM 25 s after its start, and a
  second one 0.3 s after the first
  (`captures/navigator-10-drive-20.24-2608-2026-11-11-2108.jsonl`).

Nobody touched the display.

## What the runs read and wrote

Every read of the 13 registers the schedule watches answered, in 5 rounds
of the first run and 3 of the second. 1100 read 0 and 4122 read 0.0
throughout, and 74, 88 and 4108 the schedule's values.

The phase wrote 88, 4108 and 74 at its start, and 4108 and 74 every round
after; every write was `confirmed`. The ends:

| Run   | `signal`     | 88           | 4108         | 74           | `end`        |
| ----- | ------------ | ------------ | ------------ | ------------ | ------------ |
| 21:06 | 21:07:07.466 | 21:07:07.638 | 21:07:07.962 | 21:07:08.293 | 21:07:08.444 |
| 21:08 | 21:08:45.433 | 21:08:45.609 | 21:08:45.966 | 21:08:46.294 | 21:08:46.445 |

A `final` line follows each `signal` line within a millisecond, and each
final write is `confirmed`. The second SIGTERM of the 21:08 run arrived
between the confirmations of 88 and 4108. It left no line: after the
first signal, `idm-drive` ignores SIGINT and SIGTERM, so the finals ran
to the end as in the first run: 74 was confirmed 0.86 s after the first
signal, against 0.83 s there.

## What it settles

- **A SIGTERM ends a run on the machine with the finals written and read
  back**, in the order 88, 4108, 74.
- **A second SIGTERM during the finals is ignored**, and leaves no line.

## What it does not settle

- **The other ends of a run on the machine**: the end of the schedule,
  the compressor's stop, an error, and a lost connection. The checks of
  `test/Main.hs` cover them against a fake controller.
- **A phase that writes anything but the finals' values**, and so whether
  the finals restore a value the run changed.

## Reproducing

    idm-drive HOST schedules/dry-run.toml > drive.jsonl & pid=$!
    sleep 45; kill -TERM $pid

and for the second run

    idm-drive HOST schedules/dry-run.toml > drive.jsonl & pid=$!
    sleep 25; kill -TERM $pid; sleep 0.3; kill -TERM $pid

with the binary `cabal list-bin idm-drive` names, so that the signal
reaches it and not `cabal`.
