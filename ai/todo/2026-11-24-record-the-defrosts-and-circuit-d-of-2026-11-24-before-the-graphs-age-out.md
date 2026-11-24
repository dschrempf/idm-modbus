# Record the defrosts and circuit D of 2026-11-24 before the graphs age out

The controller's graphs reach back about eight days, so what follows
lives on it only until about 2026-12-02. It was read on 2026-11-24 near
21:10 with `graph`/`detail` of graphs 1, 102, 104, 105 and 107, 30 hours
back, at Fachmann level, and printed, not captured. A `tools/webprobe.py`
capture before then keeps eight days of all of them.

## The findings

- **A defrost shows in the graphs** as `T15x_BETRIEBSART_SYSTEM` 8 and
  `N2_DEFROSTING` 1, with the 4-way valve M51 switching about 19 s in and
  back as the defrost ends: 07:37:30 to 07:43:31 and 11:03:29 to
  11:09:29, each about six minutes, at 1 to 4 °C outdoors. The compressor
  channel M1 reads 0 for five of those minutes, though
  `doc/verification/2026-10-16-draw.md` had the compressor run at up to
  78 rps in a defrost. What M1 records there is open.
- **The end of a hot water charge stops the compressor, a change into
  one does not**: heating went into hot water at 12:59:58 with the
  compressor running; the charge ended at 13:44:44 with a stop, and
  heating, requested from 13:44:44, started the compressor at 13:55:04,
  after 10 min 20 s, the minimum standstill (5419).
- **Circuit D's "demand" is a configuration**: the web's
  `system.heatingcircuit` `detail` carries `info.demand` 1 for A, C and
  D, with A and C at `activeMode` 0 "Aus"; it most likely mirrors `HSx06`
  `N2_HC_REQUEST`, "Heizkreis mit Anforderung", Ja on all three. 1501
  `Aktive Betriebsart Heizkreis D` "Heizen" stood with D's set flow at
  0.00 °C and its pump M34 off, so it is no request either.
- **D's Eco gives no set flow**: D, on `HKD01` `Zeitprogramm` with Normal
  from 04:00 to 06:00 (`HKD06`), `HKD04` 15 °C, `HKD05` 10 °C, `HKD10`
  0.3, `HKD08` 6 °C, `HSD05` 12 °C, `HSD04` 20 °C, read `T25xDES_ROOM_HCD`
  10 and `T25xDES_TEMP_HCD` 0 in Eco all day, at 0.8 °C average outdoors;
  in Normal 14.2 to 15 and 18.5 to 22. The curve would give about 13 °C
  at a room target of 10 °C; why Eco gives 0 is open.
- **D's flow overshot its set flow and its maximum while the pump ran**:
  B54 averaged 25.8 to 27.4 °C from 04:57 to 06:39 against a set flow of
  21.6 to 22 °C and `HSD04` 20 °C. D's mixer was reported faulty on
  2026-11-24, but D was shut off by a valve outside the controller until
  that evening, so the pump ran against it and B54 read water that did
  not flow: the figures say nothing about the mixer. The graph's points
  are about 50 minutes apart besides.

## What to write

A measurement in `doc/verification/` for the defrost and the stop after
hot water, and what it changes in `doc/heat-pump.md` ("Defrost", "A start
and a stop"); the circuit D findings into `doc/web-backend.md` for
`demand`, and into `doc/heat-pump.md` for Eco, each cited from a
measurement.
