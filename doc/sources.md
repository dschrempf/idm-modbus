# Sources

Where the register table and the claims of the other documents come from:
the manufacturer's documents, the controller's own register list, and the
community projects, with what each is worth. What the machine answered is in
[modbus.md](modbus.md), [registers.md](registers.md) and the documents beside
them.

## The machine

An iDM AERO ALM 2-8, an air-to-water monobloc with an indoor hydraulic module,
installed 2026, with a Navigator 10 controller; its configuration is in
[heat-pump.md](heat-pump.md), its software in
[software-versions.md](software-versions.md).

`NAV10` in the software string names the controller, and the web interface
calls itself NAV 10 too. iDM's 2025 product catalog lists the AERO ALM 2-8
with Navigator 10 control; the installation manual 812199 rev. 1.1 of June
2020 names the Navigator 2.0 for the same model, which changed controllers
under one name. The web backend is the websocket on port 61220, which
AndyNew2/hacs-idm-hpweb uses for the Navigator 10, not the HTTP endpoints it
uses for the Navigator 2.0 ([Community work](#community-work)).

The software numbers itself `20.x`, as 812170 does for the Navigator 2.0
(`20.21-101`, `20.23-515`), and the registers answer as 812170 says: the
Navigator 10 continues the Navigator 2.0's software line and serves its
register map. Neither fact tells the generations apart; the name, the
catalog and the websocket do.

## The authoritative source

**iDM document 812663, revision 0, "Modbus TCP Navigator 10", 36 pages,
dated 18 June 2025 and written for software `NAV10_20.23-903` and
`T_NAV10_20.23-1336`.** Xerolux/idm-heatpump-api ships it as
`docs/New/Modbus_TCP_NAVIGATOR_10.pdf` (md5
`2f209d0fb0b48c586454fb08755cb47e`). The table has been transcribed from it
since 2026-11-09.

For each address it gives the datatype, the access right, the matching
parameter identifier of the controller's menu (`FW030` and so on), minimum,
maximum, default and unit. Enumerated values are printed as prose beside the
row. Chapter 4.2 defines the datatypes, 4.3 works through nine application
examples, and chapter 5 is a short FAQ.

The Navigator 2.0 has a Modbus manual of its own, **812170, "Modbus TCP –
Navigatorregelung 2.0", whose revision 12, 40 pages, has its parameter list
dated 18 June 2025 and written for software 20.23-515.** 812663's parameter
list is revision 12's row for row: address, datatype, access, EEPROM star,
name, range, default and unit. Two differences: the zone modules lose rooms 7
to 9, and a footnote changes. For a machine with a separating heat exchanger,
revision 12 sends a reader of 1050 and 1052 to 1068, and 812663 sends both
to 1070; each is right for one of the two, 1070 being the flow B125 and 1068
the return B124. The application examples, the PV chapter 4.3.10 and the GLT
monitor 4.4 are word for word the same, but for "NAVIGATOR Pro" becoming
"iDM Einzelraumregelung". Moving the table to 812663 took out the 110 rows of
rooms 7 to 9, absent on this machine as every zone module row is, and
nothing else.

The table was transcribed from 812170 revision 12 from 2026-11-05 to
2026-11-09, and before that from revision 10, 36 pages, dated 20 April 2022,
for software 20.21-101, which the Loxone library mirrored
([Links](#links)).

Revision 12 is attached to a LoxWiki comment of 2026-10-09 as
`Montageanleitung_Modbus_TCP_Navigator_2_0.2025.pdf` (md5
`21ac38ed0982d565f96550c249d6a3fa`), on the page "IDM-IPump mit
Loxone-Modbus-TCP (Navigator 2.0)". Older revisions circulate on loxforum,
LoxWiki and photovoltaikforum. iDM publishes neither manual on its own site;
forum users report that support sends 812170 on request.

The manual for the generation before, 812049, "Navigator 1.0 und 1.7", has
_different_ addresses; several community projects mix the two up.

### Revision drift

812663 documents 20.23; this machine ran 20.24-1574 and since 2026-11-05 runs
20.24-2608. Revision 12 of 812170 against revision 10 adds the Smart Grid
status at 90, the groundwater temperatures at 1086 and 1088, faults at 1680
to 1683, two boosters at 4001 to 4052, and eight addresses the controller's
own list shows ([below](#the-controllers-own-list)). It drops 4126 and 4128,
moves `Smart Grid Status` from 1006 to 90, and reuses 1006 for the
`Variabler Eingang`. It narrows the bivalence points from -90 to -40, moves
the -1 of the pump signals from the minimum into the default, and drops the
cascade block's parameter identifiers.

No revision says what 20.24 added; the controller's list names addresses
that neither revision 12 nor 812663 prints
([below](#the-controllers-own-list)). A revision of
812663 or 812170 for 20.24 is worth asking iDM support for. Revision numbers
run per document, so 812184 reaching revision 13 says nothing about 812170.

The PV block is stable across two later reprints: 812184 rev. 13 of November
2024 and the Navigator 10 sheet of January 2026 print 74 to 86 and 4122 with
unchanged datatypes and defaults. Printed enumerations do drift: `PV013` went
from "Ja/Nein" to "Nein/Automatik/Immer", and `PV008` gained four inverter
manufacturers.

## The supporting documents

**iDM document 812184, revision 13, "myiDM+energy – Navigator 2.0", 52 pages,
dated 27 November 2024**, published and easy to find ([Links](#links)).

It covers the photovoltaic and the Smart Grid side and adds no address: its
block, 74, 76, 78, 82, 84, 86 and 4122, is 812170's, with the same datatypes
and defaults. In revision 13 the block is a screenshot, so `pdftotext` drops
it without saying so. What it adds:

- **A second switch gates the PV path.** Besides "Modbus TCP" "Ein" under
  "Gebäudeleittechnik", `PV008` (`SYSPVSIGNAL`) must read
  "Gebäudeleittechnik/Smartfox", and the controller needs a static address.
  `SYSPVSIGNAL` is not in the parameter list, so the switch cannot be thrown
  over Modbus.
- **4122 is a model output**, computed while the machine runs from the
  compressor characteristic, the evaporation and condensation temperature,
  the speed and the fan power, and at standstill a forecast. On this machine
  it is the inverter's figure instead ([registers.md](registers.md#4122)).
- **The PV start and stop rules**, which [pv-control.md](pv-control.md)
  holds against the measurements.
- **The PV menu is not on Modbus.** It documents `PV001` to `PV016`,
  `PV025`, `PVPRIO` and `PV-ROOMS`; none of those identifiers is in the
  parameter column. Only the live values are addressable.
- **The same two values sit on two other buses**, as BACnet objects 74
  (Analog Value) and 4122 (Analog Input) on UDP port 47808, and as EIB/KNX
  datapoints 995 and 997.
- **In a cascade, 74 is a surplus signal only.**

Nothing on the Smart Grid side is addressable: tariff signals arrive on two
digital inputs (terminals 112/113 and 118/119) and hourly tariffs over myiDM.

**The Navigator 10 sheet**, three scanned pages of January 2026, filed as
`Gebaeudeleittechnik-Smartfox.pdf`
(`manual/navigator-10-pv-glt-2026-01.pdf`): the block 74 to 86 and 4122 for
the GLT path, and the Smartfox's own settings for an iDM pump.

**812199 rev. 1.1**, the AERO ALM installation manual: the limits of heating on
p. 11, and the safety heat exchanger's loss of up to 5 K on p. 37
([heat-pump.md](heat-pump.md#hot-water)).

The PDFs live in `manual/`, which git ignores; they are the manufacturer's,
not ours to redistribute.

## The controller's own list

At Fachmann level the web backend serves an info page, 12763 `N2_GLTMON`,
that lists the addresses the controller serves over Modbus, each with a name
and unit, `RO` or `RW`, its current value and a `GLT Value`, the last value a
building management system wrote (812170 §4.4). On 20.24-1574 it listed 115
addresses, on 20.24-2608 133; 36 of them are not in 812663. Among them: the
minimum and maximum flow temperature per circuit at 1520 to 1540, the heat
sink's return, flow, flow rate and pump signal at 1068 to 1074, the total
electrical energy at 1746, power limits and cascade powers from 4108 to 4140,
and the software version at 522 to 526
([2026-10-14-gltmon](verification/2026-10-14-gltmon.md)).

The page states no datatype, persistence, range or identifier. The table
takes its rows with the width measured by `idm-dump --widths` and the rest
left unstated, and marks them `gltmon`: 30 rows. A row the page prints
without a name (68, 70, 72, 80, 4111, 4112) or with text for a value (528, 4116) stays out. Where the manual prints an address too, its row stands,
unless the measured width contradicts its datatype: 1072, a `UCHAR` in the
manual, reads two registers and fractional litres per minute, so the page's
row stays; 4112, the manual's `FLOAT` `Leistungsbegrenzung Kaskade`, answers
one register at a time on 20.24-2608, so its row goes. Identifiers for the
flow temperature limits were joined by moving the settings, in
`data/navigator-10-gltmon-parameters.tsv`
([2026-10-15-flow-temperature](verification/2026-10-15-flow-temperature.md)).

## The controller's web app

The controller serves its web interface's files to any browser. Its
JavaScript names the websocket protocol and decodes the request reason; its
translations, `assets/translations/de.json` and `en.json`, label the codes
and hold a help text behind each setting's `N2D_` key
(`captures/navigator-10-webui-20.24-2608-2026-11-05-1641/`). They settled
1005's codes ([2026-10-15-web-app](verification/2026-10-15-web-app.md)) and
are the source for the PV control's vocabulary in
[pv-control.md](pv-control.md#sources).

## Community work

None of it is wrong to consult, and none of it should be trusted over the
manual.

**kodebach/hacs-idm-heatpump.** Python, MIT, a Home Assistant custom component,
the longest-standing project aimed squarely at Navigator 2.0, read here at
8c008ba (2026-10-12). Actively maintained; since v0.15.0-beta.1 it reaches
the pump through Home Assistant's shared Modbus library. Its register
definitions live in one module inside the component; there is no library to
reuse. Its README flags its guesses: it makes "some guesses" for pump speeds,
and for valve positions and the unavailable value "this is a bit of a
guess." Of 4108 to 4128 it reads 4122 alone; the others, and 88, 1713, 1714
and 1715, are names marked TODO. It still reads 1006 as the Smart Grid
status, revision 10's layout. It reads with function code 4 in blocks of up
to 32 registers, and writes with function code 16, reading nothing back and
taking no account of the EEPROM. Its reports that bear on this machine:

- set-max-power-for-14a-enwg
  ([kodebach/hacs-idm-heatpump#173](https://github.com/kodebach/hacs-idm-heatpump/issues/173)):
  writing 4108 had no effect, and iDM support answered it is "for internal
  use and not supposed to be used by heatpump users". The report gives no
  setup; here 4108 caps or ends a PV run
  ([pv-control.md](pv-control.md#the-power-limit-at-4108)).
- sometimes-very-wrong-values-for-aktuelle-leistungsaufnahme
  ([kodebach/hacs-idm-heatpump#61](https://github.com/kodebach/hacs-idm-heatpump/issues/61)):
  4122 reads 20 to 32 kW for one poll and then returns, on the maintainer's
  machine too. Not seen here: the 4384 reads of 4122 in the watches of
  2026-10-01 to 2026-11-08, each a request of function code 3 for its two
  registers alone, all stay below 8 kW.
- add-sensor-values-for-pv-zielwert
  ([kodebach/hacs-idm-heatpump#297](https://github.com/kodebach/hacs-idm-heatpump/issues/297)),
  on a Navigator 2.0: writing 88 had no visible effect, and 90 reads the
  Smart Grid status, yellow normally, red under the utility's lock, green
  with a PV surplus.
- analogausgaenge-erweiterung-pumpen
  ([kodebach/hacs-idm-heatpump#269](https://github.com/kodebach/hacs-idm-heatpump/issues/269)):
  a request at 1712 ends after exactly one hour.
- interval-for-data-refresh-to-low
  ([kodebach/hacs-idm-heatpump#16](https://github.com/kodebach/hacs-idm-heatpump/issues/16))
  and why-is-the-min-refresh-interval-this-high
  ([kodebach/hacs-idm-heatpump#118](https://github.com/kodebach/hacs-idm-heatpump/discussions/118)):
  an iDM service partner advised 60 s or more between polls; a user polled
  every 26 s without trouble, failed below 22 s, and the controller and its
  display recovered only once the client disconnected.

**AndyNew2/hacs-idm-hpweb.** Python, MIT, a Home Assistant custom component
started December 2025, read here at c9362c5 (v0.3.6, 2026-10-23), reading
the web backend instead of Modbus. For the Navigator 2.0 it logs in on
`/index.php` with the PIN, takes a CSRF token from the page, and reads
`/data/heatpump.php`, `/data/settings.php`, `/data/info.php` and
`/data/statistics.php`; for the Navigator 10 it uses the websocket on port
61220 that `idm-web` reaches here, asking `setting` `detail` of 4768, 4775,
4782, 4789 and 4754 and `statistic` `detail`, each answer taken for the next
frame. Navigator 10 owners failed to set it up over HTTP
(unbekannter-fehler-during-setup,
[AndyNew2/hacs-idm-hpweb#8](https://github.com/AndyNew2/hacs-idm-hpweb/issues/8)),
and whether 20.24-2608 serves the HTTP endpoints is untested here. What its
README says Modbus lacks — the hot gas temperature, the evaporation and
condensation pressures — is what [web-backend.md](web-backend.md) lists as
shown by the web interface alone; the flow rate it lists is at 1072. On the
Navigator 2.0 alone it also writes: the operating mode by a POST to
`/data/info.php`; `FW027`, `FW028`, `FW048`, `FW044` to `FW046` and the clock
by a PUT to `/data/settings.php`; and a hot water charge by a PUT to
`/data/heatpump.php`. Its discussions report:

- navigator-10-german-discussion
  ([AndyNew2/hacs-idm-hpweb#5](https://github.com/AndyNew2/hacs-idm-hpweb/discussions/5)):
  a Navigator 10 on `NAVIO_20.23-940-gf62a31e12`, beside Navigator 2.0s on
  20.23, so the number alone does not tell the generations apart.
- sensorwerte-fachmannebene
  ([AndyNew2/hacs-idm-hpweb#10](https://github.com/AndyNew2/hacs-idm-hpweb/discussions/10)):
  a user entered "Fachmannebene 2" with a code spelled from the
  controller's clock, on a Navigator Pro 2.0 on 20.23-245, as
  `IDM.Navigator.Web.Level` does here. On a Navigator 2.0, 1710 cleared
  itself after exactly one hour, and the target at 1696 governed only above
  the heating circuits' own targets or once their "Heizkreis kann
  Anforderung stellen" was off.

**Xerolux/idm-heatpump-api** and **idm-heatpump-hass.** Python, MIT, started
March 2026. Better engineered — the library is separate from the integration,
it is typed, it has tests, and register definitions carry metadata including a
source reference. It aims much wider (Navigator 2.0, 10 and Pro) and says
plainly that its Navigator 2.0 coverage is incomplete and awaiting "broader raw
detection captures". Its register map is derived from 812663, which it
ships, plus measurements on other machines.

The library, read here at 0347f25 (v2.16.1, 2026-11-08), agrees with the
table on every address and datatype but these:

- 1004, the message number, as a 16-bit word, since codes up to 999 do not
  fit a byte; the table's `UCHAR` arrives as a whole register too.
- 1034 with a maximum of 67 rather than 53, from a user's report
  (register-dhw-charge-off-temp-invalid-value,
  [Xerolux/idm-heatpump-hass#460](https://github.com/Xerolux/idm-heatpump-hass/issues/460)).
- A `UCHAR` is its low byte, so `ffff` reads 255 and the `fffe` of 1714 and
  1715 reads 254, which it declares a sentinel there alone; the controller
  prints -2.
- 4112 as a writable `FLOAT`, as 812663 prints it.
- 4120 as `firmware_version`, a `FLOAT` its model probe reads; it is in
  neither manual, and here it answers exception 02
  ([registers.md](registers.md#the-software-version)).

Floats are low word first, and a `WORD` with a negative range is signed, so
-1 at 1074 and 1104 to 1109 stays a value, as here. Over Modbus it writes
without reading back; its only EEPROM guard is one write a minute per
register. Over the websocket it decodes the request reason from the
`home` `detail`: every widget with an `operationMode`, 1 heating and 4 hot
water, and while a request stands an `info` bitmask, whose table matches the
one [web-backend.md](web-backend.md#the-request-reason) took from the web
interface's JavaScript. Its test of a PV request uses a frame made by hand.
It writes `home/save`, `notification/save`, `system.freshwater/save`,
`system.heatingcircuit/save` and the clock by `setting/save`, each confirmed
by its success note and never retried; it implements no change of user
level. None of its tests reads a capture from a machine.

The integration holds no register map of its own; it pins the library. What
it adds for this project is its wiki, `docs/wiki/`, read here at 3520c5a
(2026-11-09). On a Navigator 10 it reads the cascade register 1147 as
`ffff`, as here, but takes the low byte, 255, and counts 254 among the
sentinels, which here is `fffe`, read by the controller as -2. It lists the web
backend's writes, taken from the controller's JavaScript and confirmed for
some by a capture: `home/save` with `systemMode`, numbered as 1005,
`system.freshwater/save` with a parameter identifier, `setting/save` and
`setting/execute`, and `notification/save`, each answering a
`<controller>Save` frame with a `note`. It decoded the error-code database of
iDM's Windows service tool: codes 20 to 999 are the controller's messages,
and the library packages them. And it says the technician level of the
websocket does not take a code spelled from the clock, which
`IDM.Navigator.Web.Level` does on this Navigator 10: it tried another
request, `authentication/save`, and on 12503 read the notice 20005
`N2_USERLEVELACTIVE` ("Fachmanncode aktiv") as a failure.

**seaspotter/ioBroker.idm-modbus.** TypeScript, MIT, an ioBroker adapter
started October 2026, read here at 58eb44a (2026-10-29). It keeps a map per
generation, from 812170 rev. 10, 812663 rev. 0 and 812049 rev. 1, and marks
each row it saw answer; the machine it saw is a Navigator 2.0, on which 88,
90, 4120 and 1068 answer exception 02, and nothing has been tried on a
Navigator 10. It keeps 1072 a `UCHAR`, noting Xerolux's float as a doubt. It
reads a `UCHAR` unsigned and -1 in a `WORD` as no value, so it loses both
the -2 of 1714 and 1715 and the "not being driven" of 1074. Its PV module
writes 74 to 86 every 30 s, clamps a surplus it computes at 0, and writes 0
when its source goes stale; what it says the controller does with them is
unmeasured.

**PV feeders.** Four small projects pass a surplus to an iDM; none measures
how the controller reacts.

- ThomasRammDev/idm_proxy (a028afd, 2026-04-27) emulates an SMA Data
  Manager M. Set to SMA, a Navigator 2.0 polls, by its author's account,
  only 30775 (PV production), 31249 (power at the grid connection point)
  and 30845 (battery charge), at unit 2, every 60 s. On that path the
  controller reads a meter, its own draw netted in, and forms the surplus
  itself. The emulation contradicts itself on the sign of 31249.
- uwemock/Sungrow_iHomeManager_to_iDM_Heatpump (a1f9b92, 2026-05-29), a
  Node-RED flow for "Gebäudeleittechnik / Smartfox": 74 is a Sungrow
  meter's grid power, negated and unclamped, written on a change only and
  left as it was when the meter does not answer; it also writes 78, 82, 84
  and 86.
- ReneMronet/ha-idm-heatpump (4f7b1f4, 2026-05-05), for a Navigator 10:
  reads 74 and writes 88, from 0 to 50 kW, and 4108, from 0 to 100 kW with
  a default of 100 against the -1 the machine reads here, when a user
  changes them. Its README cites 812663.
- Rudi-Regentonne/CrustyPump (b31a1f3, 2026-10-23), Rust, scrapes the
  Navigator 2.0's PHP interface: `/data/channellive.php`,
  `/data/channels.php` and `/data/settings.php`.

**chincherpa/idm_control.** A markdown transcription of a parameter list — but
of 812049, the Navigator 1.0/1.7 manual. Useful as a reminder that the
generations differ; useless for this controller.

**evcc** discussions, idm-waermepumpe-einbinden
([evcc-io/evcc#11905](https://github.com/evcc-io/evcc/discussions/11905)) and
idm-waermepumpen
([evcc-io/evcc#19002](https://github.com/evcc-io/evcc/issues/19002)), are the
best source for the PV surplus path in practice: address 74 to tell the pump
the current surplus in kW (scale 0.001 from evcc's watts), 1710 to request
heating, 4122 to read power draw. Its template,
`templates/definition/charger/idm.yaml` at 25a8e25 (2026-10-20), writes 74
with function code 16 as a low-word-first float and reads 4122; it writes
neither 88 nor 4108. A further discussion,
[evcc-io/evcc#24699](https://github.com/evcc-io/evcc/discussions/24699), an
AERO ALM on Navigator 2.0, reports that the controller kept acting overnight
on the last value written to 74, and that a store charge needed about 3.3 kW
to start on another machine.

The **Home Assistant community thread** "IDM heatpump integration via modbus
(pure HA)" documents the plain-YAML approach with the stock `modbus:`
integration. It confirms the word order problem (`swap: word`), recommends
scan intervals of 5 seconds for power and 30 for temperatures, and leaves the
encoding of address 86 unresolved; it is `Batteriefüllstand`
([registers.md](registers.md#the-energy-management-block-74-to-88)). On
another model, it reports a PV start once 74 exceeds the expected draw by
about 500 W, at least 10 minutes of runtime, no restart within 10 minutes,
speed rising with the surplus, and 74 to include the pump's own draw.

A recurring warning across loxforum and iobroker: querying too many parameters
at once makes the Navigator stall. One user staggers intervals at 55, 56 and
57 seconds to avoid collisions.

## Finding documents on the iDM site

idm-energie.at runs WordPress with the REST API open, so the document list can
be read out rather than guessed at. Filenames are not a reliable guide — the
Navigator 10 sheet is called `Gebaeudeleittechnik-Smartfox.pdf` and carries
no document number, while the number-bearing files sit under an upload
folder (`2021/04/`) that has nothing to do with their date.

Every published PDF, newest first — 1364 of them on 2026-11-07:

    for p in $(seq 1 14); do
      curl -s "https://www.idm-energie.at/wp-json/wp/v2/media?mime_type=application/pdf&per_page=100&page=$p&_fields=date,source_url" \
        | jq -r '.[]|[.date[0:10],.source_url]|@tsv'
    done

`&search=<term>` narrows it; the search runs over title and slug, so `812`
finds the numbered technical documents, `schnittstelle` the per-manufacturer
interface sheets, and `gebaeudeleittechnik` the Navigator 10 one. The `date`
field is the upload date, which is how a newer revision is spotted: several
revisions of one document sit side by side, distinguished only by a `-1`, `-2`
suffix.

Two things this does not reach. The Download Monitor endpoint
(`/wp-json/download-monitor/v1/downloads`) answers 403, so anything gated
behind the partner portal stays invisible; its post type,
`/wp-json/wp/v2/dlm_download`, answers, and lists only brochures and
newsletters. And 812170 is not in the library at all, nor 812570, its English
edition. iDM publishes its `tu_` documents there; 812170 is a `ma_` one, an
installation manual.

Guessing does not find it either. On 2026-11-07 every one of these answered
404: in each upload folder from `2021/04` to `2026/11`,
`ma_de_812170_Modbus-TCP_Navigator-2.0.pdf` — what WordPress makes of the
title the PDF carries — and seven variants of it (`ma-de-…-2-0`, `tu_de_…`,
`…_Buch`, `…_Navigatorregelung-2.0`, `Modbus-TCP_Navigator-2.0_DE`); the same
with `-1` to `-3` in `2021/04`; and four `ma_en_812570_…` and `tu_en_…`
variants in `2021/04` and from `2025/01`. Paths are case-sensitive, so another
capitalization stays untried.

Nor is anything newer than revision 12 elsewhere, as of 2026-11-07. The
LoxWiki page holds revision 12 only. A copy on Scribd named
`ma-de-812170-Modbus-TCP-Navigator-2-0` has 36 pages, as revision 10 has. The
Loxone template "iDM Heating & Cooling" (1470) ships revision 7 of 812170
(software 20.15-0), revision 10 of 812570 (from 20.21-101), and Loxone Modbus
templates whose 661 addresses all appear in revision 12. The Loxone mirror of
revision 10 did not resolve on 2026-11-05. What remains is iDM support.

## Links

- 812170 rev. 12, Modbus TCP Navigatorregelung 2.0, attached on the LoxWiki
  page "IDM-IPump mit Loxone-Modbus-TCP (Navigator 2.0)"
- [812170 rev. 10, Modbus TCP Navigatorregelung 2.0](https://api.library.loxone.com/downloader/file/647/Modbus%20TCP_Navigator%202.0_DE.pdf)
- [812663 rev. 0, Modbus TCP Navigator 10](https://github.com/Xerolux/idm-heatpump-api/blob/main/docs/New/Modbus_TCP_NAVIGATOR_10.pdf),
  shipped by Xerolux/idm-heatpump-api
- [812184 rev. 13, myiDM+energy Navigator 2.0](https://www.idm-energie.at/wp-content/uploads/2021/04/tu_de_812184_myiDMenergy_PV_Variable-Stromtarife_Navigator-2.0-2.pdf)
  — the 26-page file under `uploads/2023/10/` is an excerpt of an earlier
  revision, printed pages 11 to 36
- [The same chapter for the Navigator 10, January 2026](https://www.idm-energie.at/wp-content/uploads/2026/01/Gebaeudeleittechnik-Smartfox.pdf)
- [kodebach/hacs-idm-heatpump](https://github.com/kodebach/hacs-idm-heatpump)
- [AndyNew2/hacs-idm-hpweb](https://github.com/AndyNew2/hacs-idm-hpweb)
- [Xerolux/idm-heatpump-api](https://github.com/Xerolux/idm-heatpump-api)
- [Xerolux/idm-heatpump-hass](https://github.com/Xerolux/idm-heatpump-hass)
- [seaspotter/ioBroker.idm-modbus](https://github.com/seaspotter/ioBroker.idm-modbus)
- [ThomasRammDev/idm_proxy](https://github.com/ThomasRammDev/idm_proxy)
- [uwemock/Sungrow_iHomeManager_to_iDM_Heatpump](https://github.com/uwemock/Sungrow_iHomeManager_to_iDM_Heatpump)
- [ReneMronet/ha-idm-heatpump](https://github.com/ReneMronet/ha-idm-heatpump)
- [Rudi-Regentonne/CrustyPump](https://github.com/Rudi-Regentonne/CrustyPump)
- [evcc's iDM template](https://github.com/evcc-io/evcc/blob/master/templates/definition/charger/idm.yaml)
- [chincherpa/idm_control](https://github.com/chincherpa/idm_control/blob/master/modbus_tcp_navigator.md)
- [idm-waermepumpe-einbinden (evcc-io/evcc#11905)](https://github.com/evcc-io/evcc/discussions/11905)
- [Home Assistant community: IDM heatpump integration via modbus](https://community.home-assistant.io/t/idm-heatpump-integration-via-modbus-pure-ha/701473)
