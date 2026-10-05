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

## 2026-09-29, later

Step 1: `--show 12503` answered
`{"description":"N2D_CODE_ENTRY_EXPERT","id":"12503","name":"N2_CODE_ENTRY_EXPERT","redirectId":"-1","type":"actioncode","value":""}`
— the detail is itself of type `actioncode`, with no items. The page for that
type (`idm-settings-actioncode`) sets `value` to `parseInt(code)` and saves
through the generic path, so the request is
`{"controller":"setting","command":"save","data":{"settingId":"12503","value":2909}}`.

Step 2 done: `enterFachmann` sends that, `fachmannCode` is now a number (509
for 5 September), and the documents no longer say entering fails. Tested
against the fake server only. Steps 3 and 4 remain.


## The code, corrected by Dominik

The Fachmann level wants the five-digit code of the house document's
Servicebereich, not day and month: last digit of the hour, first digit of the
hour, last digits of year, month and day. At 2026-09-29 15:5x it is 51699.
`fachmannCode` now spells that from the controller's clock, as a number
(`01294` goes as 1294, as `parseInt` would send it). Dominik also says the
day-and-month code keeps only the second digit of each, so the 5th of
September gives 59; that code is not sent anywhere. The code changes on the
hour, so a run in the last seconds of an hour may send a stale one.

## Done 2026-09-29

Run on the machine by Dominik, each command its own connection:

    --enter-fachmann
    {"settingSave":{"note":{"text":"action has been executed successfully!","type":"success"},"redirect":{"command":"overview","controller":"setting","data":{"settingId":"-1"},"reloadDelay":300}}}
    user level  Kunde (0) -> Fachmann (2)

    --leave-fachmann
    {"notificationSave":{"note":{"text":"cancellation has been executed successfully!","type":"success"}}}
    user level  Fachmann (2) -> Kunde (0)

Both writes work. The level outlived the entering connection, so it is the
controller's, not the session's, and Dominik saw the display switch to
Fachmann. Not observed: whether the level drops by itself after a while.
