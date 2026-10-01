# Legionella charge stops short of its target

The legionella function (`FW044` heat pump, `FW046` 7 days) charges every day
instead of weekly. From 09-17 to 09-23 every run ended at 59.0–59.7 °C on the
upper sensor and 57.2–58.5 °C on B41, from starting temperatures between 22
and 48 °C, against a target of 60 °C (`FW045`; 62 °C from some time after
09-20 until Dominik set it back to 60 on 09-24). A ceiling that does not move
with the start is a limit or a setup error, not a lack of power, so the
plumber's `IV022`/`IV023` at 90 % (default 70) is unlikely to be the fix. The
run of 09-24 stopped at 54.9/53.6 °C because Dominik had switched the
legionella function off; it was a normal charge.

Later runs, as Dominik reported on 09-29: `IV022`/`IV023` at 90 % still
stopped at 59.x. With modulation back to about 40–70 % and a normal charge to
62 °C on 09-28, it stopped at 59.x again. So the ceiling holds across
modulation and across legionella and normal mode.

Found 2026-09-29, from the 09-24 Fachmann capture:

- No hot water setting sits at 59–60: `FW028` allows up to 64, `FW045` 60–64,
  `WP001`/`WP002` (maximum heat pump flow) are 72.
- The controller logs error 302 `T31xERR_LEGIONELLA_BUFFERTEMP` at the moment
  each legionella run ends (09-22 11:22, 09-23 11:14, 09-24 10:05). A failed
  run is presumably retried next day, which would explain the daily charging.
- `FW044` offers Off, `N2_BIVALENCE_AUXILIARY_HEAT_1` and `N2_HEATPUMP`, and
  it stands at heat pump. `CF008` configures an auxiliary heat generator for
  heating and hot water.
- 812199 rev. 2.0 (AERO ALM montage manual), p. 42: the R290 circuit reaches
  70 °C, the safety heat exchanger loses up to 5 K, so the hydraulic module
  flow reaches at most 65 °C (55 °C at −20 °C outside). `WP026`
  `N2_PARA_LIMIT_OF_USE_OFFSET` stands at 2 K. A tank top at 59.x is what
  65 °C minus a charging spread gives.
- B33/B34 (1050/1052) are unfitted; the only heat pump flow on Modbus is B45
  (1066). The refrigerant values (`T25x_AIN_TCOND`, hot gas) are only in the
  websocket's `Kältewerte` graph, userLevel 2, and its history is thinned to
  ~50 min steps, too coarse to show the stop.

From `captures/navigator-2.0-webapi-2026-09-29-1333.json` (Fachmann), against
the 09-24 capture: `FW044` 3 → 0 (legionella off), `FW027`/`FW028` 48/52 →
38/46, `IV022`/`IV023` 90/90 → 70/40.

- 302 again on 09-25 11:43 and 09-27 11:45, info 15 both times, each at the
  second the stage channel drops. None on 09-28, when legionella was already
  off.
- 371 `N2_ERROR` on 09-27 10:10, at a defrost that interrupted the charge for
  five minutes. Meaning unknown.
- The top sensor peaks at 59.5–59.6 °C after every charge since 09-23 (09-25,
  09-27 legionella; 09-28 normal to 62). The runs last 69–103 minutes and all
  start at 10:02, in the `FW025` window 10:00–12:00, and end well before 12:00.
  Durations that vary while the end temperature does not point to a
  temperature limit, not to a timer or to the window.
- The stage channel now starts at 10:02, inside the window, and agrees with the
  message log to the second. The hour's offset
  `doc/verification-2026-09-20-webapi.md` reports for the state channels is
  gone; the controller was restarted on 09-23 08:40. The doc needs a line on
  this.
- The sensor channels are still thinned to ~50 min, so TCOND at the stop is not
  in the history.
- Live instead: `idm-web HOST --watch 10 4768` (level 0) carries B86v TCOND,
  B71 hot gas, B78/B86 pressures and B33/B113, B34/B114, the Zwischenkreis
  flow and return that Modbus reports unfitted, at 0.1 K. Run it beside
  `idm-dump --watch` through a charge.

Captured and written up 2026-10-01, `doc/verification-2026-10-01-charge.md`:
a normal charge to 64 stopped after 2 h 19 min of compressor run, at TCOND
69.4 °C with the inverter at its floor, B45 67.0, top 59.7 (60.1 after
drift). Not a time limit; the R290 limit of 70 °C, passed down through the
safety heat exchanger (3.8 K) and the tank side (7.3 K). The plumber's
one-hour limit is refuted there in detail.

`captures/navigator-2.0-webapi-2026-10-01-1158.json`, taken after the run and
written up in the same doc: the page agrees with the registers on runtime and
electricity and books 1.17 times 1754's heat; the graph is stamped with the
controller's clock, 82 s fast, and the hour offset is gone (line added to
`doc/verification-2026-09-20-webapi.md`); thinned graph points are step means.
The message log names 371 of 09-27: `N2_ERROR` / `N2_FLOWSWITCH_HEATSINK`, the
heat sink's flow switch, at the defrost that interrupted that charge.

302 is legionella-only: Dominik, 2026-10-01 — the legionella run logs that it
missed its target, a normal charge does not log missing `FW028`. The message
log held no 302 for this run.

Open:

- Dominik's reading, 2026-10-01: a defect in the iDM software. `FW044`
  offers the heat pump for legionella, but `FW045` cannot go below 60 and
  the heat pump cannot bring the top there, so with `FW044` at heat pump the
  function fails and runs again every day. Worth reporting to iDM with
  `doc/verification-2026-10-01-charge.md`.
- The heater: Dominik is sure a rod is fitted, the display calls it
  "Bivalente Wassernachladung". The configuration agrees: `CF008` 3
  (`N2_BIVALENCE_STRATEGY_HEATING_DHW`) sets auxiliary source 1 up for
  heating and hot water, `CF009` 1, and `FW044` offers it as
  `N2_BIVALENCE_AUXILIARY_HEAT_1`. 1762 answering the sentinel says only that
  no heat meter is assigned to it. Witness on Modbus: 1124 "Bivalenz
  Betriebszustand", 1 = "Bivalenz 1 aktiv". A legionella run with `FW044` at
  auxiliary heat, watched with 1124 added, would show whether it reaches 60.
- The 7.3 K from B45 to the tank top is the largest single loss: how the tank
  is charged (internal coil or external exchanger, sensor positions) decides
  whether anything can be won there.
- What the stop keys on: TCOND, B86's pressure, or `WP026` applied to some
  limit. A second run at a different outside temperature would separate them.
- Manual control over Modbus: 1712 "Anforderung Warmwasserladung" and 1713
  "Einmalige WW-Ladung" are volatile, so triggering a charge costs no EEPROM
  cycle. Writing is absent by design; this needs the write interface
  `CLAUDE.md` asks for, decided before any code.
