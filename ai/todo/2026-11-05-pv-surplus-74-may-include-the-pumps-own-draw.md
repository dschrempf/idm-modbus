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

## How we might solve it

1. Start a store charge with 74 = 3.0 as on 2026-11-05, with B38 well below
   `PV006`. Once the compressor has run past `WP010`'s 10 min, write
   74 = 0 every minute: under reading 1 the run holds, as a meter reading 0
   means the pump uses exactly the PV output; otherwise it stops within
   `PV011`'s 2 min. If it holds, write -0.5 (74 documents no range): under
   reading 1 it then stops. Watch 1090, 1100, 4122, B38 and the graph's two
   channels.
2. Record it in a dated `doc/`, and in `doc/research.md`'s open question.
   Under reading 1, a consumer writes the meter's export as it is, negative
   for import.
