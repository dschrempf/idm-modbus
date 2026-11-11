# The web backend

The controller's web interface is a single-page application, and every value
it prints arrives over a websocket. That websocket is the package's second
channel. It carries what Modbus lacks — the refrigerant circuit, the
inverter, the request reason, the history — and the manufacturer's parameter
identifier beside every setting, which is what joins a setting to its
register ([registers.md](registers.md)).

## The protocol

The websocket is `ws://HOST:61220`; the local PIN travels in the URL as
`auth_code`. Messages are JSON, `{controller, command, data}`. The
controller's JavaScript names five commands: three read, `overview`,
`detail` and `traverse`, and two write, `save` and `execute`
([2026-09-20-webapi](verification/2026-09-20-webapi.md)). `overview` on a
menu yields its children, `detail` on a leaf its value, unit, limits and
`param`. `IDM.Navigator.Web` has a constructor for each read and none for a
write; the two writes of `IDM.Navigator.Web.Level` are the exception. Nor
does it, or `tools/webprobe.py`, send two reads: `relaytest`/`overview`,
which opens the relay test, and `authentication`/`overview`, which asks with
`userlevel` 4.

Timestamps are seconds since 2000-01-01 in the controller's local time; the
status page's `timestamp` is milliseconds since 1970, also local. The
controller's clock runs its own course: 82 s ahead of NTP on 2026-10-01, 28 s
on 2026-11-07.

## What it shows that Modbus does not

No register in the parameter list or on the register page carries
([2026-09-20-display](verification/2026-09-20-display.md)):

- the refrigerant circuit: B71 Heißgastemperatur, B78/B78v
  Verdampfungsdruck and -temperatur, B79 Verdampferaustritt, B86/B86v
  Kondensationsdruck and -temperatur, B87 Flüssigkeitsleitung, superheat,
  subcooling, expansion valve position — 4768 `N2_SENSORS` and 5888
  `N2_EVR_OVERVIEW`;
- the inverter: status, motor speed, current, voltage, power, DC bus voltage
  — 6245 `N2_MODULATION_OVERVIEW`;
- board temperature and the central unit's battery voltage;
- most heating circuit settings: Raumeinflussfaktor, the mixer parameters,
  Estrich Heizen, Zuschaltzeit;
- the PV control's forecast and settings — 10263 `N2_PV_POWER` and the menu
  10256 `N2_PV` ([pv-control.md](pv-control.md#sources));
- the request reason, below;
- history, in the graphs, below.

Some registers have no page either: 1032 `FW030`, the cooling block on a
machine without cooling, 1006, the three demands 1091 to 1093, 1122 and
1123, 1124 and 1048 ([2026-09-20-webapi](verification/2026-09-20-webapi.md)).

## The user level

The controller stands at Kunde, user level 0, or Fachmann. Several pages
answer only at Fachmann: 5888, 6245, 12763 `N2_GLTMON`, 4838
`N2_SERVICE_INFO`, the PV menu 10256. At Kunde a `detail` of them stalls
rather than being refused, or answers "not accessible"
([2026-10-01-charge](verification/2026-10-01-charge.md),
[2026-11-07-restart](verification/2026-11-07-restart.md)).

`IDM.Navigator.Web.Level` enters Fachmann with a `setting`/`save` of item
12503, a code spelled from the controller's clock, from Kunde only, and
leaves it by acknowledging the notice `N2_USERLEVELACTIVE`. The display
switches with it: the level is the controller's, not the connection's. A
restart returns it to Kunde.

The controller ends the level itself. On 20.24-1574 it fell back sixty
minutes after the entry, however often it was read meanwhile
([2026-10-01-charge](verification/2026-10-01-charge.md)). On 20.24-2608 it
fell back after about ten and eight minutes on 2026-11-05, held 73 minutes
until left by hand on 2026-11-06, and held sixty minutes under a 10 s watch
on 2026-11-09
([2026-11-05-software-update](verification/2026-11-05-software-update.md),
[2026-11-09-heating-run-as-on-1574](verification/2026-11-09-heating-run-as-on-1574.md)).
What ends it on 20.24-2608 is open. An entry sent seconds after a leave
answers success and leaves the level at Kunde; sent again 20 s to 1.5 min
later it takes.

`idm-web --watch --fachmann` holds the level for a watch: it enters it,
renews it 55 minutes from the entry by leaving it and entering again 30 s
later, and leaves it on exit. A 70-minute watch on 2026-11-11 held it so,
the renewal took, and in the pause 5888 and 6245 answered "not accessible"
at once ([2026-11-11-the-web-watch-renews-the-fachmann-level](verification/2026-11-11-the-web-watch-renews-the-fachmann-level.md)).

## The request reason

The `system` overview's `heatpump` carries `operationMode` and, while a
request stands, `info`, a bitmask the web interface's JavaScript names. In
heating: 4 `RD_REQ_EXTERNAL_DI`, 8 `RD_REQ_EXTERNAL_BUS`, 16 `RD_REQ_ISC`,
32 `RD_REQ_PV`, 64 `RD_REQ_FROST_PROT`, 128 to 8192 the circuits
`RD_REQ_HK_A` to `RD_REQ_HK_G`, 16384 `RD_REQ_SYS_OFF`, 32768 `RD_REQ_ION`,
65536 `RD_REQ_HEATING_BOOSTER`; bit 1 is cleared before counting and not
named, and more than one other bit reads `RD_REQ_MORE_DEMANDS`. Hot water
and cooling have tables of their own; `reasonBits` in `IDM.Navigator.Web`
transcribes all three. The `home` controller's `detail` carries the same
`info` per widget ([pv-control.md](pv-control.md#sources)).

At rest and in a defrost `info` is absent. A circuit's request read 513, bits
1 and 512, `RD_REQ_HK_C`, and the interface printed "Anforderung HK C"
([2026-11-09-heating-run-as-on-1574](verification/2026-11-09-heating-run-as-on-1574.md));
a PV run read 33, `RD_REQ_PV`
([2026-11-09-power-limit-floor](verification/2026-11-09-power-limit-floor.md)).
A second circuit whose flow fell more than 1 K below its target while the
heat pump ran never added its bit: either a circuit does not request while
the heat pump runs, or `info` holds only the request that started it.

## Graphs

`graph`/`overview` lists the graphs, `traverse` every channel the
controller can plot, and `detail` with a graph's `id` and `fromSecs`, a span
back from now, a graph's history. The interface asks 30 hours and eight
days; eight days is as far as the history reaches.

**The controller records every channel**, whether or not a graph holds it.
A channel put into a new graph answers with its history from before, back as
far as any graph's. A graph chooses what a read returns, not what is
recorded. A graph holds ten channels at most and is created or changed by a
`save`, by hand in the web interface; no read reaches a channel outside a
graph ([2026-11-09-graphs-record-every-channel](verification/2026-11-09-graphs-record-every-channel.md)).

**A graph answers the channels of the current level.** At Kunde `traverse`
lists 37 channels, at Fachmann 54; the 17 more are the refrigerant
circuit's. Read at Kunde, a graph of Fachmann channels answers none, and a
mixed one its Kunde channels. The built-in graph 2 `Kältewerte`, at level 2,
is left out of the Kunde `overview` but answers a `detail`
([2026-11-10-a-graph-answers-the-channels-of-the-current-level](verification/2026-11-10-a-graph-answers-the-channels-of-the-current-level.md)).
So a run reads the refrigerant circuit live, from 4768 and 5888, not from a
graph.

**A temperature's point is the mean over the interval it closes**, stamped
at the interval's end. The controller thins what it keeps: points every 5
minutes for about the last half hour, then about every 50 minutes, and every
1.6 hours in the eight-day span, whatever the span asked. A state channel
has a point per change. A graph says what the machine did while nobody
watched; it does not replace a watch, and flattens a peak
([2026-10-01-charge](verification/2026-10-01-charge.md),
[2026-11-09-graphs-record-every-channel](verification/2026-11-09-graphs-record-every-channel.md)).
On 20.24-1574 before the restart of 2026-09-23 the state channels were
stamped an hour early; since then their edges match the registers', offset
by the controller's clock alone. A restart lays the history out anew
([2026-11-07-restart](verification/2026-11-07-restart.md)).

## Statistics

The statistics page books heat, runtime and electrical energy per day, month
and in total. Its runtime and electrical energy agree with the registers; its
heat does not, and it books a day without runtime
([registers.md](registers.md#the-wärmemenge-counters-1746-to-1762)).
