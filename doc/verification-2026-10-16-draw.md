# 4122 is the inverter's figure, and the heating run never reached its floor

2026-10-16. The controller's info page 6245, `N2_MODULATION_OVERVIEW`, prints
what the compressor's inverter reports: its status, the motor's speed, current,
voltage and power. Read every 10 s beside the registers, through a heating
run, two hot water charges and a defrost, 4122 follows the inverter's motor
power to the page's rounding. `N2_GLTMON` describes 4122 as the total
electrical power, "falls kein Wert vom Inverter vorhanden ist, wird jener vom
Polynom verwendet"; on this machine the inverter supplies one. The heating
run did not modulate down: after its start the compressor turned at 101 to
113 rps and drew 2.5 to 3.1 kW until it stopped, so what the heating floor,
`IV003` at 20 %, draws is still unknown.

## What was recorded

The run of [verification-2026-10-16-charge-pump.md](verification-2026-10-16-charge-pump.md),
which lists the captures and when the machine was in which mode. 6245 was
asked 970 times, the registers 4122, 4126, 1090 and 1100 986 times each.

## 4122 against the motor power

Each of the 384 readings of 6245 with the drive at `run` is set against the
4122 reads on either side of it. The nearer one differs from the page's
`motor power` by 0.004 kW on average, by at most 0.05 kW in 83 % of the
readings and 0.15 kW in 95 %; the page prints one decimal. Two differ by more
than 0.25 kW, both where the power moved within a round: 10:08:38, 2.1 against
1.76, and 10:12:58, the compressor starting at 4.6 rps, 0.6 against 0.28.

| Phase                  | Speed, rps  | `motor power`, kW | 4122, kW  |
| ---------------------- | ----------- | ----------------- | --------- |
| Heating, start         | 43.9–50.4   | 0.9–1.1           | 0.94–1.13 |
| Heating, 08:20–08:54   | 101.5–109.3 | 2.5–3.1           | 2.48–3.06 |
| Hot water, start       | 29.9–50.4   | 0.9–1.6           | 0.83–1.61 |
| Hot water, 10:07–10:10 | 64.7–65.1   | 1.8–2.1           | 1.74–2.07 |
| Defrost                | 50.4–78.0   | 1.0–2.4           | 0.80–2.51 |
| Hot water, 10:27–10:30 | 64.6–65.0   | 1.8–2.0           | 1.82–2.00 |

4122 is the inverter's figure, or a figure that tracks it to the page's
rounding through four kinds of operation. The question
[research.md](research.md) left open, inverter or polynomial, is settled for
this machine as far as a register can be. Whether the inverter's power
includes the fan and the pumps the page does not say; a meter on the supply
would.

## The heating run did not reach its floor

The heating run started with the compressor at 50.4 rps for three minutes,
08:11:59 to 08:14:59, drawing 0.9 to 1.1 kW. Both hot water charges started at
the same speed, though the hot water floor, `IV023`, is 40 % and the heating
floor 20 %: the 50.4 rps is a start program, not a floor. The heating run
then rose to 112.8 rps at 08:16:39, eased to 101.5 at 08:35:29, and rose
again to 106 by the stop at 08:54:53. The least it drew outside the start
was 2.48 kW by 4122.

So the controller never asked for less than about 100 rps while it heated,
and the run says nothing of the floor. The page prints the speed, not a
modulation in percent, and how `IV003`'s 20 % maps to a speed or a power is
not stated anywhere read so far. A run with less demand, a milder day or a
lower heating curve, would have to show it.

## What else the run showed

- **4126 goes negative in a defrost**, to -7.79 kW, while the pump drives
  the heat sink's water at 32 l/min: heat taken from the heat sink's water
  rather than given to it. The row documents no range, so `decode` reads it as a
  measurement; only exactly -1.0 would be `NoValueOr`.
- **4126 reads 0 while the pump stands at its minimum speed**, the four to
  five minutes at the start of each hot water charge when 1072 read no flow
  and the compressor already drew up to 1.6 kW. It is computed from the flow
  ([verification-2026-10-15-heat-sink.md](verification-2026-10-15-heat-sink.md)),
  so a coefficient of performance taken from 4126 and 4122 reads 0 there.
- **4108 and 4112 read -1.0 at every read**, in each of the four modes, and
  `N2_GLTMON` printed them as -1.0 with a `GLT Value` of -1 throughout. No
  operation moved them.

## Reproducing

    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
    IDM_PIN=... cabal run idm-web -- HOST --watch 10 6245 > webwatch.jsonl
    cabal run idm-dump -- HOST --watch 10 1090 1100 4122 4126 > watch.jsonl
    IDM_PIN=... cabal run idm-web -- HOST --leave-fachmann

while the machine runs, renewing the level every hour.
