# The charge pump's signal is at 1074, not 1104

2026-10-16. The heat sink's charge pump, M73, has two candidate registers:
1104, `Status Ladepumpe (M73)`, from the parameter list, and 1074,
`Ladepumpe Wärmesenke Steuersignal`, from the controller's register page
([verification-2026-10-14-gltmon.md](verification-2026-10-14-gltmon.md)).
On 2026-10-15 they disagreed while the machine heated: 1104 read `ffff`, 1074
93 to 97 ([verification-2026-10-15-heat-sink.md](verification-2026-10-15-heat-sink.md)).
Read beside the page that prints M73, at rest, through a heating run, a hot
water charge and a defrost, 1074 follows M73 read for read: its `ffff` is the
page's -1.0, "not driven", and its 0 the page's 0, minimum speed. 1104 reads
`ffff` throughout.

## What was recorded

|             |                                                                                                                                                  |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Registers   | `captures/navigator-10-watch-20.24-1574-2026-10-16-0745.jsonl`: 1072, 1074, 1090, 1100, 1104, 4108, 4112, 4122, 4126                            |
| Web backend | `captures/navigator-10-webwatch-20.24-1574-2026-10-16-0748.jsonl`: 4782 `N2_ANALOGUE_OUTPUTS`, 12763 `N2_GLTMON`, 6245 `N2_MODULATION_OVERVIEW` |
| Interval    | 10 s, both                                                                                                                                       |
| User level  | Fachmann, entered at 07:47:58, renewed by leaving and entering it again: `captures/navigator-10-level-20.24-1574-2026-10-16-0748.log`           |
| Span        | 07:45 to 10:30                                                                                                                                   |

Times are the laptop's. None of the 8874 register reads failed. Of the 2910
web requests, 23 to 12763 and 6245 got no answer, in the two stretches the
controller stood at Kunde while the level was renewed, from 08:43:09 to
08:45 and around 09:40; 4782 answered at Kunde as well. Nothing was set but
the user level.

| Time              | 1090             | 1100                    |
| ----------------- | ---------------- | ----------------------- |
| 07:45–08:10:02    | 0, `Aus`         | 0                       |
| 08:10:12–08:54:43 | 1, `Heizbetrieb` | 1 from 08:11:02         |
| 08:54:53–09:59:33 | 0                | 0                       |
| 09:59:43–10:10:23 | 4, `Warmwasser`  | 1 from 10:02:03         |
| 10:10:33–10:18:53 | 8, `Abtauung`    | 1 from 10:12:53         |
| 10:19:03–10:30    | 4                | 0, then 1 from 10:22:23 |

## The start

| Time              | 1090 | 1074   | 1104   | 1072, l/min | 1100 | 4122, kW  |
| ----------------- | ---- | ------ | ------ | ----------- | ---- | --------- |
| 07:45–08:10:02    | 0    | `ffff` | `ffff` | 0           | 0    | 0         |
| 08:10:12          | 1    | 100    | `ffff` | 0           | 0    | 0         |
| 08:10:22–08:10:52 | 1    | 100    | `ffff` | 32.7–33.1   | 0    | 0         |
| 08:11:02          | 1    | 100    | `ffff` | 32.9        | 1    | 0         |
| 08:11:12–08:11:32 | 1    | 60     | `ffff` | 23.2–23.4   | 1    | 0.29–0.83 |
| 08:11:42 on       | 1    | 63–100 | `ffff` | rising      | 1    | rising    |

The pump's signal rises in the round where 1090 turns to `Heizbetrieb`, the
flow follows one round later, and the compressor, 1100, starts 50 s after
the pump; 4122 leaves 0 one round after that.

## The stop

| Time     | 1090 | 1074   | M73 on 4782, 4–6 s later | 1072, l/min | 1100 |
| -------- | ---- | ------ | ------------------------ | ----------- | ---- |
| 08:54:43 | 1    | 94     | 94.0                     | 32.1        | 1    |
| 08:54:53 | 0    | 94     | 94.0                     | 32.1        | 0    |
| 08:55:03 | 0    | 94     | -1.0                     | 31.8        | 0    |
| 08:55:13 | 0    | `ffff` | -1.0                     | 0           | 0    |

The compressor and the mode stop together; the pump's signal goes to -1 one
round later, and the flow with it. The defrost ended the same way at
10:19:03, from 100.

## 1074 is M73

The page 4782 printed M73 970 times. 915 readings equal the 1074 read before
them, 27 the one after. The other 28 fall in ramps, where the signal moved
up to 6 points between two reads, and lie between their two neighbors. No
-1.0 on the page stands beside anything but `ffff` on 1074, and nothing else
beside `ffff`.

12763 `N2_GLTMON`, the register page, prints its own value for 1074, and
agrees in the same way: 927 of 958 values equal a neighboring read, the
other 31 in ramps, and -1.0 exactly where the register answered `ffff`. That
is the controller reading its own register 1074 as signed.

So 1074 is M73's control signal on the pump scale of
[verification-2026-09-20.md](verification-2026-09-20.md): `ffff` is -1, the
pump not driven, and a value is percent of the pump's speed range. It read
0 to 100. 0 is a state of its own: at the start of each hot water charge,
from 10:01:52 and from 10:22:03, 1074 and the page stood at 0, minimum speed,
for four to five minutes, while 1072 read no flow and the compressor ran;
then the signal jumped to 73 to 100 and the flow to 32 l/min. On the wire
that is `0000` against the `ffff` of a pump not driven, the distinction
`Drive` draws between `Driven 0` and `NotDriven`.

## 1104 does not follow M73

1104 answered all 986 reads with `ffff`: at rest, at 0 % and while the page
printed M73 at up to 100 %. On this machine 1104 answers
and does not report the pump it names; the table decodes it as
`DriveSignal NotDriven` while the pump is driven at 100 %. Whether software
20.24 stopped updating it, or this configuration drives M73 through another
channel, the run cannot say. The parameter list documents 20.21-101
([research.md](research.md), "Revision drift").

What this does not explain is 2026-09-20, when the page printed M73 at -1.0
while the `Digitalausgänge` page showed the same pump on: a pump running with
no control signal. Today the signal rose with the pump in every mode the machine ran.

## What follows for the table

Nothing changes yet. The table decodes 1074 as `Count 65535` at rest and
1104 as `NotDriven` throughout. Decoding 1074 as `DriveSignal` takes a
datatype, a range and a unit its `gltmon` row cannot state, and marking 1104
as a register that answers without following needs a constructor and a way
for a watch to enter the table. Both are a question of what
`tools/transcribe.py` takes in besides the manual.

## Reproducing

    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
    IDM_PIN=... cabal run idm-web -- HOST --watch 10 4782 12763 > webwatch.jsonl
    cabal run idm-dump -- HOST --watch 10 1072 1074 1104 > watch.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --leave-fachmann

across the start or stop of a run. The level lasts sixty minutes; renewing
it right after leaving it failed once on 2026-10-16, and succeeded after a
20 s pause.
