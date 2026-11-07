# Does 88 set the export the PV controller holds?

## The question

A PI controller sets the speed of a PV run: gains `IV017` to `IV019`, P 5.0,
I 10.0, D 0.0. Both runs of 2026-11-06 fit an error of the mean of 74 over
`PV011` less a target of 0. 88, `PV-Zielwert (Smartfox und Solar-Log)`, was
the candidate for that target. If it were, a consumer would write the
meter's export to 74 as it is and its intent to 88. `doc/pv-control.md`,
"What 88 would add", has the argument.

## Answered: not for the speed

Three runs on 2026-11-07, `doc/verification-2026-11-07-pv-target.md` and
`doc/verification-2026-11-07-pv-target-ignored.md`:

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
level. Never end with 88 away from 0. End a schedule on `aus` rather than a
time, so the driver's -0.5 does not end a run the controller would hold.

## Next: a shorter `PV011`

On an idle, cool day, a meter-style run with `PV011`, setting 10389, 0.1 to
360 min, at 0.5 min instead of 2.0: one EEPROM cycle at the display, and one
more to set it back, unless the run argues for keeping it. Write 74 every
10 s rather than 20, so the mean holds three writes, and pass `--mean 30` to
`tools/runtable.py`. The PV the meter simulates is near the floor's draw,
0.8 kW, so a loop that settles settles low; 2.0 for the start, which 0.8
would not give:

    tools/drivepv.py HOST watch.jsonl --final -0.5 --final-target 0 \
      2.0/10/ein/0 0.8-4122/10/aus > write.log

It shows what the two-minute mean adds to the overshoot: with the lag
shorter, the draw should settle faster and overshoot less. Whether a loop
settled at a mean near 0 runs past the minimum runtime is the other half:
74 at 0 did not. A shorter mean also weighs the start on a shorter surplus,
so the start may come sooner.

## 88 left behind

What a dead consumer leaves at 88 matters only if 88 acts on something;
it does not belong in `controller-behavior-when-glt-values-stop-unknown`
unless a run shows that.
