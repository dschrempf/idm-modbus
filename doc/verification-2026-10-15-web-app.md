# What the controller's web app says about three open questions

2026-10-15. The controller serves the files of its web interface, a
single-page application, to any browser, and its labels live there: the
script turns the numbers the websocket sends into words, and two translation
files hold the words. Read against the captures already made, they settle
what 1005's codes 3 and -1 mean, and switching the mode shows 1005 answering
them over Modbus. They leave open what the -2 of 1714 and 1715 means, but the
captures show the wire sends a `UCHAR` as a whole signed word, and the
decoding now reads it that way. For 4108 and 4112 they show no setting to
join.

## What was recorded

|               |                                                                                                                                  |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| The web app   | `captures/navigator-10-webui-20.24-1574-2026-10-15-1407/`: `index.html`, `main-LF3VJISP.js`, `assets/translations/{de,en}.json` |
| The settings  | `captures/navigator-10-webapi-20.24-1574-2026-10-01-1158.json`, Fachmann, with 12763 `N2_GLTMON`                                |
| The registers | the ten scans from `captures/navigator-10-scan-20.24-1574-2026-09-19-1503.json` to `-20.24-1574-2026-10-15-0847.json`           |
| The modes     | `captures/navigator-10-watch-20.24-1574-2026-10-15-1418.jsonl`, 1005, 1090 and 4122 every 5 s                                   |

The files were fetched with plain HTTP `GET`s, and nothing was sent over the
websocket. The script's `Last-Modified` is 2026-08-20. One setting was
changed, at the display, while Modbus was read: the operating mode, below.

## 1005: -1 is "Aus", 3 is "Urlaub"

The web backend offers `systemMode` the options -1, 0, 1, 2, 3, 5 and 4, as
bare numbers (`homeDetail`, in every webapi capture that holds it). The script
labels them in one `switch`:

| Code | Key                                           | `de.json`                   | The manual's label  |
| ---- | --------------------------------------------- | --------------------------- | ------------------- |
| -1   | `RD_OFF`                                      | Aus                         |                     |
| 0    | `RD_STANDBY`                                  | Standby                     | Standby             |
| 1    | `RD_AUTOMATIC`                                | Automatik                   | Automatik           |
| 2    | `RD_ABSENT`                                   | Abwesend                    | Abwesend            |
| 3    | `RD_HOLIDAY`                                  | Urlaub                      |                     |
| 4    | `RD_ONLY_HOT_WATER`                           | Nur Warmwasser              | Nur Warmwasser      |
| 5    | `RD_ONLY_HEATING` / `RD_ONLY_HEATING_COOLING` | Nur Heizung / Heizen/Kühlen | Nur Heizung/Kühlung |

The text for 5 depends on whether cooling is configured. The longer texts say
what the two new codes do. -1: "Gerät schaltet sofort Aus - kein Frostschutz
aktiv", against 0's "Gerät auf Standby - Frostschutz aktiv"; the chooser
asks first, "Betriebsmodus wirklich auf Aus stellen?". 3: "Bei Einstellung
„Urlaub" läuft das System für Heizen und Kühlen im Eco-Betrieb. Die
Warmwasserladung kann Ein-/Ausgeschalten werden."; the chooser opens a dialog
that sends a number of days and whether hot water stays on along with the 3.

That the web's code is 1005's rests on two things. The five codes the manual
prints carry the manual's labels. And in the walk of 2026-10-01 11:58, the
register page `N2_GLTMON` printed 1005 as 4 while `homeDetail` sent
`systemMode` 4; the scan of 2026-09-29 13:24 read 1005 as 4, the walk nine
minutes later `systemMode` 4. No other code has been seen on both sides.

Over Modbus the two codes arrive as the script has them. With the machine at
rest, the operating mode was set at the controller from "Automatik" to "Aus",
then "Urlaub" for one day with hot water on, then back, while 1005 was read
every 5 s:

| From     | 1005 reads | Mode      |
| -------- | ---------- | --------- |
| 14:18:52 | `0001`     | Automatik |
| 14:19:47 | `ffff`     | Aus       |
| 14:20:57 | `0003`     | Urlaub    |
| 14:21:52 | `0001`     | Automatik |

Three rounds, 14:18:57 to 14:19:09, got no answer, all before the first
change. 1090 read 0 and 4122 read 0.0 throughout.

So "Aus" is `ffff` on the wire, the same word an unfitted sensor answers. The
decoding below reads it as no value: a consumer of `decode` takes a machine
switched off for a register that holds nothing.

## 1714 and 1715: a whole signed word, and -2 still unexplained

The manual has these two as `UCHAR`, and every other `UCHAR` that answers a
sentinel reads 255 where 1714 and 1715 read 254
([verification-2026-09-19.md](verification-2026-09-19.md)). The 255 and 254
were the decoding's: it kept only the low byte. On the wire, in all ten scans,
84 `UCHAR` registers answer: 67 with a high byte of `00`, 15 with `ffff` and
1714 and 1715 with `fffe`. None answers `00ff` or `00fe`.

The controller reads those words as signed. `N2_GLTMON` printed 1714
(`externe Anforderung Sole-/Zwischenkreispumpe`) and 1715 (`externe
Anforderung Grundwasserpumpe`) as -2, and 86, a `WORD` answering `ffff`, as -1.

So `asWritten` now reads a `UCHAR` as a 16-bit two's complement word, and
`decode` takes any negative one for no value, -1 and -2 alike, as it took 255
and 254. Scans written before record 255 and 254 as the `value`; their `raw`
is unchanged.

What -2 means is not in the web app. It names the two registers,
`N2_ERBP` and `N2_ERGP`, and nothing in the script or the translations
mentions -2. The settings tree holds neither pump, at Fachmann level either:
this machine draws its heat from the air and has neither. "No external
request" and "no such pump" remain the two readings, and this machine cannot
tell them apart.

## 4108 and 4112: no setting to join

`N2_GLTMON` names 4108 `Leistungsbegrenzung Wärmepumpe` and 4112
`Leistungsbegrenzung Kaskade`, with no unit. Every scan since 2026-10-14 reads
both as -1.0, at rest and while heating.

The translations hold keys with those names, `N2_POWER_LIMIT_HEATPUMP` and
`N2_POWER_LIMIT_CASCADE`, but no webapi capture holds a setting by either
name, so no parameter identifier joins them, and no persistence follows.

What the tree holds is the menu 10424 `N2_SMART_GRID`, with `EV003`
`N2_EVU_SPERRMODUS`: what the machine does when the grid operator's contact
opens, 0 `N2_EVU_SPERRE` or 1 `N2_Leistungsbegrenzung`, here 0. The
translation of the second describes a parameter for the power drawn while the
contact is open, in kW, by default 4.2, which § 14a always allows. That
parameter is not in the capture; the menu numbers its items 1, 2, 3 and 10.
Whether it is 4108 nothing says, and 4108 reading -1.0, not 4.2, speaks
against it being that parameter's stored value.

The page has a fifth column, `GLT Value`, empty but for 4108, 4112 and the
cascade powers 4132, 4136 and 4140, where it reads -1. All five are `RW`;
the column may hold what a building management system last wrote, and -1
nothing, but nothing states it.

## Reproducing

The `curl` loop in `captures/README.md`; then, in the script, the `switch`
that begins `case-1:return{icon:"icon-beladestatus-aus"`, and in `de.json`
the keys above.

The modes: with the machine at rest,

    cabal run idm-dump -- HOST --watch 5 1005 1090 4122 > watch.jsonl

while the mode is switched at the display. "Aus" stops frost protection for
as long as it is set.
