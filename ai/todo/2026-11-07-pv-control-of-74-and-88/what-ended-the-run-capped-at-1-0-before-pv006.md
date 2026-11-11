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

- **A time of about 30 minutes**, for a capped run or one at low speed; the
  run on 1.5 held 46 min 30 s. An uncapped run at the floor and above held
  77 minutes on 2026-11-11, so a time would be the cap's.
- **Ruled out: B45 `Ladefühler` or the flow against `PV006`.** On
  2026-11-11 B45 and B125 stood above 40 °C for 11 minutes before a stop
  that came with B38 at 40.01 °C
  (`doc/verification/2026-11-11-the-pv-control-holds-74-at-0-25.md`).

## How we might solve it

1.0 again, from a store near 30 °C, as on 2026-11-09, with 1066
`Ladefühler (B45)` and 1070 `Vorlauftemperatur Wärmesenke (B125)` added to
the Modbus watch (1050, named after B33, answers -1 on this machine:
`doc/verification/2026-09-20-display.md`), and a webprobe walk within half an
hour of the stop, while the graph still holds its five-minute samples. A stop
near 30 minutes with B38 well below 40 is the time.

The 2026-11-09 run as a schedule for `idm-drive`,
`schedules/pv-limit-1-0.toml`, with the watch of
`schedules/pv-clamp-0-1.toml`, which has 1066 and 1070:

    IDM_PIN=... cabal run idm-web -- HOST --watch 10 --reason --fachmann 4768 5888 6245 10263 12763 > webwatch.jsonl
    cabal run idm-drive -- HOST schedules/pv-limit-1-0.toml > drive.jsonl
    IDM_PIN=... tools/webprobe.py HOST > webapi.json
