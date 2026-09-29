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

## Found 2026-09-29, from the controller's `main-LF3VJISP.js`

- **Fachmann login.** The page `idm-code-entry-expert` sends
  `{"controller":"frostprotection","command":"save","data":{"itemId":"2","value":CODE}}`,
  then `status`/`overview`. The `frostprotection` controller (route `/afw`)
  doubles as a service menu: item "1" is frost protection info, "2" the Fachmann
  code, "3" commissioning (`authentication`/`save` with `userlevel` 4). The
  settings root lists the same entry as `12503 N2_CODE_ENTRY_EXPERT`, type
  `action`. The code is day and month, `DDMM` (house document
  `manual/Wärmepumpe iDM AERO ALM 2-8 Fachmann-Code.png`).
- **No logout.** The JavaScript sends nothing that lowers the level. Unknown
  whether the level is per connection, shared with the display, or times out.
- **Live values without the graph.** Settings of type `info` are HTML tables
  of live readings, one row per sensor: designator, German label, value, unit.
  `4768 N2_SENSORS` (visible at level 0) carries B71 hot gas, B78/B86 pressures,
  B78v/B86v evaporation and condensation temperature, B87, and
  `B33/B113`, `B34/B114` Zwischenkreis flow and return — which Modbus reports
  unfitted at 1050/1052. `5888 N2_EVR_OVERVIEW` (Fachmann) adds superheat,
  subcooling and valve positions; `6245 N2_MODULATION_OVERVIEW` (Fachmann)
  the modulation.
- **The graph's last point is live**: 20–30 s old, after ~300 s steps.

## Decided and built 2026-09-29

Agreed with Dominik: separate executable `idm-web`; the PIN in `IDM_PIN`; leave
Fachmann by acknowledging its notice, as the Meldungen page does; keep the
project name for now, rename later.

- `IDM.Navigator.Web` (vocabulary, parsers, redaction), `.Connection`
  (hidden; sends any JSON), `.Session` (sends only a `Query`), `.Level`
  (the two writes). Dependencies `aeson`, `websockets`, `time`.
- Leaving: the page sends
  `{"controller":"notification","command":"save","data":{"code":"20005","remindMeLater":true}}`
  — `remindMeLater` is `quitType == 2`, and the notice (`N2_USERLEVELACTIVE`)
  has quitType 2. Never `quitAll`, which would acknowledge faults as well.
- `idm-web HOST --status | --show ID... | --watch SECONDS ID... |
  --enter-fachmann | --leave-fachmann`; `--watch` writes
  `captures/navigator-2.0-webwatch-*.jsonl`, a webapi entry per line plus
  `error`.
- Parsers checked against all 258 `settingDetail` of the 09-29 capture: none
  unrecognized; 16 of types not read (`ttw`, `text`, `graphheatcircuit`,
  `tt1`, `setdt`, `inputnumber`, `license`) come back as `SettingOther`.
- Tested against a fake server on localhost only.

Open:

- First run against the machine: `--status`, `--show 4768`, then enter and
  leave with Dominik watching the display. Unknown still: what the controller
  answers to either `save`, and whether the code wants zero padding before
  the 10th (`fachmannCode` pads, `0509`).
- Not yet in the Haskell client: the pages (`home`, `system`, statistics,
  weather) and a typed graph; `tools/webprobe.py` stays the capture tool until
  it does.

## Done 2026-09-29

First run against the machine, 15:45, at level 0: `--status` and `--show 4768`
read and parse. 4768 carries B33/B113 42.4 °C and B34/B114 34.6 °C, the
Zwischenkreis that Modbus reports unfitted at 1050/1052, and B86v 23.2 °C.
`--enter-fachmann` was refused (see
`../todo/2026-09-29-fachmann-code-refused-over-the-websocket.md`);
`--leave-fachmann` at level 0 found no notice and sent nothing, as it should.
The pages and the graph remain for `tools/webprobe.py`.
