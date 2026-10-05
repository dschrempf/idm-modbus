# The Wärmemenge registers count something the Wärmemenge page does not

1748, 1750 and 1754 add up among themselves and disagree with the totals the
controller prints, by a factor near 1.19 that grows with use rather than a
fixed offset a counter reset would leave. No register anywhere in the sweep
carries the number the page prints. The measurements are in
`doc/verification-2026-09-20-webapi.md`.

So the table's names for 1748–1762 are at best incomplete, and nothing should
be built on them meaning what the Wärmemenge page means.

What would settle it: two sweeps spanning a single hot water charge, against
the controller's figure for that same charge. The charge window is 10:00–12:00
on this machine, so a sweep before 10:00 and one after 12:00 on the same day,
with `tools/webprobe.py` run beside the second — then compare the rise in 1754
against the day's figure for that day. If the ratio is 1.19 again the registers
are a scaled quantity and the question becomes which one; if the rise matches,
the earlier windows were contaminated and the factor is an artifact.

Worth checking against the second manual, 812184, while at it: it may say what
the counters accumulate.

## Closed 2026-09-20: no new sweep was needed

The capture of that evening already contained the answer, in the part of the
web backend nobody had read: the `statistic` overview serves a **graph**, a
sampled history of the sensors and of whether the machine was heating, making
hot water or defrosting, 30 hours of it. It shows exactly one compressor run in
the window the two sweeps span — the morning charge of 2026-09-20, 87 minutes
against the 1.48 h the controller booked as that day's runtime. So the sweeps
already bracketed a single charge: 8.494 kWh on 1754 against the controller's
10.25, a ratio of 1.21. The factor is per charge, not an artifact of a
contaminated window.

Two things fell out of it. The controller books 10.25 kWh of hot water heat on
2026-09-19 against zero runtime and zero electrical energy — the only such day
in the 31 it keeps, and it is carried into the total the page prints. And the
heat a 300 L tank takes up over that temperature rise is nearer the register's
figure than the page's. The measurements are in
`doc/verification-2026-09-20-webapi.md`; what the counters accumulate is still
unnamed and is an open question in `doc/research.md`.

`tools/webprobe.py` now captures the graph on purpose rather than by accident.
