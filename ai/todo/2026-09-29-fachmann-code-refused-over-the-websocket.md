# Fachmann code refused over the websocket

Handoff, 2026-09-29. `idm-web HOST --enter-fachmann` sends
`{"controller":"frostprotection","command":"save","data":{"itemId":"2","value":"2909"}}`,
what the `idm-code-entry-expert` page of the web interface sends. The
controller, at level 0, 15:46, answered

    {"frostprotection":{"note":{"text":"wizard is not available!","type":"danger"}}}

and stayed at level 0. That page is reached through `/afw`, the frost
protection wizard, which evidently accepts nothing while no wizard is running.
The code itself was not judged.

## Next candidate: the settings route

Item `12503 N2_CODE_ENTRY_EXPERT`, type `action`, at the root of the settings
tree. In `main-LF3VJISP.js`:

- The settings detail page asks `setting`/`detail` of every item it opens,
  actions included (a read; the action happens on save).
- Saving an `action` whose items include one of type `actioncode` sends
  `saveSetting(id, {code: value})`, i.e.
  `{"controller":"setting","command":"save","data":{"settingId":"12503","value":{"code":2909}}}`;
  the page stores the code with `parseInt`, so a number, and the leading zero
  of a day before the 10th would be lost — which suggests the controller
  compares numbers.
- `send()` lets `settingId == 12503` through even in demo mode, which singles
  it out as the login path.

Steps:

1. `idm-web HOST --show 12503` — a read; `--show` now prints the whole detail
   of a type it does not parse. Confirm the item of type `actioncode` and
   any other items and `required` conditions.
2. Switch `enterFachmann` to that request, as a number; update the haddock of
   `IDM.Navigator.Web.Level`, `CLAUDE.md`, `Readme.md`, `Changelog.md`, which
   now say entering does not work.
3. Run with Dominik at the display; then `--leave-fachmann` at level 2, which
   has not run yet (it sends `notification`/`save`, code `20005`,
   `remindMeLater` true, as the Meldungen page does).
4. If the level drops by itself after a while, note after how long.

Leaving via the display ("quittieren" on Meldungen) is known to work, so a
failed step 3 can always be undone by hand.
