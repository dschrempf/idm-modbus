# Does 88 set the export the PV controller holds?

## The question

A PI controller sets the speed of a PV run: gains `IV017` to `IV019`, P 5.0,
I 10.0, D 0.0. Both runs of 2026-11-06 fit an error of the mean of 74 over
`PV011` less a target of 0. 88, `PV-Zielwert (Smartfox und Solar-Log)`, is
the candidate for that target. If it is, a consumer writes the meter's
export to 74 as it is and its intent to 88: +0.5 leaves 0.5 kW unused, and
-1.0 draws 1.0 kW from the grid, a store charge at low power without
inventing a surplus. `doc/pv-control.md`, "What 88 would add", has the
argument and what 88 would not change.

## Where it stands

Two runs on 2026-11-07, `doc/verification-2026-11-07-pv-target.md`:

- The planned run, 74 as a meter of 2.0 kW from the first write, stopped
  after 8 minutes, before its first step of 88: the loop does not settle
  with `PV011` at 2.0 min.
- With 74 held at 0 and the speed steady at 50.4 rps, 88 at -1.0 moved
  nothing in 3 minutes. 88 at +1.0, written 9 minutes after the start, was
  followed by a fall and a stop at the end of the minimum runtime, so it
  does not settle whether 88 acts.

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
level. Never end with 88 away from 0.

## Next: +1.0 apart from the minimum runtime

74 at 0 from the compressor's start, 88 at +1.0 from 5 minutes, past the
start program of about 4, until 8, then 0 past the 10 minutes of the
minimum runtime:

    tools/drivepv.py HOST watch.jsonl --final -0.5 --final-target 0 \
      2.0/20/ein/0 0/20/ein+300 0/20/ein+480/1.0 0/20/ein+780/0 > write.log

- A fall under +1.0, before the minimum runtime, says 88 acts on the
  speed; a stop then, on the stop condition. A ramp rather than a jump says
  it goes through `PV011`'s mean like 74.
- Nothing under +1.0, and a stop near 10 minutes under 0: 88 is ignored,
  and 74 at 0 ends a run once the minimum runtime is over, against the
  morning of 2026-11-06, when 0 held 120 rps past it.
- Nothing under either, and the run holds to 13 minutes: 88 is ignored, and
  2026-11-07's stop was the minimum runtime's.

## Then: a shorter `PV011`

On another idle, cool day, the first schedule of 2026-11-07 with `PV011`,
setting 10389, 0.1 to 360 min, at 0.5 min instead of 2.0: one EEPROM cycle
at the display, and one more to set it back, unless the run argues for
keeping it. Write 74 every 10 s rather than 20, so the mean holds three
writes, and pass `--mean 30` to `tools/runtable.py`:

    tools/drivepv.py HOST watch.jsonl --final -0.5 --final-target 0 \
      2.0-4122/10/ein+720/0 2.0-4122/10/ein+1140/1.0 \
      2.0-4122/10/ein+1560/-1.0 2.0-4122/10/ein+1620/0 > write.log

It shows what the two-minute mean adds to the overshoot: with the lag
shorter, the draw should settle faster and overshoot less. If it settles,
the steps of 88 come on a settled loop. A shorter mean also weighs the
start on a shorter surplus, so the start may come sooner.

## Afterward, if 88 acts

- **A start on 88 alone.** At rest, 74 as a meter with no PV, 0-4122, and
  88 at -1.7. A start would mean the start condition weighs 74 less 88 too,
  and a consumer can ask for a grid-powered charge at a chosen draw. -1.0
  did not move a running charge, so a negative target may be clamped at 0;
  this tests the same for the start.
- **88 left behind.** What a dead consumer leaves at 88 matters more than
  at 74: add 88 to `controller-behavior-when-glt-values-stop-unknown`.
