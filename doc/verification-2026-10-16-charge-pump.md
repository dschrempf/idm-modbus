# The charge pump's signal is at 1074, not 1104

2026-10-16. The heat sink's charge pump, M73, has two candidate registers:
1104, `Status Ladepumpe (M73)`, from the parameter list, and 1074,
`Ladepumpe Wärmesenke Steuersignal`, from the controller's register page
([verification-2026-10-14-gltmon.md](verification-2026-10-14-gltmon.md)).
On 2026-10-15 they disagreed while the machine heated: 1104 read `ffff`, 1074
93 to 97 ([verification-2026-10-15-heat-sink.md](verification-2026-10-15-heat-sink.md)).
Read beside the page that prints M73, at rest and across the start of a
heating run, 1074 follows M73 read for read, and its `ffff` is the page's
-1.0, "not driven". 1104 reads `ffff` throughout.

## What was recorded

|             |                                                                                                                                       |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Registers   | `captures/navigator-2.0-watch-2026-10-16-0745.jsonl`: 1072, 1074, 1090, 1100, 1104, 4108, 4112, 4122, 4126                            |
| Web backend | `captures/navigator-2.0-webwatch-2026-10-16-0748.jsonl`: 4782 `N2_ANALOGUE_OUTPUTS`, 12763 `N2_GLTMON`, 6245 `N2_MODULATION_OVERVIEW` |
| Interval    | 10 s, both                                                                                                                            |
| User level  | Fachmann, entered at 07:47:58, renewed by leaving and entering it again: `captures/navigator-2.0-level-2026-10-16-0748.log`           |

Both watches run to 10:30, through the stop of the run; this document covers
07:45 to 08:17. Times are the laptop's; the controller's clock ran about 90 s
ahead of it. Of 1710 register reads and 527 web requests none failed. Nothing
was set but the user level.

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

## 1074 is M73

The page 4782 printed M73 176 times. 154 readings equal the 1074 read before
them, 15 the one after. The other 7 fall in the ramp from 08:11 to 08:17,
where the signal moved up to 6 points between two reads, and lie between
their two neighbors. No -1.0 on the page stands beside anything but `ffff`
on 1074, and nothing else beside `ffff`.

12763 `N2_GLTMON`, the register page, prints its own value for 1074, and
agrees in the same way: -1.0 at every read where the register answered
`ffff`, and 169 of 176 values equal to a neighboring read, the other 7 in the
ramp. That is the controller reading its own register 1074 as signed.

So 1074 is M73's control signal on the pump scale of
[verification-2026-09-20.md](verification-2026-09-20.md): `ffff` is -1, the
pump not driven, and a value is percent of the pump's speed range. While
driven it read 60 to 100.

## 1104 does not follow M73

1104 answered all 190 reads with `ffff`, the 25 minutes at rest and the 7
minutes the page printed M73 at 60 to 100 %. On this machine 1104 answers
and does not report the pump it names; the table decodes it as
`DriveSignal NotDriven` while the pump is driven at 100 %. Whether software
20.24 stopped updating it, or this configuration drives M73 through another
channel, the run cannot say. The parameter list documents 20.21-101
([research.md](research.md), "Revision drift").

What this does not explain is 2026-09-20, when the page printed M73 at -1.0
while the `Digitalausgänge` page showed the same pump on: a pump running with
no control signal. Today the signal rose with the pump.

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

across the start or stop of a heating run, renewing the level every hour.
