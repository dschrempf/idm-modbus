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
run, a defrost or a stop, after the fact.

## How we might solve it

1. `idm-web HOST --enter-fachmann`; the user creates one or two graphs
   holding the 17 in the web interface, a `save` and so by hand.
2. A webprobe walk at Fachmann level, then `--leave-fachmann` and one at
   Kunde: whether the new graphs answer with history, and whether they
   answer at Kunde level at all.
3. Record it in `doc/verification-2026-11-09-graphs-record-every-channel.md`
   or a new dated `doc/`, and in `ai/doc/web-backend-and-captures.md`.
