# Float sentinel swallows the averaged outdoor temperature at -1.00 °C

`navigator` (`src/IDM/Navigator/Register.hs`) reads every `FLOAT` equal to
`-1.0` as `NotFitted`. Its haddock claims that happens only where the sentinel
lies outside the documented range, but no `FLOAT` in the table has a negative
minimum, and outdoor, air intake and heat source temperatures pass through
-1 °C every winter.

Live sensors arrive at full precision (1000 read `20.782480…` in
`captures/navigator-2.0-scan-2026-09-20-2141.json`), so an exact `-1.0` is
unlikely there. 1002 `Gemittelte Außentemperatur` arrives rounded to
hundredths (`20.260000…`), so whenever the average stands at -1.00 °C the
library reports the sensor unfitted.

Options, for Dominik to choose:

- apply the `-1.0` rule only to registers the table records `absent`; but
  presence is one machine's, and 1050/1052 answer `-1.0` while `present`
- a third constructor for a value that is the sentinel and also a possible
  reading, so a caller has to decide
- no rule for `FLOAT` registers whose quantity can be negative

Related: `2026-10-14-notfitted-overclaims-absence`.
