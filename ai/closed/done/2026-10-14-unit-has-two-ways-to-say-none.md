# `Unit` has two ways to say "no unit"

`registerUnit :: Maybe Unit`, and `Unit` has `Unitless`. `parseUnit` only
sees non-empty text (`src/IDM/Navigator/Table.hs`), so `Unitless` is never
built and "no unit" is always `Nothing`. Drop `Unitless`, or make the field
`Unit` and drop the `Maybe`. Public API either way.

Fixed on 2026-10-14: `Unitless` is gone and `registerUnit` stays a `Maybe`,
since an empty cell says the source states no unit, not that the quantity has
none.
