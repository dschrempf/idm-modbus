# Search the web for 812663 newer than rev. 0

812663 rev. 0, the Navigator 10's Modbus manual, documents software
20.23-903 and 20.23-1336; the machine runs 20.24-2608, and the controller's
own register page lists 36 addresses no manual prints (`doc/research.md`,
"Revision drift"). Rev. 0 turned up in Xerolux/idm-heatpump-api, not on
iDM's site, so a later revision may sit somewhere similar.

## Where to look

- The document number and its titles: "812663", "Modbus TCP Navigator 10",
  "MODBUS TCP NAVIGATOR 10", "Montageanleitung Modbus TCP Navigator 10",
  with and without "Rev.1" and "20.24".
- iDM's uploads, under `www.idm-energie.at/wp-content/uploads/YYYY/MM/`, as
  `doc/research.md`, "Finding documents on the iDM site", describes; the
  Navigator 10's GLT chapter was found that way.
- The community projects in `community/` and their issues, LoxWiki and
  loxforum, photovoltaikforum, the ioBroker and Home Assistant forums,
  where 812170 rev. 12 surfaced.
- The Loxone library, which mirrored 812170 rev. 10.

## Done when

A revision newer than 0 is in `manual/` and in the house archive, and
`doc/research.md` names it; or the search, with its date and the places
tried, is recorded here and the mail of
`ask-idm-support-for-812170-covering-20-24-2608` remains the way.

## 2026-11-09: nothing newer than rev. 0

No revision of 812663 newer than 0 is public; the mail of
`ask-idm-support-for-812170-covering-20-24-2608` remains the way. Tried:

- iDM's media library through the REST API: `search=` for `812663`,
  `navigator-10`, `navigator`, `modbus`, `812`, `gebaeudeleittechnik`,
  `montageanleitung`, and every PDF uploaded since 2025-06-01. No Modbus
  document; the newest relevant one is still `Gebaeudeleittechnik-Smartfox.pdf`
  of 2026-01-12.
- 96 guessed paths, all 404: `ma_de_812663_Modbus-TCP_Navigator-10.pdf`, the
  same with `NAVIGATOR-10`, `Modbus_TCP_NAVIGATOR_10.pdf`,
  `Modbus-TCP_Navigator-10.pdf` and `Modbus-TCP-Navigator-10.pdf` in every
  upload folder from `2025/06` to `2026/11`; the first and third with no
  suffix, `-1` and `-2` in `2021/04`.
- The clones in `community/`, fetched: upstream brings CI bumps only.
  Xerolux/idm-heatpump-api's `docs/New/Modbus_TCP_NAVIGATOR_10.pdf` is still
  rev. 0, md5 as in `manual/`, unchanged since 2026-05-31.
  seaspotter/ioBroker.idm-modbus lists rev. 0 in `docs/sources/README.md` and
  keeps the PDF out of its public tree.
- GitHub code search for `812663` and `Modbus_TCP_NAVIGATOR`: only
  ReneMronet/ha-idm-heatpump's README, which cites rev. 0, and the two
  projects above. LM1LC3N7/gladys-idm cites rev. 0 and ships no PDF. Issues
  and PRs of Xerolux's two projects, seaspotter, kodebach and ReneMronet, for
  `812663`, `Rev.1`, `Modbus_TCP_NAVIGATOR`, "neuere Version", "newer
  revision": none concerns a newer revision.
- verbrauchersteuerung-idm-navigator-10 (openWB/core#4104): no document.
- LoxWiki, "IDM-IPump mit Loxone-Modbus-TCP (Navigator 2.0)", through the
  Confluence API: attachments of 2023-12-30 only; the last comment is the
  rev. 12 of 812170 of 2026-10-09.
- The Loxone library answers 403 to a fetch; not pursued further.
- ioBroker forum, through its API: `812663` finds nothing; `navigator 10`
  finds the topic "Test Adapter idm-modbus" (85616), with no document
  attached.
- Home Assistant community, "IDM heatpump integration via modbus (pure HA)":
  812170 and 812184 only; its search answers 403.
- photovoltaikforum: no Navigator 10 thread; its attachment 113433 is 812170
  rev. 7, dated 10 March 2020. loxforum's file 124252 needs a login.
- Web searches for "812663", "812663_Rev", "Modbus TCP Navigator 10",
  "NAV10_20.24" and an English edition.

In passing: other Navigator 10s run `NAV10_20.24-653`, `NAV10_20.24-1124`
and `T_NAV10_20.24-1580` (Xerolux/idm-heatpump-hass releases, the ioBroker
topic, openWB/core#4104).
