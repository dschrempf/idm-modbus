# The least draw at the heating modulation floor is unknown

## The question

The heating modulation floor, `IV003` / `N2_MOD_MIN_POWER_HEATING`, is set
to 20 %. The hot water floor, `IV023`, is set to 40 %, and there the charge
of 2026-10-01 drew 1.5–1.7 kW by 4122
(`doc/verification-2026-10-01-charge.md`). The one captured heating run drew
2.7–3.1 kW (`doc/verification-2026-10-15-heat-sink.md`), but its modulation
was not recorded, so nobody knows whether that was the floor. A consumer
deciding whether a surplus can run the machine needs to know the least it
draws while heating (`doc/research.md`, "The least draw while heating").

There is a second question inside it. `N2_GLTMON` describes 4122 as
"elektrische Gesamtleistung (falls kein Wert vom Inverter vorhanden ist,
wird jener vom Polynom verwendet)". So 4122 is either the inverter's figure
or a model's, and nothing yet says which.

## Found on 2026-10-16

Step 1 and 2 of the list below, over the heating run of 08:10 to 08:55
(`doc/verification-2026-10-16-draw.md`):

- 4122 follows 6245's `motor power` to its 0.1 kW rounding in every mode:
  the inverter's figure, not the polynomial's.
- The floor was not reached. After a start at a fixed 50.4 rps, 0.9–1.1 kW,
  which hot water uses too, the compressor turned at 101–113 rps and drew
  2.48–3.06 kW until the stop. 6245 prints a speed, not a modulation in
  percent, so even a run that slows down leaves how 20 % maps to a speed to
  be read off the lowest steady speed.

Left: a heating run with less demand, watched the same way, 6245 beside
1090, 1100 and 4122.

## How we might solve it

1. While the machine heats, watch setting 6245, `N2_MODULATION_OVERVIEW`,
   beside 4122, 1100 and 1090. The overview is an info page; at rest it
   printed the inverter's `motor speed` (rps), `motor power` (kW),
   `drive status` and `dc bus voltage`. Do it over a long run: whether
   and when the controller modulates down to the floor isn't known, so a
   short run may never reach it.

       IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
       IDM_PIN=... cabal run idm-web -- HOST --watch 30 6245 > captures/navigator-2.0-webwatch-YYYY-MM-DD-HHMM.jsonl
       cabal run idm-dump -- HOST --watch 30 1090 1100 4122 4126 > captures/navigator-2.0-watch-YYYY-MM-DD-HHMM.jsonl
       IDM_PIN=... cabal run idm-web -- HOST --leave-fachmann

   The Fachmann level lasts sixty minutes, so a longer run has to enter it
   again.
2. If `motor power` tracks 4122, then 4122 is the inverter's figure; if it
   doesn't, 4122 is the polynomial's.
3. A meter on the supply would say what the machine actually draws, as
   against what it reports.

Record the outcome in a dated `doc/`, and close the open question in
`doc/research.md`.
