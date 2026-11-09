# Target values typed per register

`write` takes an untyped `Value`, so sending a `Flag` to a `FLOAT` is a
`Refusal` at run time rather than a type error. A second index, `Target c a`,
would fix the value's type per constructor: `Double` for a temperature or a
power, `Bool` for a request, an enumeration for an operating mode.

The enumerations meet the 1005 defect first
(`decide-how-a-measured-fact-enters-the-table`): the table lacks -1 "Aus" and 3
"Urlaub". Settle that first.
