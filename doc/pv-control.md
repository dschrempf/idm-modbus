# The controller's PV control: what the sources say, and how to watch it

The runs on 74 so far (`doc/verification-2026-11-05-pv-surplus.md`,
`doc/verification-2026-11-06-pv-surplus-own-draw.md`,
`doc/verification-2026-11-06-pv-surplus-loop.md`) each answered a question
and raised one the tests could not see into: what starts a PV run, what sets
its speed, what stops it, and what holds off the next start. This document
collects what the sources say about that logic and which observations would
show it at work, so the next test measures rather than guesses. A claim
here is the source's until a dated `doc/` measures it.

## The sources

- **812170 rev. 12, §4.3.10.** 74 carries the surplus in kW, 4122 the
  current or forecast draw; "Sobald der PV-Überschuss höher ist als die
  Aufnahmeleistung startet die Wärmepumpe". Its register list prints, beside
  74, 76 `Leistung E-Heizstab`, 78 `Aktuelle PV Produktion`, 82
  `Hausverbrauch`, 84 `Batterieentladung`, 86 `Batteriefüllstand` and 88
  `PV-Zielwert (Smartfox und Solar-Log)`, a `FLOAT` in kW with default 0, all
  `RW/RO` and volatile. §4.4 describes the GLT monitor.
- **812184 rev. 13, chapter 2.5**, summarized in `doc/research.md`: the
  forecast at standstill, the mean over `PV011`, `PV015`'s shift, and that a
  heating run stops "nach Ablauf der Mindestlaufzeit des Kompressors …, wenn
  die verfügbare PV-Leistung unter die angeforderte PV-Leistung abfällt".
  For Solar-Log it names a value the GLT path does not show:
  "Aktueller Aufnahme Zielwert".
- **The Navigator 10 sheet** (`manual/navigator-10-pv-glt-2026-01.pdf`,
  scanned, read by eye): the same block 74 to 86 and 4122 for the GLT path,
  and the Smartfox's own settings for an iDM pump: "Zielwert standardmäßig
  „0"" and the pump's electrical power at nominal speed in watts. The
  Smartfox regulates toward a target of its own; what it writes to 74 is not
  documented.
- **The controller's help texts**, `assets/translations/en.json` and
  `de.json` of `captures/navigator-2.0-webui-20.24-2608-2026-11-05-1641/`:
  the description behind each setting's `N2D_` key. The ones that bear on
  this, in the controller's English:
  - `N2D_PV_HEATING_HYSTERESIS` (13300): "PV control is activated when the
    temperature of the heating buffer sensor falls below the preset max.
    temperature (PV006) by this value."
  - `N2D_PVTIMECONST` (10389, `PV011`): "the time interval for averaging the
    PV power."
  - `N2D_PVCONSUMPTIONOFFSET` (10396, `PV015`): it raises or lowers "the
    'Actual/Predicted Power Consumption' value", so the pump switches on
    later or earlier.
  - `N2D_MIN_RUNTIME_COMPRESSOR` (5412): "In the event of an error, the
    minimum running time does not apply!" No other exception is named.
  - `N2D_MIN_DWELL_TIME_COMPRESSOR` (5419): the minimum standstill.
  - `N2D_PV_SIGNAL_TYPE` (`PV010`): for an "Excess" signal, "the signal value
    is reduced by the electrical power consumption of the heat pump when it
    is switched on", which is the controller adding its draw back that
    `doc/verification-2026-11-06-pv-surplus-own-draw.md` measured for 74.
  - Names without a setting in any capture: `N2_CA20PV_PID_HEAT_Y`,
    `N2_CA20PV_PID_PRIO_Y` and `N2_CA20PV_PID_COOL_Y` ("CC PV PID … Y"), the
    outputs of a PID controller per mode; `N2_PV_POWERTARGET` "Target
    Consumption" ("Aufnahme Zielwert"); `N2_PV_TARGET` "PV target value";
    `N2_ELECTRIC_POWER_WITH_PVOFFSET`, "total electrical power + PV-Offset
    (if there is no value from the inverter, that from the polynomial is
    used)".
- **The web interface's JavaScript**, `main-7UP7UE6I.js` of the same
  capture: a function that reads `heatpump.info` of the `system` overview
  with the operating mode and names the reason for a request. In heating
  mode bit 32 is `RD_REQ_PV`; the others are `RD_REQ_EXTERNAL_DI` (4),
  `RD_REQ_EXTERNAL_BUS` (8), `RD_REQ_ISC` (16), `RD_REQ_FROST_PROT` (64), the
  circuits `RD_REQ_HK_A` to `RD_REQ_HK_G` (128 to 8192), `RD_REQ_SYS_OFF`
  (16384), `RD_REQ_ION` (32768) and `RD_REQ_HEATING_BOOSTER` (65536); more
  than one bit reads `RD_REQ_MORE_DEMANDS`. Hot water and cooling have
  tables of their own. The webapi capture at rest,
  `captures/navigator-2.0-webapi-20.24-2608-2026-11-06-1148.json`, has no
  `info` in its `heatpump`.
- **The GLT monitor**, 12763 `N2_GLTMON`, at Fachmann level: per address a
  `Value`, the controller's internal one, and a `GLT Value`, the last one
  written (812170 §4.4). On 2026-10-16 it listed 74 to 88 with an empty
  `GLT Value`
  (`captures/navigator-2.0-webwatch-20.24-1574-2026-10-16-0748.jsonl`).
- **The PV graph**, graph 101, Kunde level: channel 183 `T25xPV_AVAILPOWER`
  "akt. PV-Überschuss" and 184 `T25xHP_REQPOWER` "Mom/prog. Aufnahme", at
  one point per 304 s in the captures so far.
- **Community reports**, unverified here:
  - [A Home Assistant thread](https://community.home-assistant.io/t/idm-heatpump-integration-via-modbus-pure-ha/701473),
    March 2024 to March 2025, another model: a start once 74 exceeds the
    expected draw by about 500 W, at least 10 minutes of runtime, no restart
    within 10 minutes, speed rising with the surplus, and 74 to include the
    pump's own draw.
  - [An evcc discussion](https://github.com/evcc-io/evcc/discussions/24699),
    an AERO ALM on Navigator 2.0, October 2025 to October 2026: the
    controller kept acting overnight on the last value written, and a store
    charge needed about 3.3 kW to start on another machine.

## By question

### What starts a PV run

812170 and 812184: a mean surplus above the forecast draw, shifted by
`PV015`. Measured: 1.0 against a forecast of 0.8 kW started nothing in 12
minutes; a mean of about 1.0 against 0.7 kW did. A margin of about 0.3 kW
fits both; the Home Assistant thread says 500 W. `PV015` is not it: 10396
reads 0 (`captures/navigator-2.0-webapi-20.24-2608-2026-11-06-1148.json`).
Not settled whether the margin is a setting.

### What sets the speed

The help texts name a PID controller per mode and a target consumption;
812170 prints a target at 88, 0 by default. Measured on the evening of
2026-11-06: the speed climbed while the mean of 74 was positive and fell
while it was negative. With 88 at 0 that is a controller driving the mean of
74, an export, toward 88. If so, 88 is the lever a consumer lacks: a target
for the export, so that writing the meter's export with 88 at -1.0 would ask
the controller to draw 1.0 kW from the grid beyond the PV, and 88 at +0.5 to
leave 0.5 kW unused. Untested; 88 has read 0.0 in every scan.

### What stops it

812184: available PV power below the requested, after the minimum runtime.
Measured: a stop 72 s into a negative mean at 81 rps (morning), and one at
the floor after 8 minutes 10 seconds, before the 10 minutes of 5412
(evening). Not settled what "requested" is, or why the minimum runtime did
not hold.

### What holds off the next start

5419, 10 minutes of standstill. Measured: no start in ten minutes on 1.7,
from nine minutes after a PV stop, with B38 6 K below the hysteresis
threshold. Not settled. The request reason, `heatpump.info`, would show
whether the controller registered a PV request at all.

### What the controller does with a value no one renews

812184 and the help text of `N2D_PVStaticHousepwrActive`: the fallback house
consumption `SYSPV030` takes over "when the smart meter hasn't delivered any
new values for more than 5 hours". 74 read -0.5 8 h 10 min after the last
write, on 2026-11-06; the register holds. Not settled what the control uses;
`controller-behavior-when-glt-values-stop-unknown` plans that test.

## Observations that would settle these

Each is a read that the tests so far did not take:

1. **12763 during a run**, at Fachmann level with `idm-web --watch`: the
   internal value of 74, whether it is the mean, the value written or the
   value plus the draw, and of 88.
2. **The request reason**: `heatpump.info` of the `system` overview, every
   10 s. `idm-web --watch` reads settings only; this needs the `Query` for
   the `system` overview in a watch, a change to `idm-web`.
3. **The PV graph at a finer step**: whether graph 101 serves points closer
   than 304 s for a short `fromSecs`.
4. **The setting behind each PID name**, if any: a webapi capture at
   Fachmann level during a run, searched for `CA20PV` and `POWERTARGET`.
5. **88 written**: a test of its own, once 1 and 2 show what 74 does inside
   the controller.
