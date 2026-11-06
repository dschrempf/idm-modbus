# The PV surplus at 74 may include the pump's own draw

## The question

Given 3.0 kW at 74, the pump drew up to 4.05 kW and ran until the heating
store reached `PV006` (`doc/verification-2026-11-05-pv-surplus.md`). Two
readings fit:

1. The controller adds its own draw back to 74, taking it for a surplus
   measured at the grid, which falls as the pump runs. 812184 says so for
   `PV010` "Überschuss", but `PV010` applies to the 0–10 V and S0 signals
   only and is not in the menu with `N2_GLTSF`.
2. It starts on the surplus and then does not size the run to it.

A consumer writes either the grid's export as it is or the export plus the
pump's draw, depending on the answer. Faking a surplus to run the pump on
demand works either way; how hard it then runs depends on it.

## What the graph adds

Put into a graph by hand after the run, the controller's history of
2026-11-05 showed "akt. PV Überschuss" at 3.0 kW throughout: the channel is
74 as written, not 74 plus the draw. "Mom./prog. Aufnahme" followed the
draw while the pump ran, up to about 3.8 kW and down to 3.4, then 0. So
while the pump runs the threshold is its own draw, and from about 21:21 on
it exceeded the surplus. `WP010` `N2_MIN_RUNTIME_COMPRESSOR` reads 10 min,
so under 812184's rule for a store charge, without adding anything back,
the run should have stopped about 21:26:20. It ran to 21:35:40 and stopped
at `PV006`. That favors reading 1, or a store charge that does not follow
the rule; it does not settle it. Seen on the web interface by eye, not
captured yet: the next webapi capture holds the graph, which reaches back
about a week.

## Why it comes first

Under reading 1, 0 is not "no surplus": it reads as a meter showing that
the pump uses exactly the PV output. A consumer that leaves the controller
to its own business by writing 0 would then keep a running pump running, and
must write a negative value instead. And 74 has stood at 0, with `PV008` at
`N2_GLTSF`, `PV001` Yes and `PV013` Always, since 21:37 on 2026-11-05. If the
controller weighs 0 plus its draw against its draw, a run it starts on its
own may count as covered by PV and go on as a PV store charge until B38
reaches `PV006`. Until this is settled, a run the controller started that
ends at B38 = `PV006` rather than at its own store target points to that;
setting `PV008` back to `N2_NONE` rules it out, at one EEPROM cycle each
way.

## How we might solve it

1. Start a store charge with 74 = 1.0, the first phase of
   `does-a-low-surplus-at-74-cap-the-speed`, with B38 as far below `PV006`
   as it gets: on 2026-11-05 the charge went from 27.5 to 35 °C in 20 min at
   full speed, and this step needs the compressor's 10 min of `WP010`, plus
   `PV011`'s 2 min, plus a margin, before `PV006` ends the run. Once the
   compressor has run past `WP010`, write 74 = 0 every minute: under
   reading 1 the run holds; otherwise it stops within `PV011`'s 2 min. If it
   holds, write -0.5 (74 documents no range): under reading 1 it then
   stops. Watch 1090, 1100, 4122, B38 and the graph's two channels.
2. Record it in a dated `doc/`, and in `doc/research.md`'s open question.
   Under reading 1, a consumer writes the meter's export as it is, negative
   for import.

## Done on 2026-11-06

Reading 1: the controller adds its own draw back. Run on the morning, not
the evening, with `PV006` raised to 40 and then 45 °C for room. 1.0 did not
start a charge in 12.5 min; 1.7 did. The run held at full speed, 3.9 kW,
past `WP010` at 1.7 and for 3 min at 0, and stopped 72 s after -0.5, after
ramping down from 120 to 81 rps
(`doc/verification-2026-11-06-pv-surplus-own-draw.md`, and
`doc/research.md`). A consumer writes the meter's export as it is, negative
for import; 0 keeps a running charge running.

The worry under "Why it comes first" did not bear out on the morning's hot
water charge: it ended at its own target with 74 at 0 and left the pump in
standby, by eye at the display. `PV008` stays at `N2_GLTSF`.

`PV006` is back at 40 °C, where the house may leave it.
