# What `AE026` governs, and whether it runs the charge pump

`AE026` `N2_FROST_PROTECTION_FLOW_TEMP`, 5755, reads 20 °C, beside
`AE025` `N2_FROST_PROTECTION_OUTDOOR_TEMP`, 5748, at 3 °C, in
`N2_MONITORING_FUNCTIONS` under `N2_HEAT_PUMP`. The web interface gives its
purpose as securing the defrost. It is not a circuit's frost target: with
it at 20 °C, every circuit in frost protection read 10.00 °C
(`doc/verification/2026-11-06-frost-protection.md`, which leaves `AE026`
open).

The hypothesis: it is the minimum of the heat pump's own water. 812199
§5.7 describes a frost protection of the outdoor unit that starts the
charge pump, below the frost protection outdoor temperature, while the heat
pump's flow is below "die einstellbare Minimaltemperatur", until the
connecting lines are warm again. A defrost takes its heat from that water
(4126 at -7 to -8 kW, `doc/heat-pump.md`), which is what "secure defrost"
would mean.

On 2026-11-24 at 21:07, at -2.5 °C outdoors, the web's 4789 read M73
`Ladepumpe Wärmesenke EIN/AUS` at 100.0 while 4768 read B34/B114 at
10.5 °C and B33/B113 at 19.3 °C, both below 20 °C. The same minute,
Modbus read 1074 "not driven" and 1072 0.00 l/min, as did 4768's B2. The
two channels disagree about the pump; this was read once, not watched.

## How to settle it

An overnight watch below 3 °C, both channels at once, reading only, no
setting changed. Below `AE025` is a night like 2026-11-26's, at 0.6 °C
outdoors at 20:40.

### Before starting

- The outdoor temperature, 1000, below 3 °C, and forecast to stay there.
- The level at Kunde, `idm-web HOST --status`: the web watch enters
  Fachmann itself, for 4768's refrigerant and intermediate circuit
  values, and renews it every 55 minutes all night. Each entry shows the
  notice on the display.
- `HSD40` still `N2_NO` (it read 0 in the walk of 2026-11-26 at 20:36).

### Run

From the evening to past 08:00, so that D's Normal window at 04:00 and a
morning defrost are in it:

    cabal run idm-dump -- HOST --watch 60 1000 1060 1008 1072 1074 1090 1091 1100 1104 1356 1501 > captures/navigator-10-watch-SOFTWARE-YYYY-MM-DD-HHMM.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --watch 60 --reason --fachmann 4768 4789 > captures/navigator-10-webwatch-SOFTWARE-YYYY-MM-DD-HHMM.jsonl

Both with `2> ….stderr` beside them. Stop both with SIGTERM in the
morning; the web watch leaves the level on its way out. Then a walk at
Fachmann level, `tools/webprobe.py`, for the night's graphs.

Beyond the note's first list, 1091 and `--reason` tell a heating
request's M73 from frost protection's, 1100 the compressor, and 1356 and
1501 circuit D (below). 60 s is enough for the frost protection, which
runs for minutes; it cannot time a defrost's edges, so a defrost's M73 is
read as a defrost by 1090 at 8 and not counted.

### What it answers

Whether M73 runs, with a flow at 1072, while B33 or B34 is below `AE026`
and 1090 reads no mode; when it stops; and which of 1074 and 4789's M73
tells the truth. A measurement in `doc/verification/`, and
`doc/heat-pump.md`'s frost protection section updated.

## Not in the way, with one window

`HSD40` is off, so D's frost protection runs nothing. But D now runs on
purpose: `HKD01` `Zeitprogramm` with Normal 04:00 to 06:00 and 17:00 to
19:00 (`HKD06`), and `HSD04` at 35 °C so that its pump runs whatever its
flow, as a manual frost protection while its mixer is faulty (read in the
walk of 2026-11-26). From 04:00 to 06:00 D's pump draws on the buffer, may
cool it into a heating request, and its flow reads the buffer's
temperature. Read those two hours by the request reason, and the rest of
the night as clear of D.

A graph's M1 is no witness to the compressor near a defrost or another
change within five minutes
(`doc/verification/2026-11-26-a-graphs-state-channel-keeps-one-point-per-five-minutes.md`);
read 1100.
