# Operating mode 3 and -1 at 1005 unlabeled

## The question

1005, `Betriebsart System` (`SYSMODE`, `UCHAR`, `RW`, EEPROM), has the codes
0 `Standby`, 1 `Automatik`, 2 `Abwesend`, 4 `Nur Warmwasser` and 5 `Nur
Heizung/Kühlung` in the manual, within a range of 0 to 5. There is no 3.
The web backend's `homeDetail` offers `systemMode` options -1, 0, 1, 2, 3, 5
and 4, in that order, as bare numbers without labels
(`captures/navigator-2.0-webapi-20.24-1574-2026-10-01-1158.json`). What do 3 and -1
mean? Until that's known, `enumLabel` has no label for a 3 and the table
can't say whether -1 is a value 1005 can hold.

## Answered on 2026-10-15

The web app's own script labels -1 `RD_OFF`, "Aus" (no frost protection),
and 3 `RD_HOLIDAY`, "Urlaub"; its 0, 1, 2, 4 and 5 carry the manual's labels
(`doc/verification-2026-10-15-web-app.md`). What stays open:

- how the two labels enter the table: session 4 of
  `2026-10-15-run-the-open-todos-in-six-sessions`;
- `decode` reads "Aus" as no value. Switched at the display on 2026-10-15,
  1005 read `ffff` in "Aus" and `0003` in "Urlaub"
  (`captures/navigator-2.0-watch-20.24-1574-2026-10-15-1418.jsonl`). -1 is therefore a
  value 1005 holds, not its sentinel, and the fix belongs with the labels in
  session 4.

The rest of this note is how it was approached.

## How we might solve it

All of these read; none sets the mode.

1. **The web interface's own JavaScript.** It turns the `systemMode` values
   into words, so its code or translation table names 3 and -1. The
   controller serves the single-page application's files to any browser, and
   fetching them is a read. The label might also show which user level
   offers the choice.
2. **The display.** The mode chooser on the controller's display lists the
   modes by name. If it lists them in the web's order, -1, 0, 1, 2, 3, 5, 4,
   the names map onto the numbers. Order alone is weak evidence, though, and
   only a sanity check for 1.
3. **812184 or a later revision of 812170.** Neither prints the list:
   revision 12 still labels 0, 1, 2, 4 and 5 only. Asking iDM support for a
   revision covering 20.24-2608 is
   `ask-idm-support-for-812170-covering-20-24-2608`.

Setting 1005 to 3 and reading the display would also answer it. But 1005 is
an EEPROM register, it is not a target, and a mode with no known
meaning is a poor thing to switch the machine into.

A label found this way comes from a source other than the manual, so it
raises a second question: how `tools/transcribe.py` adds an enum code the
manual does not print. That is session 4 of
`run-the-open-todos-in-six-sessions`.
