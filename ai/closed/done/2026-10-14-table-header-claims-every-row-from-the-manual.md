# The table's module header claims every row is from the manual

The header of `IDM.Navigator.Table` says the table is "transcribed from the
manufacturer's manual". Since a023f37 it also holds the 19 rows of the
`source` `gltmon`, from the controller's `N2_GLTMON` page, and `navigator20`'s
own haddock already says so. Say it once, in the header, and point there.

While there: `navigator` in `IDM.Navigator.Register` has a case
`(OneRegister, Count _) -> Measured v` that the catch-all below it already
covers. Removed on 2026-10-14, in session 4.

Fixed on 2026-10-14, in session 5: the header names both sources and
`registerSource`, and `navigator20`'s haddock no longer repeats it.
