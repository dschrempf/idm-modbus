# What ended the run capped at 1.0 before `PV006` is unknown

The run of the evening of 2026-11-09, 74 at a constant 2.0 and 4108 at 1.0
from before the start, held 1.01 kW for 26 minutes past the start program
and ended 30 min 50 s after the start: the controller withdrew the
request, `info` 33 to 0, before the compressor stopped, with B38 at
37.9 °C, 2.1 K below `PV006`, and no error, lock or defrost
(`doc/verification/2026-11-09-power-limit-held-at-1-0.md`). The run on 1.5
of 2026-11-08 went on to B38 at 40.00 °C. A consumer holding a long low
run needs to know what ends it.

## Candidates

None ruled out:

- **B45 `Ladefühler` against `PV006`.** B45 is the water going into the
  store, about 2 K above B38 while it charges. The graph's five-minute
  means put it near 39.6 °C at the stop, below 40
  (`doc/verification/2026-11-09-graphs-record-every-channel.md`). Against
  it, as against the flow: on 2026-11-08 it must have passed 40 well before
  that run ended at B38 40.00 °C.
- **The flow, B33, against `PV006`.** It read 39.8 °C at the stop. Against
  it: on 2026-11-08 B38 reached 40.00 °C, so the flow, above B38 while the
  store charges, stood above 40 for a while without ending that run.
- **A time of about 30 minutes**, for a capped run or one at low speed; the
  run on 1.5 held 46 min 30 s.

## How we might solve it

1.0 again, from a store near 30 °C, as on 2026-11-09, with 1066
`Ladefühler (B45)` and 1070 `Vorlauftemperatur Wärmesenke (B125)` added to
the Modbus watch (1050, named after B33, answers -1 on this machine:
`doc/verification/2026-09-20-display.md`), and a webprobe walk within half an
hour of the stop, while the graph still holds its five-minute samples. A stop
near 30 minutes with B38, B45 and the flow well below 40 is the time; a stop as
B45 or the flow reaches 40 is the temperature.

The 2026-11-09 run as a schedule for `idm-drive`,
`schedules/pv-limit-1-0.toml`, with the watch of
`schedules/pv-clamp-0-1.toml`, which has 1066 and 1070:

    IDM_PIN=... cabal run idm-web -- HOST --watch 10 --reason --fachmann 4768 5888 6245 10263 12763 > webwatch.jsonl
    cabal run idm-drive -- HOST schedules/pv-limit-1-0.toml > drive.jsonl
    IDM_PIN=... tools/webprobe.py HOST > webapi.json
