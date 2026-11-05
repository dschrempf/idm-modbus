# Write interface: EEPROM guard and tests still open

What the 2026-11-05 review of the write interface left open: decisions, and
one measurement on the machine. The review's other findings are fixed in the
working tree. They are the overflow to +Inf in `encode`, `costAt` checking a
target's type against the table, the refusal of a write-only EEPROM target,
and the stale help text and comments.

## Outcome

Closed on 2026-11-05. The two code items are done, each with its outcome in
its file. The measurement has its own todo,
`eeprom-guard-needs-exact-round-trip`. It stays the gate for the first
EEPROM target, 4108 in session 6b of `run-the-open-todos-in-six-sessions`.

- `write-decision-logic-untested.md`: the branch of `write` that guards the
  EEPROM had no check; now a pure core, checked against a fake controller.
- `write-multiple-quantity-unbounded.md`: `WriteMultiple` and `Quantity`
  admitted counts Modbus forbids; now one register or two, and a smart
  constructor.
