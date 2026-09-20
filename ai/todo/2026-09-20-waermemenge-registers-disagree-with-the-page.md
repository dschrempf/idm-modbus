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

## Left over from the same session

1449 is not the maximum flow temperature — moving that setting to 42, 43 and 44
on circuits A, C and D changed no register at all. The conclusion rests on the
change having taken while it was made, which was never confirmed on the
display. Redoing it means writing a setting, so it is a decision for Dominik,
not something to run unasked.
