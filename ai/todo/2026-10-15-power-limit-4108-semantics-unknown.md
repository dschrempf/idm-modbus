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
