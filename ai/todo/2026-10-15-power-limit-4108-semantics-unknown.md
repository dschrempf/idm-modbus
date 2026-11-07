# What the power limit at 4108 does is unknown

## The question

`N2_GLTMON` lists 4108 `Leistungsbegrenzung Wärmepumpe` and 4112
`Leistungsbegrenzung Kaskade` as `RW` `FLOAT`s; revision 10 of 812170 does
not have them. Unknown were:

- the unit: kW or percent of the rated power;
- the persistence: volatile or EEPROM;
- whether it caps the inverter's draw, and in which modes;
- what reading it at rest returns, and whether that means "no limit".

Revision 12 answers the first two for 4108 (below, 2026-11-05); the last two
stand.

A consumer matching the draw to a PV surplus, or obeying a grid operator's
dimming, would use it — it is the only lever that says "run, but at most
this much".

## Found on 2026-10-15

Step 1, existing captures: no setting matches. The translations have
`N2_POWER_LIMIT_HEATPUMP` and `N2_POWER_LIMIT_CASCADE`, named as the page
names 4108 and 4112, but no captured tree holds them. The tree has `EV003`
`N2_EVU_SPERRMODUS`, whose option 1 limits the draw while the grid operator's
contact is open, by a parameter in kW, default 4.2, that the capture does not
hold. 4108 reads -1.0 at rest and while heating, so it is not that
parameter's stored value. `N2_GLTMON`'s `GLT Value` column reads -1 for 4108,
4112 and 4132 to 4140, and for no other row
(`doc/verification-2026-10-15-web-app.md`). Step 1's second half, a watch of
12763 beside the registers, is in session 2.

## Found on 2026-10-16

Step 1's second half: 4108 and 4112 read -1.0 at every read of a heating run,
a hot water charge and a defrost, and `N2_GLTMON` printed -1.0, `GLT Value`
-1, throughout (`doc/verification-2026-10-16-draw.md`). Nothing joins them to
a setting; step 1 is done, and only writing can go further.

## Found on 2026-11-05

Revision 12 of 812170 prints 4108 `Leistungsbegrenzung Wärmepumpe` and 4112
`Leistungsbegrenzung Kaskade`, both `FLOAT`, `RW`, in kW, with a default of
-1 and no EEPROM mark, so the table has 4108 from the manual, volatile. -1
at rest is the default, which suggests "no limit" without saying it.

On 20.24-2608 4112 is no longer a `FLOAT`: 4112 and 4113 each answer alone,
and the table drops it (`adapt-to-software-20-24-2608`, `table-rebuild.md`).
The page now prints 4108 as `Leistungsbegrenzung  (kW)`, 4112 without a
name at 0.0, and beside it 4110 `Sperre`, 4113 and 4114 `Sperre Booster 1`
and `2`, all `RW`, all 0. What the locks do is as unknown as the limit. Only
4108 is left to this note, and step 2 costs no EEPROM cycle.

## How we might solve it

1. Read 4108 and 4112 beside their web settings, if the settings tree has a
   matching one; a matching identifier gives the persistence through the
   parameter list's family.
2. Once the persistence is known, activated as a target: during a long run,
   write a limit below the present draw and watch 4122, the modulation
   (setting 6245, `N2_MODULATION_OVERVIEW`) and 1090. Remove the limit.
3. Record the outcome in a dated `doc/`.

## 2026-11-07: the lever for a low PV run

No value written to 74 or 88 holds a PV run low past the minimum runtime
(`doc/pv-control.md`, "What holds a run at low power"): a constant surplus
drives the speed to the top, about 4 kW, and 74 at 0 ends the run at 10
minutes. A cap that holds the draw near the floor, 0.6 to 0.74 kW, under a
constant surplus would give a long low run, which is what
`pv-control-of-74-and-88` now aims at; this is its step 1.

Step 2 as a PV run: 4108 listed in `data/navigator-2.0-targets.tsv` and the
module regenerated, then a store charge with 74 at a constant 2.0 and 4108
written 0.8 a few minutes after the start, renewed beside 74, and -1 at the
end. What answers it: 4122 and 6245's speed against the limit, and whether
the run goes on to `PV006` or ends at the minimum runtime. The schedule
driver writes only 74 and 88, so it needs a third value, or the limit is
written by hand with `idm-write`.

## 2026-11-07: volatile, measured

Listed as the target `HeatPumpPowerLimit`. 3.0 written at rest read back,
`N2_GLTMON` listed it with a `GLT Value` of 3.0, and it held for six minutes
unrenewed; after `System Neustart` it read -1.0, so the EEPROM does not hold
it (`doc/verification-2026-11-07-restart.md`). The walk at Fachmann level
holds no setting for it either. Persistence and unit are settled; whether
it caps the draw, and in which modes, is step 2, now the PV run of
`pv-control-of-74-and-88`. Since 4108 costs no EEPROM cycle, the run may
renew it beside 74.

## 2026-11-07: below the draw, it ends a run

A PV run on 74 at a constant 2.0, with 0.8 written to 4108 at 112.5 rps
and 3.1 kW, five minutes after the start: the compressor stopped within
9 s, the request with it, before the minimum runtime, and 1004 reported
nothing (`doc/verification-2026-11-07-power-limit.md`). Not a cap at that
distance. Open: whether a limit above the start program's 1.2 kW, written
before the start, caps the draw as it climbs or ends the run when the draw
reaches it, and whether a limit below the forecast holds off a start. Next:
4108 at 1.5 from the first phase,

    tools/drivepv.py HOST watch.jsonl --final -0.5 --final-target 0 --final-limit -1 \
      2.0/20/ein/0/1.5 2.0/20/aus//1.5 > write.log

A speed that climbs past the start program and holds near 1.5 kW is a cap;
then lower the limit in steps toward the floor.
