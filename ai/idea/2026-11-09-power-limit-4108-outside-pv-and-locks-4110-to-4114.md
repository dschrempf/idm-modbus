# 4108 outside a PV run, and the locks at 4110 to 4114

What 4108 `Leistungsbegrenzung Wärmepumpe` does outside a PV run, for a
grid operator's dimming, and what the locks 4110 `Sperre`, 4113 and 4114
`Sperre Booster 1` and `2` do, all `RW` and 0 at rest on 20.24-2608. Inside
a PV run 4108 is settled
(`doc/verification/2026-11-09-power-limit-floor.md`,
`doc/verification/2026-11-09-power-limit-held-at-1-0.md`); the rest needs
writes of its own, each volatile as far as 4108 shows. No consumer waits on
it: the house is not dimmed, and the PV control does not need the locks.

The history is in the closed `power-limit-4108-semantics-unknown`, the
dropped mail to iDM support in
`ask-idm-support-for-812170-covering-20-24-2608`.

## How we might solve it

1. 4108 at a limit below the draw during a heating run on a circuit's
   demand, watched as the PV runs were: whether it caps, ends or is
   ignored.
2. Each lock written 1 at rest and during a run, with the request reason
   watched, and 0 after.
