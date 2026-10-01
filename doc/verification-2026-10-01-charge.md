# A hot water charge to 64 °C, sampled every ten seconds

2026-10-01. Every hot water charge from 2026-09-17 to 09-28 left the top of the
tank at 59.0–59.7 °C, from starting temperatures between 22 and 48 °C and
against targets of 60 and 62 °C. A ceiling that does not move with
the start or the target is a limit, and the question is which one: the
plumber's explanation is a one-hour time limit on the charge, the other
candidate the refrigerant circuit's temperature limit. The controller's own
graph cannot decide it, because it thins sensor history to steps of about 50
minutes. This run, to 64 °C, samples the charge every ten seconds, on Modbus and on the
web backend at once, and the answer is the refrigerant circuit.

## What was recorded

| | |
|---|---|
| Registers | `captures/navigator-2.0-watch-2026-10-01-0828.jsonl`, 08:28–11:10 |
| Web backend | `captures/navigator-2.0-webwatch-2026-10-01-0828.jsonl`, 08:28–11:10 |
| Interval | 10 s, both |
| User level | Fachmann, so that 5888 and 6245 answer |
| Afterwards | `captures/navigator-2.0-webapi-2026-10-01-1158.json`, 11:58–12:09, Fachmann |

The registers are B45 (1066), B41 (1012), B48 (1014), `Status Verdichter 1`
(1100), the three powers 1790, 4122 and 4126, `Wärmemenge Warmwasser` (1754),
`Betriebsart Wärmepumpe` (1090), `Warmwasseranforderung` (1093),
`Summenstörung Wärmepumpe` (1099), the valve M63 (1112), and the three hot
water settings 1032 to 1034. The web backend's settings are 4768
`N2_SENSORS`, which carries the refrigerant circuit and the intermediate
circuit Modbus reports unfitted, 5888 `N2_EVR_OVERVIEW` (superheat,
subcooling, valve positions) and 6245 `N2_MODULATION_OVERVIEW` (the
inverter). Not one Modbus read failed.

In force: `FW027`/`FW028` 40/64 °C, `FW030` 46 °C, the legionella function
off (`FW044` 0). The `FW025` window was extended by hand for the run and set
back to 10:00–12:00 afterwards, with `FW027`/`FW028` back at 38/46. Outside,
B32 read 17.3 °C at the start and 19.6 °C at the stop.

## The run

The request came at 08:29:30 (1093 to 1, 1090 to 4 "Warmwasser", M63 over),
the compressor at 08:31:49. For the first ten minutes the charge pump did not
run: the sink flow B2 read 0 l/min and 4126 read 0 kW while the compressor
drew up to 2.3 kW and lifted the intermediate circuit, B33/B113, from 20 to
62.5 °C. At 08:41:08 the flow started, and after a two-minute transient as
the hot intermediate volume was pushed through, the charge settled at about
6 kW of heat.

Values at ten-minute marks, Modbus and web read within two seconds of each
other; TCOND is B86v, the condensation temperature, and B86 its pressure:

| Time | B41 | B48 top | B45 | TCOND | B86 bar | B71 hot gas | Inverter rps | 4122 kW | 4126 kW |
|---|---|---|---|---|---|---|---|---|---|
| 08:40 | 28.1 | 44.4 | 20.7 | 57.9 | 19.3 | 56.0 | 61.8 | 2.1 | 0.0 |
| 08:50 | 32.2 | 44.3 | 44.7 | 46.9 | 15.0 | 60.5 | 62.0 | 1.8 | 6.1 |
| 09:00 | 36.8 | 44.3 | 49.1 | 50.9 | 16.5 | 65.7 | 61.3 | 1.9 | 6.0 |
| 09:10 | 40.3 | 44.8 | 52.7 | 54.6 | 17.9 | 70.1 | 61.2 | 1.9 | 6.0 |
| 09:20 | 43.4 | 46.0 | 55.6 | 56.9 | 18.8 | 74.4 | 61.7 | 2.1 | 5.9 |
| 09:30 | 45.9 | 48.2 | 58.1 | 59.9 | 20.1 | 77.1 | 59.8 | 2.1 | 5.9 |
| 09:40 | 48.2 | 50.2 | 60.3 | 61.2 | 20.7 | 79.6 | 54.2 | 1.9 | 5.5 |
| 09:50 | 50.2 | 51.8 | 61.8 | 62.4 | 21.3 | 80.0 | 43.4 | 1.6 | 4.4 |
| 10:00 | 51.9 | 53.5 | 63.0 | 63.6 | 21.8 | 81.1 | 39.9 | 1.5 | 4.2 |
| 10:10 | 53.2 | 54.7 | 64.0 | 64.9 | 22.4 | 82.0 | 39.9 | 1.5 | 4.2 |
| 10:20 | 54.5 | 56.1 | 64.7 | 65.9 | 22.9 | 82.9 | 40.0 | 1.6 | 4.0 |
| 10:30 | 55.8 | 57.2 | 65.5 | 67.5 | 23.6 | 84.2 | 39.9 | 1.6 | 4.1 |
| 10:40 | 57.1 | 58.6 | 66.5 | 68.5 | 24.1 | 86.4 | 39.9 | 1.7 | 4.0 |
| 10:50 | 58.2 | 59.6 | 66.8 | 68.5 | 24.1 | 87.1 | 39.9 | 1.6 | 4.1 |
| 11:00 | 58.7 | 60.0 | 48.6 | 32.3 | 10.4 | 56.9 | 0.0 | 0.0 | 0.0 |

The inverter ran at about 62 rps until TCOND passed 60 °C, then slowed, and
from 09:53 it held 39.9 rps, its floor, to the end. Thermal power fell with
it, from 6 to 4 kW.

## The stop

The compressor stopped between the reads at 10:51:09 and 10:51:19, and the
controller withdrew the request in the same round: 1093, 1090 and M63 all
went to 0. Nothing reported a fault — 1099 read 0 throughout, the inverter's
error code 0.0 — and the message log, captured at 11:58, holds no 302,
which this controller writes only when a legionella run misses its target.

The last round with the compressor running, 10:51:08–09:

| | |
|---|---|
| TCOND | 69.4 °C, up from 68.7 at 10:50:28 |
| B86 | 24.5 bar |
| B71 hot gas | 87.2 °C |
| B33/B113, B34/B114 | 70.8 / 65.8 °C |
| B45 | 67.0 °C |
| B48 top, B41 | 59.7 / 58.2 °C |
| Inverter | 39.9 rps, at its floor since 09:53 |

After the stop the top sensor drifted on, to 60.1 °C by 11:09, gaining 0.01 K
a minute by then.

## What it rules out

**A time limit.** The compressor ran 2 h 19 min without a break, the charge
pump 2 h 10 min; 1090 never showed defrost and 1100 never dropped. The runs
of 09-25, 09-27 and 09-28 lasted 69 to 103 minutes and ended at the same top
temperature (`captures/navigator-2.0-webapi-2026-09-29-1333.json`). A limit of
one hour, or of any fixed duration, would have ended all four at the same
duration and at different temperatures; they ended at different durations
and the same temperature. The settings tree, as far as the Fachmann walk of 09-29 reached, holds no
time limit on a hot water charge: its durations are the compressor's minimum
runtime (`WP010`) and dwell time, defrost, circulation, bivalence and the
charge pump's lead and post-run. Nor was it the window: `FW025` is a program
of half-hour slots, so an edge of it falls on :00 or :30, and the stop came at
10:51:19.

**The settings.** `FW028` stood at 64 and the top stopped at 59.7. `FW030`,
at 46, did not end the charge either: the top passed 46 °C at 09:20, 91
minutes before the stop. `WP001` and
`WP002`, the maximum heat pump flow, stand at 72, and B45 reached 67.0.

**Too little power.** The inverter was at its floor, not its ceiling, for the
last 58 minutes. `IV022`/`IV023` bound the modulation from above and below;
raising them could not have helped, which is what the runs at 90 % showed.

## What it points to

The refrigerant circuit's limit. The AERO ALM montage manual (812199 rev. 2.0,
p. 42) gives the R290 circuit 70 °C. The controller approached it the way a
limit is approached: it throttled the compressor from TCOND ≈ 60 °C on, and
with the compressor at its floor and TCOND still rising, at 69.4 °C, the only
move left was to stop.

The top of the tank ends ten degrees below that because the heat passes
three stages, and the capture measures each:

| Stage | Out | Lost |
|---|---|---|
| Refrigerant, TCOND | 69.4 | |
| Intermediate circuit flow, B33/B113 | 70.8 | +1.4, the hot gas's superheat |
| Safety heat exchanger to the house side, B45 | 67.0 | 3.8 |
| Tank top, B48 | 59.7 | 7.3 |

The manual's own figure, 65 °C at the hydraulic module's flow, assumes the
full 5 K across the safety heat exchanger; this one lost 3.8 and B45 reached
67. The larger loss is the last, from B45 to the top of the tank. Whether the
threshold is TCOND itself, B86's 24.5 bar, or 70 °C less `WP026`'s 2 K
applied to some other quantity, one run cannot say; what it does say is that
the stop sits on the refrigerant side and the tank top inherits it. The
manual lowers the limit to 55 °C at −20 °C outside, so the ceiling will be
lower in winter than at the 17–20 °C of this run.

For the legionella function this means a target of 60 °C, the lowest `FW045`
allows, is out of reach of the heat pump alone on this tank: the run ends with
the top at 59.x, the controller logs 302, and tries again the next day.

## What the Wärmemenge register accumulates

`doc/verification-2026-09-20-webapi.md` proposed this test: sample 1754 and
the power through a charge, and integrate one against the other. 1754 rose by
11.228 kWh from 08:28:49 to 11:09:59. The sum of 4126 over the same rounds,
each held for its ten seconds, is 11.156 kWh, 0.6 % less. 1790 equals 4126 in
every round. So 1754 is the running integral of the flow sensor's thermal
power, and the factor of about 1.19 against the controller's statistics page
belongs to what the page computes, not to the registers.

The electrical side, 4122 summed the same way, is 4.082 kWh, the ten minutes
before the charge pump started included: 2.7 units of heat for one of
electricity, for this charge from 44 to 60 °C at the top.

The statistics page of the capture taken afterwards books the same day, and
nothing else ran that day:

| 2026-10-01 | Page | Registers | Page / registers |
|---|---|---|---|
| Hot water runtime | 2.33 h | 1100: 2 h 19 min 30 s, 2.325 h | 1.00 |
| Electrical energy | 4.10 kWh | 4122 summed: 4.082 kWh | 1.00 |
| Heat | 13.17 kWh | 1754: 11.228 kWh | 1.17 |

Runtime and electricity agree; only the heat differs, by a factor close to
the 1.19 `doc/verification-2026-09-20-webapi.md` found between the totals. The page's
heat is therefore not the flow sensor's: by it, this charge gave 3.2 units of
heat per unit of electricity instead of 2.7.

## The controller's own graph of the run

The graph's edges come late against the registers, by the same amount at both
ends of the run: hot water on at 08:30:50, stage on at 08:33:10, both off at
10:52:33–34, where Modbus has the request at 08:29:20–30, the compressor at
08:31:39–49 and both off at 10:51:09–20. The controller's clock read 11:59:51
in the status response captured at 11:58:29 by an NTP-synchronized clock,
82 seconds fast, which is the whole of the lag. The hour by which
`doc/verification-2026-09-20-webapi.md` found the state channels early is
gone.

Its sensor history is thinned to steps of about 51 minutes, and a thinned
point is the mean over its step, stamped at the step's end: the top sensor's
points at 10:07:11 and 10:58:09 read 49.96 and 57.40 °C, and the means of B48
over the same steps, shifted by the 82 seconds, are 49.94 and 57.39. A peak
in the history is flattened accordingly, which is why the graph could not show
where a charge stops.

## The Fachmann level lasts sixty minutes

The level is not held until it is left. It dropped back to Kunde twice during
the run, each time sixty minutes after it was entered: entered about 08:27,
lost between 09:26:59 and 09:27:09; entered 09:27:53, lost between 10:27:49
and 10:27:59. Reading 5888 every ten seconds throughout did not extend it, so
the hour runs from the entry, not from the last request. Entering again at
once worked both times. Once, entering straight after `--leave-fachmann`
did not: the controller answered "action has been executed successfully!" and
stayed at Kunde, and the same request 1.5 minutes later took.

At Kunde level the controller does not answer a `detail` of 5888 at all; the
request stalls rather than being refused. In the capture that shows as
`NoAnswer` on 5888 and `not connected` on the 6245 after it, for five rounds
at 09:27 and one at 10:28, while 4768 and every register read on.

## Reproducing

    IDM_PIN=... cabal run idm-web -- 192.168.0.200 --enter-fachmann
    cabal run idm-dump -- 192.168.0.200 --watch 10 1066 1012 1014 1100 1790 4122 4126 1754 1090 1093 1099 1112 1032 1033 1034 \
      > captures/navigator-2.0-watch-DATE.jsonl
    IDM_PIN=... cabal run idm-web -- 192.168.0.200 --watch 10 4768 5888 6245 \
      > captures/navigator-2.0-webwatch-DATE.jsonl

Start both before the charge, and enter the level again within the hour for
as long as the run lasts; with 4768 first in the list, a lost level costs only
the two Fachmann settings.
