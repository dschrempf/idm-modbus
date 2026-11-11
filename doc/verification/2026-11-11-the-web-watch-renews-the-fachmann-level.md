# The web watch renews the Fachmann level at 55 minutes, and holds it for 70

2026-11-11, morning, on 20.24-2608. A web watch at `--fachmann`, 70
minutes long, to see on the machine what `idm-web --watch --fachmann`
does with the level: one entry, one renewal, and the leave at its end.
Times are the host's.

The renewal took: the watch left the level 55 minutes after its entry,
entered again 39 s later, and held Fachmann to its end, past the sixty
minutes of the first entry. In the pause between the two, 5888 and 6245
answered at once that the level does not reach them.

## What was done

`idm-web --status` read Kunde at 07:40. Then, from 07:40 to 08:50, a web
watch every 10 s of 4768 `N2_SENSORS`, 5888 `N2_EVR_OVERVIEW` and 6245
`N2_MODULATION_OVERVIEW`, with `--reason` and `--fachmann`, ended after
70 minutes by a SIGINT from `timeout`
(`captures/navigator-10-webwatch-20.24-2608-2026-11-11-0740.jsonl`).
Nobody touched the display.

## What the watch read

Its level lines:

| Time     | `level`   | `userLevel` |
| -------- | --------- | ----------- |
| 07:40:37 | `entered` | Fachmann    |
| 08:35:38 | `leaving` | Kunde       |
| 08:36:17 | `renewed` | Fachmann    |
| 08:50:36 | `left`    | Kunde       |

The leave came 55:01 after the entry, the next entry 39 s after the
leave: the 30 s gap and the wait for the next round. No line says
`fell-back` or `failed`: the level held from each entry to the next
leave, and the first entry after the gap took.

The watch made 420 rounds, and every overview and every read of 4768
answered. 5888 and 6245 answered their tables in every round but the four
from 08:35:39 to 08:36:06, the pause, where each answered "setting item
[5888] is not accessible!", 6245 likewise, rather than stalling. From
08:40:37 on, after the sixty minutes of the first entry, they answered
their tables to the last round, at 08:50:25.

## What it settles

- **The watch holds the level through a renewal without a person**: it
  enters from Kunde, leaves at 55 minutes, enters again after the gap,
  and leaves on SIGINT.
- **A gap of 30 s is enough** for the next entry to take, as 20 s was on
  2026-11-10 (`captures/navigator-10-level-20.24-2608-2026-11-10-2056.log`).
- **At Kunde, 5888 and 6245 answer "not accessible" at once**, so a run
  loses only the pause's rounds of them.

## What it does not settle

- **The watch's other paths on the machine**: a level that falls back on
  its own, an entry that does not take, giving up after three. The checks
  of `decide` cover them against no machine.

## Reproducing

    IDM_PIN=... timeout -s INT 70m idm-web HOST --watch 10 --reason --fachmann 4768 5888 6245 > webwatch.jsonl

from the level at Kunde, the binary `cabal list-bin idm-web` names, so
that the SIGINT reaches it and not `cabal`.
