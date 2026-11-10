# Does 88 set the export the PV controller holds?

## The question

A PI controller sets the speed of a PV run: gains `IV017` to `IV019`, P 5.0,
I 10.0, D 0.0. Both runs of 2026-11-06 fit an error of the mean of 74 over
`PV011` less a target of 0. 88, `PV-Zielwert (Smartfox und Solar-Log)`, was
the candidate for that target. If it were, a consumer would write the
meter's export to 74 as it is and its intent to 88. `doc/pv-control.md`,
"The PV target at 88", has the argument.

## Answered: not for the speed

Three runs on 2026-11-07, `doc/verification/2026-11-07-pv-target.md` and
`doc/verification/2026-11-07-pv-target-ignored.md`:

- The planned meter-style run, 74 as a meter of 2.0 kW from the first write,
  stopped after 8 minutes, before its first step of 88: the loop does not
  settle with `PV011` at 2.0 min.
- With 74 held at 0 and the speed steady at 50.4 rps, 88 at -1.0 for 3
  minutes moved nothing, 6 to 9 minutes after the start, and neither did
  +1.0 for 3 minutes, 5 to 8 minutes after it, in the evening.
- 88 at +1.0, written 9 minutes after the start at noon, was followed by a
  fall to the floor and a stop at the end of the minimum runtime. In the
  evening the stop came at the same time with 88 at 0, without the fall.

Not settled: whether 88 weighs in a start or a stop, and what the fall at
noon was. Neither is worth a run of its own now; a run that tests 88 at the
start costs a cycle that holds nothing low.

Both settings stayed: `PV006` 40 °C, `PV011` 2.0 min.

## Before each run

- The pump idle, B38 at 31 °C or below: a start needs B38 below `PV006`
  less 13300, 36 °C, and the run ends at `PV006`, 40 °C.
- At least 30 minutes since the last PV stop: the second start of
  2026-11-07 came 29 min 59 s after the first run's stop.
- 88 reads 0.0.

The watches and the end as on 2026-11-07: the driver writes 0 to 88 and
-0.5 to 74 when its schedule ends, the run stops or it is signalled. Check
in the watch that 88 reads 0.0, stop the watches, and leave the Fachmann
level; with `idm-web --watch --fachmann` (`idm-drive-replaces-drivepv`),
stopping the web watch leaves it. Never end with 88 away from 0. End a
schedule on the stop, `until = "stop"`, rather than a time, so the
driver's -0.5 does not end a run the controller would hold.

## Run: `PV011` at its minimum

Run on the evening of 2026-11-10 with the schedule of
`doc/verification/2026-11-10-pv-loop-at-0-1-min-swings.md`, "Reproducing":
2.0 until the start, the export of 2.0 kW of PV for 6 minutes after it, then
steps down every 3 minutes. The loop swung rather than settled, and the run
ended at 8 minutes, in the first step. `PV011` stays at 0.1 min.

## Next: the clamp

74 written as the export clamped to ±0.1 kW, every 10 s: beyond the band
the controller sees only the sign, and the integral moves the speed at a
fixed, slow rate. Smoothing the export instead would add lag, which is what
the mean of 2.0 min did. A clamp is a choice a consumer would make; written
as a fixed schedule it stays a measurement.

The driver for it is `idm-drive`, not `drivepv.py`
(`idm-drive-replaces-drivepv`). Its schedule, `schedules/pv-clamp-0-1.toml`,
is that note's example: the PV held longer than on 2026-11-10, 2.0 to 12
minutes after the start, past the stop at 8 and the minimum runtime at 10,
then 1.5, 1.2 and 1.0, the last until the stop.

    IDM_PIN=... cabal run idm-web -- HOST --watch 10 --reason --fachmann 4768 5888 6245 10263 12763 10389 > webwatch.jsonl
    cabal run idm-drive -- HOST schedules/pv-clamp-0-1.toml > drive.jsonl
    IDM_PIN=... tools/webprobe.py HOST > webapi.json

What to read: the swing's amplitude and period against 2026-11-10, the mean
at 8 minutes and whether the run passes it, and the PV below which the run
ends. If the swing stays, lower gains are next (`README.md`, step 2).

## 88 left behind

What a dead consumer leaves at 88 matters only if 88 acts on something;
it does not belong in `controller-behavior-when-glt-values-stop-unknown`
unless a run shows that.
