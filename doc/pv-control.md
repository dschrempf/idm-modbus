# The controller's PV control: what the sources say, and how to watch it

The runs on 74 so far (`doc/verification-2026-11-05-pv-surplus.md`,
`doc/verification-2026-11-06-pv-surplus-own-draw.md`,
`doc/verification-2026-11-06-pv-surplus-loop.md`,
`doc/verification-2026-11-07-pv-target.md`,
`doc/verification-2026-11-07-pv-target-ignored.md`,
`doc/verification-2026-11-07-power-limit.md`,
`doc/verification-2026-11-08-power-limit-cap.md`) each answered a question
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
  `de.json` of `captures/navigator-10-webui-20.24-2608-2026-11-05-1641/`:
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
  - iDM's other controllers name their I a reset time: `N2_PID_HEAT_TN`
    "PID Heat Tn(I)", `N2_HC_MIXER_I` "Mischer Nachstellzeit", and
    `N2D_EVR_SUBCOOLING_I`, "Reset time … Increasing this parameter makes
    the subcooling control slower". The cascade's staging gives one reading
    each: `N2D_COMPRESSOR_STAGES` has a faster start from "increasing the P
    component … and decreasing the I component (I=2.0)", a reset time;
    `N2D_CASCADE_STAGE_CONNECTION_P` has P doubled and I "reduced by one
    third" against overshoot, a gain.
- **The PV menu at Fachmann level**, 10256 `N2_PV`
  (`captures/navigator-10-webapi-20.24-2608-2026-11-06-1148.json`, in no
  Kunde capture): after `PV011` and `PV015`, three settings of type `float`
  with no unit, range 0 to 1000, each at its default:

  | Setting | Name                     | German              | Identifier | Value | Step |
  | ------- | ------------------------ | ------------------- | ---------- | ----- | ---- |
  | 10403   | `N2_MOD_POWER_CONTROL_P` | Leistungsregelung P | `IV017`    | 5.0   | 0.1  |
  | 10410   | `N2_MOD_POWER_CONTROL_I` | Leistungsregelung I | `IV018`    | 10.0  | 1.0  |
  | 10417   | `N2_MOD_POWER_CONTROL_D` | Leistungsregelung D | `IV019`    | 0.0   | 0.1  |

  Their help texts are the untranslated keys, and neither 812170 nor 812184
  names them. The identifier files them with the modulation, `IV002` and
  `IV003`. The menu holds one set of gains for the three outputs `Y`.

- **The PID vocabulary**, from
  [Wikipedia, "PID controller"](https://en.wikipedia.org/wiki/PID_controller).
  The output u follows the error e, the setpoint less the measurement, as
  u = Kp·e + Ki·∫e dt + Kd·de/dt, or in the standard form
  u = Kp·(e + (1/Ti)·∫e dt + Td·de/dt), so Ki = Kp/Ti and Kd = Kp·Td. Ti,
  German Tn or "Nachstellzeit", is a reset time: the larger it is, the weaker
  the integral. The proportional term alone leaves an offset; the integral
  term removes it, keeps moving the output while the error keeps its sign,
  and holds the output where it is once the error is zero. Raising Kp or Ki
  speeds the response and raises overshoot; Kd damps overshoot and amplifies
  noise, and is "seldom used in practice". An integral that keeps
  accumulating while the output is at its limit winds up and holds the
  output there after the error turns; clamping it is one remedy.
- **The web interface's JavaScript**, `main-7UP7UE6I.js` of the same
  capture: a function that reads `heatpump.info` of the `system` overview
  with the operating mode and names the reason for a request. In heating
  mode bit 32 is `RD_REQ_PV`; the others are `RD_REQ_EXTERNAL_DI` (4),
  `RD_REQ_EXTERNAL_BUS` (8), `RD_REQ_ISC` (16), `RD_REQ_FROST_PROT` (64), the
  circuits `RD_REQ_HK_A` to `RD_REQ_HK_G` (128 to 8192), `RD_REQ_SYS_OFF`
  (16384), `RD_REQ_ION` (32768) and `RD_REQ_HEATING_BOOSTER` (65536); more
  than one bit reads `RD_REQ_MORE_DEMANDS`. Hot water and cooling have
  tables of their own. The webapi capture at rest,
  `captures/navigator-10-webapi-20.24-2608-2026-11-06-1148.json`, has no
  `info` in its `heatpump`.
- **The GLT monitor**, 12763 `N2_GLTMON`, at Fachmann level: per address a
  `Value`, the controller's internal one, and a `GLT Value`, the last one
  written (812170 §4.4). On 2026-10-16 it listed 74 to 88 with an empty
  `GLT Value`
  (`captures/navigator-10-webwatch-20.24-1574-2026-10-16-0748.jsonl`).
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
minutes; a mean of about 1.0 against 0.7 kW did, and on 2026-11-07 one of
about 1.2 against 0.7 kW did within 71 s. A margin of about 0.3 kW fits
all three; the Home Assistant thread says 500 W. `PV015` is not it: 10396
reads 0 (`captures/navigator-10-webapi-20.24-2608-2026-11-06-1148.json`).
Not settled whether the margin is a setting.

### What sets the speed

The help texts name a PID controller per mode and a target consumption;
812170 prints a target at 88, 0 by default. The PV menu holds the gains,
`IV017` to `IV019`: P 5.0, I 10.0, D 0.0. With D at 0 the controller is a
PI controller. Whether `IV018` is a Ki or a Ti, and the units of either, no
source states; iDM names an I a reset time elsewhere, but not consistently.

The two runs of 2026-11-06 read as such a controller, with the error the
mean of 74 over `PV011` less a target of 0:

- **The integral term dominates.** At 11:28, 0 written held the run at
  120 rps for 3 minutes; a proportional term alone has nothing to hold it
  with at an error of 0. In the evening the speed climbed while the mean
  fell from 1.70 to 0 and peaked 10 s after it crossed zero: an output
  following the error's integral, not the error.
- **How long the top holds once the mean turns is not explained.** In the
  morning the speed stood at the top, 120 rps, for over seven minutes with
  the mean positive, and fell 20 s after -0.5 was written, the mean then
  about -0.08: no sign of an integral wound up past the limit. On
  2026-11-07 it held the top for 100 s after the mean crossed zero, down to
  -1.65, after barely a minute there.
- **The output is bounded** by the heating floor `IV003`, 20 % or 24 rps,
  and `IV002`, 100 %, 120 rps; the evening run reached the floor.
- **The overshoot of the evening is the integral against a lag.** The
  controller sees 74 only through `PV011`'s two-minute mean, and a consumer
  writing the meter's export closes a second loop through it: a change of
  speed reaches the error up to two minutes later, and the integral keeps
  climbing meanwhile. The controller's own levers are a shorter `PV011`, a
  weaker I and a D above 0, each a Fachmann setting at the display or a web
  `save`, which this package does not send.
- **Part of that overshoot was the test's.** The meter-style writes began
  at 20:00:22, with the two-minute window still full of the 1.7 written
  for the start; the mean read 1.70 while the values written were already
  negative, and the integral climbed on it for 90 s. A meter would have
  read 1.7 less the start program's 1.2 kW from the compressor's start.
  The first run of 2026-11-07 wrote 74 as a meter from the first write and
  overshot all the same: from the start program to the top, and a stop
  after 8 minutes.
- **The climb is the controller's, not a warm-up.** The start program holds
  50.4 rps for about 4 minutes; with the mean at 0 the speed held 50.4 for
  nearly 6 minutes after it (2026-11-07).

Not settled: the form and units of `IV017` and `IV018`, whether the target
is 88, `N2_PV_POWERTARGET` or both, and whether one set of gains serves all
three outputs.

### What 88 would add

The hypothesis: 88 is the target of that controller, the export it holds
the mean of 74 at. The speed then moves with

    error = mean of 74 over PV011  −  88

up while the error is positive, down while it is negative, and holds where
the error is zero. Said as a draw, the controller aims at its draw plus the
error, which may be what the help texts call "Target Consumption",
`N2_PV_POWERTARGET`; 812184 shows a "Aktueller Aufnahme Zielwert" for
Solar-Log only.

For it: 812170 prints 88 as `PV-Zielwert (Smartfox und Solar-Log)`, a
volatile `FLOAT` in kW, default 0, beside 74, and `PV008` is at
`N2_GLTSF`, "Gebäudeleittechnik/Smartfox". The Smartfox, the device this
path was built for, has a setting "Zielwert standardmäßig „0"" for an iDM
pump (812184), so it presumably writes 88 as it writes 74. Both runs of
2026-11-06 fit a target of 0, 88's value in every scan.

With it, a consumer writes the meter's export to 74 as it is and its
intent to 88:

| 88   | The run holds the export at | Use                                 |
| ---- | --------------------------- | ----------------------------------- |
| 0    | 0: all of the surplus       | the default                         |
| +0.5 | 0.5 kW left over            | room for another load, a battery    |
| -1.0 | 1.0 kW drawn from the grid  | a cheap tariff, a charge without PV |

The last row is the consumer's first use, a store charge at low power,
asked for without inventing a surplus at 74.

What 88 would not change:

- **The loop's dynamics.** 88 moves where the loop settles, not how it gets
  there. The overshoot comes from the gains and `PV011`.
- **That 74 must answer the draw.** With 74 fixed, the error never closes
  and the integral runs to a limit, whatever 88 is. Only a value that falls
  as the pump draws more, a meter's export or a simulated one, settles.
- **The speed, if the error is the difference.** Writing 74 less a target,
  with 88 at 0, then gives the same error as writing 74 and 88 at that
  target. 88 adds something only where the two differ: in what starts and
  stops a run, in the PV page and the graph, which print 74 as written, and
  in timing, if 88 is weighed at once rather than through `PV011`'s mean. A
  step of 88 would then show the proportional share of the response as an
  immediate jump of the speed, apart from the integral's ramp.

Measured on 2026-11-07 (`doc/verification-2026-11-07-pv-target.md`), with
74 held at 0 and the speed steady at 50.4 rps: 88 at -1.0 moved nothing in
3 minutes, so the last row does not hold, not then at least. 88 at +1.0 was
followed 40 to 50 s later by a fall to the floor and a stop, but at the end
of the minimum runtime, so that step does not settle whether 88 acts. The
PV page prints nothing that follows 88; 12763 lists it as written.

Measured on the evening of 2026-11-07
(`doc/verification-2026-11-07-pv-target-ignored.md`), the same way but
5 to 8 minutes after the start: 88 at +1.0 moved nothing in 3 minutes
either. Neither sign of 88 moves the speed; whether it weighs in the start
or the stop is open.

### What stops it

812184: available PV power below the requested, after the minimum runtime.
Measured: a stop 72 s into a negative mean at 81 rps (morning), and one at
the floor after 8 minutes 10 seconds, before the 10 minutes of 5412
(evening). On 2026-11-07 one after 8 minutes 0 seconds at 60 rps, falling,
with the mean at -1.23, and one at the floor after 10 minutes 21 seconds,
with the mean at 0 and 88 at +1.0. On the evening of 2026-11-07 one after
10 minutes 10 seconds at 50.4 rps, not falling, with 74 and 88 at 0 and the
store 9 K below `PV006`: 0 at 74 ends a run at the minimum runtime, as it
did not at 120 rps on the morning of 2026-11-06. Late that evening one
after 5 minutes 10 seconds at 112.5 rps, 9 s after 0.8 kW was written to
4108, with 74 at 2.0 throughout: a limit below the draw ends a run before
the minimum runtime. On 2026-11-08 one at `PV006`, after 46 minutes 30
seconds at 52 to 59 rps, with 74 at 2.0 and 4108 at 1.5 throughout. Not
settled what
"requested" is, why the minimum runtime did not hold, or why 0 held the one
run and ended the other.

### What holds a run at low power

The draw spans 0.6 to 0.74 kW at the heating floor, 24 rps, to about 4 kW
at the top, 120 rps; the start program holds 50.4 rps and 1.2 kW for about 4
minutes. Measured on 74 alone, none holds a run low past the minimum
runtime:

- **A constant above 0** drives the integral, and the speed, to the top
  (2026-11-06).
- **A mean of 0** holds the speed where it is, the start program's once
  that is over, and the run ends at the minimum runtime (both runs of
  2026-11-07 with 74 at 0).
- **A meter's export**, which falls as the pump draws more and so could
  settle the loop, overshot to the top and stopped before the minimum
  runtime with `PV011` at 2.0 min (2026-11-06 evening, 2026-11-07 noon).
  Where it settles, the mean is 0 again, which ended the evening run of
  2026-11-07.
- **88** moves neither the speed nor, by the runs so far, where the loop
  settles.

The levers outside the PV loop: 4108 `Leistungsbegrenzung Wärmepumpe`, a
`FLOAT` in kW, -1 by default, volatile as a restart showed
(`doc/verification-2026-11-07-restart.md`). Written 0.8 under a draw of
3.1 kW, it ended the run within 9 s rather than capping it
(`doc/verification-2026-11-07-power-limit.md`). Written 1.5 before the
start, beside a constant 2.0 at 74, it capped the run: the speed climbed one
step past the start program and held the draw near 1.4 kW for 42
minutes, until `PV006` ended the run
(`doc/verification-2026-11-08-power-limit-cap.md`). Whether a limit below
the start program's draw caps as well is untested. And
`IV002` `N2_MOD_MAX_POWER_HEATING`, a Fachmann setting in percent that would
cap every heating run, not only a PV one, and did not bind in the one run
that lowered it (`doc/verification-2026-11-05-floor.md`). That run also
shows a heating run held low without the PV loop: on a circuit's demand
with its flow near target, the speed came down to the floor and held it for
seven minutes.

### What holds off the next start

5419, 10 minutes of standstill. Measured: no start in ten minutes on 1.7,
from nine minutes after a PV stop, with B38 6 K below the hysteresis
threshold; on 2026-11-07 a request 29 min 59 s after a PV stop, on 2.0
standing for 24 minutes. So a PV start waits 30 minutes after a PV stop;
which setting holds them no source names. The request reason, `heatpump.info`, would show
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
   value plus the draw, and of 88. Read on 2026-11-07: both as written.
2. **The request reason**: `heatpump.info` of the `system` overview, every
   10 s. `idm-web --watch` reads settings only; this needs the `Query` for
   the `system` overview in a watch, a change to `idm-web`. A second
   witness, unverified here: Xerolux/idm-heatpump-hass reads the display's
   "Anforderungsgrund" from the `home` controller's `detail`, a bitmask per
   heating and hot water widget in which 32 is PV.
3. **The PV graph at a finer step**: whether graph 101 serves points closer
   than 304 s for a short `fromSecs`.
4. **The outputs `Y` and the target consumption**: the gains are at 10403
   to 10417, but no capture holds `CA20PV` or `POWERTARGET`. A webapi
   capture at Fachmann level during a run, searched for both, would show
   whether a page lists them.
5. **A simulated meter from the first write**: 74 written as a meter would
   read it with a fixed PV and the pump the only load, from before the
   start rather than after it, so no stale mean drives the integral. It
   shows whether the loop settles at all with these gains, and if not, its
   period and amplitude.
6. **88 written in steps** during such a run, 1 watched beside it: whether
   the draw follows 88, and, if 88 is weighed at once, the proportional
   and the integral share apart. A step at 74 cannot show them apart, as
   `PV011`'s mean turns it into a two-minute ramp.

5 and 6 were one run on 2026-11-07; it stopped before 88 was stepped, and
did not settle. 6 alone, with 74 held at 0, did in part: -1.0 moved
nothing, and +1.0 apart from the minimum runtime nothing either.
`does-88-set-the-export-the-pv-controller-holds` plans 5 again with
`PV011` at 0.5 min, which separates the mean's share of the overshoot from
the gains'.
