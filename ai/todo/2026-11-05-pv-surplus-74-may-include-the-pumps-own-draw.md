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

## How we might solve it

1. With B38 well below `PV006`, write 74 = 1.5, above the page's threshold
   (0.7–0.8 kW) and below the draw seen, every minute. Watch 1090, 1100,
   4122 and B38 as on 2026-11-05. Under 1 the run holds and may ramp past
   1.5 kW; under 2, 812184 has a heating or store run stop once the
   surplus falls below the requested power and the compressor's minimum
   runtime has passed.
2. The web interface offers four PV channels for a graph: "akt. PV
   Überschuss", "Mom./prog. Aufnahme", "akt. PV Produktion" and "akt.
   Hausverbrauch"; `T25xPV_AVAILPOWER`, channel 183, is likely the first.
   Put the first two into a graph by hand (a `save`, so not from here)
   before the run: if "akt. PV Überschuss" reads 74 plus 4122 while the
   pump runs, that is reading 1. The next webapi capture holds the graph,
   perhaps back to 2026-11-05 if the controller logs channels no graph
   shows.
3. Record it in a dated `doc/`, and in `doc/research.md`'s open question.
