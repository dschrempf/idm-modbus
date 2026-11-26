# Record the hot water stop and circuit D of 2026-11-24

The walk of 2026-11-26 at 20:36, at Fachmann level
(`captures/navigator-10-webapi-20.24-2608-2026-11-26-2036.json`), holds
eight days of every graph, back to 2026-11-19, 2026-11-24 among them. What
follows was read on 2026-11-24 near 21:10 with `graph`/`detail` of graphs
1, 102, 104, 105 and 107, 30 hours back, and printed; it is to be read
again from that capture before it is written.

The defrost finding is written:
`doc/verification/2026-11-26-on-a-day-of-snow-the-heat-pump-defrosted-every-hour.md`,
and M1's five minutes of 0 in a defrost are the graph's, not the
compressor's:
`doc/verification/2026-11-26-a-graphs-state-channel-keeps-one-point-per-five-minutes.md`.
What is left is below.

## The findings

- **The end of a hot water charge stops the compressor, a change into
  one does not**: heating went into hot water at 12:59:58 with the
  compressor running; the charge ended at 13:44:44 with a stop, and
  heating, requested from 13:44:44, started the compressor at 13:55:04,
  after 10 min 20 s, the minimum standstill (5419). M1's start there came
  more than five minutes after its last point, 13:44:44, so the graph
  stamps it at its time.
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
  are about 50 minutes apart besides, each an average over its interval.
  That evening, measurement
  `2026-11-24-a-circuits-pump-stops-while-its-flow-is-above-its-maximum`
  had M34 stop while B54 stood above `HSD04`. The morning's run does not
  contradict it: `HSD04` read 40 °C on 2026-11-11 at 22:41, and by the
  household's account it went to 20 °C only later on 2026-11-24, before
  21:10, and to 35 °C that evening, so that D runs for sure, a manual
  frost protection while the mixer is faulty. It stood at 35 °C on
  2026-11-26. The morning's figures are no evidence about `HSD04`.

## What to write

A measurement in `doc/verification/` for the stop after hot water, and
what it changes in `doc/heat-pump.md` ("A start and a stop"); the circuit
D findings into `doc/web-backend.md` for `demand`, and into
`doc/heat-pump.md` for Eco, each cited from a measurement.
