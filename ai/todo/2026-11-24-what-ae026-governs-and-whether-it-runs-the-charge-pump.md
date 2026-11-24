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

An overnight watch below 3 °C, both channels at once, at Fachmann level
for 4768's refrigerant and intermediate circuit values:

    cabal run idm-dump -- HOST --watch 60 1000 1060 1008 1072 1074 1090 1104 > captures/navigator-10-watch-SOFTWARE-YYYY-MM-DD-HHMM.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --watch 60 --fachmann 4768 4789 > captures/navigator-10-webwatch-SOFTWARE-YYYY-MM-DD-HHMM.jsonl

It answers: whether M73 runs, with a flow at 1072, while B33 or B34 is
below `AE026`; when it stops; and which of 1074 and 4789's M73 tells the
truth. Reading only, no setting changed. A measurement in
`doc/verification/`, and `doc/heat-pump.md`'s frost protection section
updated.

## Not in the way

The watch confounds nothing with the circuits' frost protection as long
as circuit D's frost protection, `HSD40`, is off or its mixer M44 holds.
D's mixer was reported faulty on 2026-11-24: with it on, D's pump would
draw on the buffer, and a reading of D's flow says nothing about `AE026`.
