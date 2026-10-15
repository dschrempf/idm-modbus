# What the power limit at 4108 does is unknown

## The question

`N2_GLTMON` lists 4108 `Leistungsbegrenzung Wärmepumpe` and 4112
`Leistungsbegrenzung Kaskade` as `RW` `FLOAT`s; 812170 does not have them.
The table carries them as `gltmon` rows with the width measured and nothing
else (`doc/verification-2026-10-14-gltmon.md`). Unknown:

- the unit: kW or percent of the rated power;
- the persistence: volatile or EEPROM;
- whether it caps the inverter's draw, and in which modes;
- what reading it at rest returns, and whether that means "no limit".

A consumer matching the draw to a PV surplus, or obeying a grid operator's
dimming, would use it — it is the only lever that says "run, but at most
this much".

## How we might solve it

1. Read 4108 and 4112 beside their web settings, if the settings tree has a
   matching one; a matching identifier gives the persistence through the
   parameter list's family.
2. Once writing exists and the persistence is known: during a long run,
   write a limit below the present draw and watch 4122, the modulation
   (setting 6245, `N2_MODULATION_OVERVIEW`) and 1090. Remove the limit.
3. Record the outcome in a dated `doc/`.
