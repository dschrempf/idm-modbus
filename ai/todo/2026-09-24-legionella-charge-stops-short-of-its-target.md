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

Open:

- Which parameter ends the charge near 59 °C. The Fachmann capture
  `captures/navigator-2.0-webapi-2026-09-24-1544.json` (untracked) holds all
  260 settings visible at that level; look there first, then ask iDM.
- Whether the next runs, with `FW045` at 60 again, still stop short.
- Manual control over Modbus: 1712 "Anforderung Warmwasserladung" and 1713
  "Einmalige WW-Ladung" are volatile, so triggering a charge costs no EEPROM
  cycle. Writing is absent by design; this needs the write interface
  `CLAUDE.md` asks for, decided before any code.
