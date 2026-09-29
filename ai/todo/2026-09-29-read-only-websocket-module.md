# Read-only websocket module

Decided 2026-09-29: the library gains a typed, read-only client for the
Navigator's web backend (`ws://HOST:61220`), next to the Modbus stack rather
than instead of it. Not started; design to be raised with Dominik before code.

Why both. Modbus is the documented contract (812170) and carries the live
values at full precision, the volatile control registers (1712, 1713, 74) and
quantities the web pages do not (1790, 4122, pump signals). The websocket is the
only route to most settings — 244 parameter identifiers at Fachmann level
against the table's 93, 20 in common — and to the statistics, notifications
and the seven-day graph.

Constraints already settled:

- Read only: `overview`, `detail`, `traverse`. No `save`, no `execute`, no
  relay test, no raising the user level — the same fence `tools/webprobe.py`
  keeps.
- Settings join to the register table on the `parameter` column, the one place
  the two vocabularies meet.
- The protocol is undocumented (`jsonVersion` 11 in the captures); the types
  should make a response the parser does not recognize visible rather than
  silently empty.

Open for the design discussion: module name and place in the stack (e.g.
`IDM.Navigator.Web`), websocket dependency versus the hand-rolled client of
`webprobe.py`, how the PIN is passed, what the result depends on the user
level, and whether the project's name still fits.
