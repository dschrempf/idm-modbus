# Register blocks the web interface has not yet been read against

**Closed 2026-09-20.** Not by screenshots. The web interface keeps its values
in a websocket on port 61220, which answers read commands directly, so all of
this was settled by capture instead — `tools/webprobe.py`, and
`doc/verification-2026-09-20-webapi.md` for the result. 1005, 1378–1384 and
1002 are confirmed; 1120 and 1121 are confirmed and settle the sign of a
`WORD`; 1032, 1006, 1091–1093, 1122–1124 and 1048 have no page and never will
have one on this machine; 1457–1497 cannot be checked at all, because cooling
is not configured. 1748–1762 disagree with the controller's own totals and are
now their own item, `2026-09-20-waermemenge-registers-disagree-with-the-page`.

The list below is what was open before that, left as it stood.

The verification of 2026-09-20 covered Fühlereingänge, the four service
input/output pages, Heizkreis A/C/D, Warmwasser, Modulation, Expansionsventil
and System Informationen. These registers answer but no page has been compared
against them yet.

| Registers | What would settle them | Value on 2026-09-20 20:08 |
|---|---|---|
| 1032 | the Warmwasser page, scrolled to its top | 46 |
| 1005, 1006 | the system operating mode, and Smart Grid | 4, and 1006 unread |
| 1091, 1092, 1093, 1099 | wherever the demands and the fault summary are shown | 0, 0, 0, 0 |
| 1120–1124 | the 2./3. Wärmeerzeuger page | -5, -20, -5, -20, 0 |
| 1378–1390 | the target flow temperature per circuit | 0.0 — note: zero, not the -1.0 sentinel, on circuits that are idle |
| 1457–1497 | the cooling half of each Heizkreis page | untested |
| 1748–1762 | the Wärmemenge totals, not the daily chart | internally consistent only |
| 1002, 1048 | — | 20.42, and -1.0 |

The daily Wärmemenge chart cannot check 1754: its window starts after the
machine did.

Settled on 2026-09-20: 1449 is not the maximum flow temperature. Moving that
setting to 42, 43 and 44 on circuits A, C and D changed no register at all. The
circuits are back at 45. Worth confirming on the display next session that the
change did take while it was made, since the conclusion rests on it — if the
display never showed 42, the experiment proves nothing and has to be redone.
