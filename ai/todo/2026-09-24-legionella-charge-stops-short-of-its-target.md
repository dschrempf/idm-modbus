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

Open:

- Confirm the envelope: B45 and TCOND at the moment a charge to ≥ 60 °C stops.
  Needs sampling during a charge, not the graph history:
  `idm-dump HOST --watch 10 1066 1012 1014 1100 1790 4122 4126 1754 >
  captures/navigator-2.0-watch-YYYY-MM-DD-HHMM.jsonl`, started before 10:00.
  TCOND is not on Modbus, so B45 is the envelope's only witness there.
- Whether `FW044` = auxiliary heat is the intended setup, i.e. whether a
  heating rod is physically fitted (1762 answers the sentinel).
- Manual control over Modbus: 1712 "Anforderung Warmwasserladung" and 1713
  "Einmalige WW-Ladung" are volatile, so triggering a charge costs no EEPROM
  cycle. Writing is absent by design; this needs the write interface
  `CLAUDE.md` asks for, decided before any code.
