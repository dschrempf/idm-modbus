# Write interface: EEPROM guard and tests still open

What the 2026-11-05 review of the write interface left open: decisions, and
one measurement on the machine. The review's other findings are fixed in the
working tree. They are the overflow to +Inf in `encode`, `costAt` checking a
target's type against the table, the refusal of a write-only EEPROM target,
and the stale help text and comments.

Nothing here blocks 74, which is volatile. `eeprom-guard-needs-exact-round-trip`
must be settled before the first EEPROM target enters
`data/navigator-2.0-targets.tsv`. The others are code, and need no machine.

- `eeprom-guard-needs-exact-round-trip.md`: `Unchanged` compares bytes, so
  the guard holds only if the controller reads back what was written; measure,
  or compare decoded values.
- `write-decision-logic-untested.md`: the branch of `write` that guards the
  EEPROM has no check; how to give it one.
- `write-multiple-quantity-unbounded.md`: `WriteMultiple` and `Quantity`
  admit counts Modbus forbids.
