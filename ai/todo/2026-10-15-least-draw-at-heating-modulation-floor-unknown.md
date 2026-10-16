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

Over the heating run of 08:10 to 08:55
(`doc/verification-2026-10-16-draw.md`):

- 4122 follows 6245's `motor power` to its 0.1 kW rounding in every mode:
  the inverter's figure, not the polynomial's.
- The floor was not reached. After a start at a fixed 50.4 rps, 0.9–1.1 kW,
  which hot water uses too, the compressor turned at 101–113 rps and drew
  2.48–3.06 kW until the stop. 6245 prints a speed, not a modulation in
  percent, so even a run that slows down leaves how 20 % maps to a speed to
  be read off the lowest steady speed.

Left: the floor itself. Waiting for the controller to choose it may take
many runs, so the next run forces it as far as the settings allow.

## The next run

The settings cannot pin heating at 20 %: `IV003` is already at its least,
20, and `IV002`, `N2_MOD_MAX_POWER_HEATING`, accepts 50 to 100, set to 100
(`captures/navigator-2.0-webapi-2026-10-01-1158.json`). So:

1. Before the run, at the display: `IV002` from 100 to 50, and the heating
   curve of circuit A a step lower, so the controller has a reason to go
   below the cap. Write down both values first. Each change is presumably an
   EEPROM write; a handful by hand is a small cost.
2. Watch a heating run as on 2026-10-16, 6245 beside 1090, 1100, 4122 and
   4126, at 10 s, renewing the Fachmann level with a pause after leaving
   (`fachmann-entry-right-after-leaving-is-ignored`):

       IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
       IDM_PIN=... cabal run idm-web -- HOST --watch 10 6245 > captures/navigator-2.0-webwatch-YYYY-MM-DD-HHMM.jsonl
       cabal run idm-dump -- HOST --watch 10 1090 1100 4122 4126 > captures/navigator-2.0-watch-YYYY-MM-DD-HHMM.jsonl
       IDM_PIN=... cabal run idm-web -- HOST --leave-fachmann
3. Restore both settings after the run.

The run tests a hypothesis. The defrost, set by `IV007` to 65 %, ran at
78.0 rps, which puts 100 % near 120 rps. Then the heating run of 2026-10-16
ran at 85 to 94 %, hot water at 54 %, the start program at 42 %, and the
floor is near 24 rps. Capped at 50 %, the compressor should top out near
60 rps. If it does, the scale holds, and the lowest steady speed of the run
says how far toward 24 rps the controller went; what 4122 reads there is
the answer. If it tops out elsewhere, the cap's speed gives a second point
of the scale.

Should the controller stay at the cap, the run still bounds the floor's
draw from above. The other way to force it, the power limit at 4108, needs
writing (`power-limit-4108-semantics-unknown`).

4122 is the inverter's figure; a meter on the supply would say what the
machine draws besides it.

Record the outcome in a dated `doc/`, and close the open question in
`doc/research.md`.
