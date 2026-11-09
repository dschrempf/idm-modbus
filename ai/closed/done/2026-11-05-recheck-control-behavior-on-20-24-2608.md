# Re-check control behavior on 20.24-2608

The update of 2026-11-05 left the registers and the settings tree as they
were, but for what `doc/software-versions.md` lists. What the documents
measured of the machine's behavior was measured on 20.24-1574, and an update
may change control behavior without changing a register. Re-check each when
a heating run is watched anyway, and record the outcome in a new dated
document that `doc/software-versions.md` points to.

- `doc/verification-2026-10-16-draw.md`: graph channels 112 and 365, both
  `T20x_QACT` before, are now `N2_THERMAL_PERFORMANCE_POLY` and
  `…_FLOWSENSOR`. Its 4112, which stayed at -1.0, is gone; 4113 and 4114
  are locks (`power-limit-4108-semantics-unknown`).
- `doc/verification-2026-10-16-charge-pump.md`: 1074 is M73's signal, now
  from the manual too, and 1104 does not follow it
  (`charge-pump-status-1104-reads-not-driven-while-pumping`). It is prose
  in `doc/research.md`'s open questions and in the haddock of `Drive`
  (`decide-how-a-measured-fact-enters-the-table`); if it holds here too,
  weigh again a `Presence` constructor for a register that answers but does
  not follow its quantity, which takes 1104 out of `present`.
- `doc/verification-2026-11-05-floor.md`: the floor of 24 rps at 0.67 kW.
- `doc/verification-2026-10-01-charge.md`: a hot water charge.
- `doc/verification-2026-09-20.md`: the display against the registers.

Re-checked by reads on 2026-11-05 already: every address, the settings
tree's ids and identifiers, the protocol, the Fachmann code, and the labels
of `systemMode` (`adapt-to-software-20-24-2608`, `rechecks.md`). Settled
from the captures on 2026-11-09: `FW045` and `FW046` went with `FW044` Off,
on 20.24-1574, and `N2_PING` never went (`doc/software-versions.md`).

## 2026-11-09: the heating run, watched

Read only, 14:50 to 16:29, the level at Fachmann from 14:51 to 15:51;
`doc/verification-2026-11-09-heating-run-as-on-1574.md`, pointed to by
`doc/software-versions.md`. Re-checked and unchanged: 1074 follows M73,
1104 reads `ffff` while the pump is driven
(`doc/verification-2026-10-16-charge-pump.md`); 4122 follows 6245's motor
power, the start program holds 50.4 rps for three minutes
(`doc/verification-2026-10-16-draw.md`); the compressor starts 50 s after
the request. The request reason read 513, `RD_REQ_HK_C`, as the web
interface printed it: C's flow had stood 1 K below its set for the
add-on time, `HKC59`, 15 min, and A's had not; A's bit did not appear when
its flow fell below later, during the run. Mode 8 and no `info` in the
defrost.

Not reachable by a read: graph channels 112 and 365 are in no graph the
controller offers, only in the `traverse` group `N2_HEATQUANTITIES`;
plotting them takes a `save`. The draw's re-check rests on 6245 instead.

## Closed 2026-11-09

Decided against re-checking behavior at each update: a run watched for
hours cannot be repeated on every software. An update is re-checked by
what a read checks at rest, the scan, the widths and the walk, and a
behavior measurement stands with the software it was made on;
`doc/software-versions.md` says so. The run of 2026-11-09 was the last
such re-check. 1104 reads `ffff` while its pump runs on both softwares:
said in `doc/research.md`'s second finding and in the haddock of `Drive`;
no `Presence` constructor. The floor, the hot water charge and the display
stand as measured on 20.24-1574.
