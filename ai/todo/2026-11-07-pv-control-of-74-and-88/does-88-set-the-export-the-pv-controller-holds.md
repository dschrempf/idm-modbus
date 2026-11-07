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

The run below also answers whether the loop settles at all when 74 is a
meter's export from the first write. The evening of 2026-11-06 could not
tell: its two-minute mean still held the 1.7 of the start when the
meter-style writes began.

## Before the run

Done on 2026-11-07: 88 is the target `PvTarget`, and `tools/drivepv.py`,
`tools/drive74.py` renamed, writes it at the start of a phase, and 0 to it
on exit before the final 74. Tried against a stub writer only.

1. Read 88 once: it should read 0.0, as in every scan.
2. Wait for the pump to stand idle and the store to be cool: the run takes
   about 30 minutes at about 2 kW, and the morning of 2026-11-06 rose 7 K in
   15 minutes at 3.9 kW. A start needs B38 below `PV006` less 13300, 36 °C;
   the run ends at `PV006`, 40 °C. Start at 31 °C or below. `PV006` stays
   at 40 °C.
3. `PV011` stays at 2.0 min, so that only 88 differs from the runs of
   2026-11-06.

## The run

At Kunde level for Modbus, the web at Fachmann level:

    cabal run idm-dump -- HOST --watch 10 74 88 1008 1090 1091 1100 1074 4122 1004 1098 > watch.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
    IDM_PIN=... cabal run idm-web -- HOST --watch 10 6245 10263 12763 > webwatch.jsonl
    tools/drivepv.py HOST watch.jsonl --final -0.5 --final-target 0 \
      2.0-4122/20/ein+720/0 2.0-4122/20/ein+1140/1.0 \
      2.0-4122/20/ein+1560/-1.0 2.0-4122/20/ein+1620/0 > write.log
    tools/runtable.py watch.jsonl --web webwatch.jsonl --writes write.log

74 is a meter of 2.0 kW of PV with the pump the only load, from the first
write to 27 minutes after the compressor starts. At rest it writes 2.0,
above the 1.7 that started a run.

| Phase | From the start | 88   | The draw, 4122, if 88 is the target | If 88 is ignored |
| ----- | -------------- | ---- | ----------------------------------- | ---------------- |
| a     | 0 to 12 min    | 0    | about 2.0 kW                        | about 2.0 kW     |
| b     | 12 to 19 min   | +1.0 | about 1.0 kW                        | about 2.0 kW     |
| c     | 19 to 26 min   | -1.0 | about 3.0 kW                        | about 2.0 kW     |
| d     | 26 min to end  | 0    | about 2.0 kW                        | about 2.0 kW     |

Phase a runs past the start program, about 3.5 minutes, and past the
minimum runtime, 10 minutes. 1.0 kW in phase b lies above the floor of
0.67 kW, 3.0 in phase c below the top of about 3.9.

What to read off:

- **Phase a: does the loop settle?** The draw near 2.0 kW and 74 near 0.
  If it oscillates instead, its period and amplitude; then compare each
  phase's mean draw rather than a settled one.
- **Phases b and c: does the draw follow 88?** If it does, the first 30 s
  after each step: a jump of the speed at once is the proportional share,
  in rps per kW of 88; the ramp after it, the integral's. If the speed
  only ramps, 88 goes through `PV011`'s mean like 74.
- **12763**: the controller's internal value of 74, the mean or the value
  written, and of 88 against the value written.
- **10263**: whether the PV page shows 88, or a target consumption.
- **Stops.** If the run stops while 74 sits near 0, note when, at which
  mean and which 88. A loop that settles at the stop condition cannot hold;
  that is a finding of its own, for "What stops it".

End: the driver writes 0 to 88 and -0.5 to 74 when its schedule ends, the
run stops or it is signalled. Check in the watch that 88 reads 0.0, stop
the watches, and leave the Fachmann level. Never end with 88 away from 0: a
negative 88 left behind asks for grid power with no one watching.

Record it in a dated `doc/`, and update `doc/pv-control.md`.

## The second run: a shorter `PV011`

On another idle, cool day, the same schedule with `PV011`, setting 10389,
0.1 to 360 min, at 0.5 min instead of 2.0: one EEPROM cycle at the display,
and one more to set it back, unless the run argues for keeping it. Write 74
every 10 s rather than 20, so the mean holds three writes, and pass
`--mean 30` to `tools/runtable.py`. It shows what the two-minute mean adds
to the overshoot: with the lag shorter, the draw should settle faster and
overshoot less. A shorter mean also weighs the start on a shorter surplus,
so the start may come sooner.

## Afterward, if 88 is the target

- **A start on 88 alone.** At rest, 74 as a meter with no PV, 0-4122, and
  88 at -1.7. A start would mean the start condition weighs 74 less 88 too,
  and a consumer can ask for a grid-powered charge at a chosen draw. Then 88
  at -1.0 for the floor.
- **88 left behind.** What a dead consumer leaves at 88 matters more than
  at 74: add 88 to `controller-behavior-when-glt-values-stop-unknown`.
