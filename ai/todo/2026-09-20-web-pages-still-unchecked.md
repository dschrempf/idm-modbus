# Register blocks the web interface has not yet been read against

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
setting to 42, 43 and 44 on circuits A, C and D changed no register at all.
Worth confirming on the display next session that the change did take, since
the conclusion rests on it. The circuits can then go back to 45.
