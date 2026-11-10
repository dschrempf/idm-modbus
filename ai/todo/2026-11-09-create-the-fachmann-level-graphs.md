# Create the graphs of the Fachmann level's channels

The controller records every graph channel whether or not a graph holds
it, but a read reaches a channel only through a graph
(`doc/verification-2026-11-09-graphs-record-every-channel.md`). Seven
graphs hold the 37 channels of the Kunde level. The 17 the Fachmann level
adds are the refrigerant circuit's and in none: 23 B71 hot gas, 26 B37 air
in, 28 B79 and 29 B78 evaporator outlet and pressure, 55 M51 four-way
valve, 60 M63 priority valve, 76 fan speed, 91 superheat, 93 valve
position, 145 `T25x_AIN_TEVAP`, 146 `T25x_AIN_TCOND`, 148 `T23xPRS`, 149
inverter temperature, 153 B86 condenser pressure, 180 reversing valve, 182
B87 liquid pipe, 188 subcooling. They say what the compressor did through a
run, a defrost or a stop, after the fact, to a person at the web
interface. A run reads the same circuit live from the web watch, 4768
`N2_SENSORS`, 5888 `N2_EVR_OVERVIEW` and 6245, not from a graph: a graph
is edited by hand and can change under it (decided 2026-11-10).

## How we might solve it

1. `idm-web HOST --enter-fachmann`; the user creates one or two graphs
   holding the 17 in the web interface, a `save` and so by hand.
2. A webprobe walk at Fachmann level, then `--leave-fachmann` and one at
   Kunde: whether the new graphs answer with history, and whether they
   answer at Kunde level at all.
3. Record it in `doc/verification-2026-11-09-graphs-record-every-channel.md`
   or a new dated `doc/`, and in `ai/doc/web-backend-and-captures.md`.

## Done on 2026-11-10, but for one channel

Created by hand at about 20:50: 106 "Temperatures (Fachmann)" holds 23,
26, 28, 91, 145, 146, 149, 182 and 188; 107 "Pressures and actuators
(Fachmann)" holds 29, 53, 55, 76, 93, 148, 153 and 180. 60 M63
`Vorrangventil` is in neither: a graph takes ten channels at most, and 107
has room. 148 `T23xPRS` is "rps", the compressor's speed. The built-in
graph 2 "Kältewerte", user level 2, holds 23, 91, 145, 146 and 188 beside
10000 to 10004. Graph 106 answered `detail` with points over the past hour,
from before it was created. At Kunde level, at 21:37 after the run, 106
answered no channel, 107 only 53 and 2 only 10000 to 10004: a graph answers
the channels of the level the controller is at
(`captures/navigator-10-webgraph-20.24-2608-2026-11-10-2137.json`). The
walk at Fachmann level of 21:24 holds the run's five-minute means
(`captures/navigator-10-webapi-20.24-2608-2026-11-10-2124.json`). Left: 60
into 107.
