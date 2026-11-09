# Target values typed per register

`write` takes an untyped `Value`, so sending a `Flag` to a `FLOAT` is a
`Refusal` at run time rather than a type error. A second index, `Target c a`,
would fix the value's type per constructor: `Double` for a temperature or a
power, `Bool` for a request, an enumeration for an operating mode.

For an enumeration the table has what this needs: `registerScale` marks it,
and its codes, 1005's measured -1 "Aus" and 3 "Urlaub" among them
(`decide-how-a-measured-fact-enters-the-table`), are in the enums table.
