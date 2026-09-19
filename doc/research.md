# Modbus TCP on an iDM Navigator 2.0: what is known, and from where

Written 2026-09-19. This is the background for the library: where the register
table comes from, what the existing community projects get right and wrong, and
which questions are still open.

## The machine

An iDM AERO ALM 2-8, an air-to-water monobloc with an indoor hydraulic module,
installed 2026. Controller: Navigator 2.0. Firmware reports itself as
`T_NAV10_20.24-1574-g183d9b17a`.

That string is a trap. `NAV10` reads like "Navigator 10", which iDM does sell
and which some projects treat as a separate protocol family. It is not what
this is. The Navigator 2.0 software line numbers itself `20.x` — the manual for
this controller documents `20.21-101` — and `20.24` is three minor versions
further along the same line. The question was settled by reading registers off
the machine rather than by reasoning about the string: see
[verification-2026-09-19.md](verification-2026-09-19.md).

## The authoritative source

**iDM document 812170, revision 10, "Modbus TCP – Navigatorregelung 2.0",
36 pages, dated 20 April 2022.**

iDM does not publish it on their own site. Forum users report that support
sends it on request. It is nevertheless downloadable, most reliably from the
Loxone library, which mirrors it for customers integrating iDM with Loxone:

    https://api.library.loxone.com/downloader/file/647/Modbus%20TCP_Navigator%202.0_DE.pdf

An older revision 0 circulates on loxforum. The corresponding manual for the
previous controller generation is 812049, "Navigator 1.0 und 1.7", and its
addresses are *different*; several community projects mix the two up.

The document gives, for each address: datatype, access right, the matching
parameter identifier in the controller's own menu (`FW030` and so on), minimum,
maximum, default, and unit. Enumerated values are printed as prose beside the
row. Chapter 4.2 defines the datatypes, 4.3 works through nine application
examples, and chapter 5 is a short FAQ.

Two facts from it that every integration needs and that are easy to miss:

- A 32-bit float occupies two consecutive registers **low word first**. This
  contradicts the usual Modbus habit and is the single most common bug in
  community configurations.
- Addresses marked with a star are written straight into the controller's
  EEPROM, which the manual rates at 300000 write cycles. An automation that
  adjusts a starred setpoint once a minute destroys it in about seven months.

## The supporting document

**iDM document 812184, revision 13, "myiDM+energy – Navigator 2.0", 52 pages,
dated 27 November 2024.** This one iDM publishes, and unlike 812170 it is easy
to find. It covers the photovoltaic and the Smart Grid side:

    https://www.idm-energie.at/wp-content/uploads/2021/04/tu_de_812184_myiDMenergy_PV_Variable-Stromtarife_Navigator-2.0-2.pdf

It adds no address. Its block — 74, 76, 78, 82, 84, 86 and 4122 — is the one
812170 prints, with the same datatypes and the same defaults, and in revision
13 it is a screenshot rather than text, so `pdftotext` drops it without saying
so. Five things in it are not in 812170:

- **A second switch gates the PV path.** 812170 asks only that "Modbus TCP" be
  "Ein" under "Gebäudeleittechnik". 812184 adds that the parameter PV008
  (`SYSPVSIGNAL`) must read "Gebäudeleittechnik/Smartfox", and that the
  controller needs a static address. `SYSPVSIGNAL` appears nowhere in the
  parameter list, so the switch cannot be thrown over Modbus. This is half an
  answer to the `RW/RO` question below: for this block a menu parameter does
  gate the feature, and neither document says what a write to 74 does while it
  is unset.
- **4122 is a model output, not a meter.** While the machine runs, it is
  computed from the compressor characteristic, the evaporation and condensation
  temperature, the speed and the fan power; at standstill it is a forecast from
  the outside temperature, the storage or return temperature, the minimum speed
  and the "TWW-Erwärmer-Maximaltemperatur". A series logged from it is not
  measured electrical power.
- **The PV menu is not on Modbus.** 812184 documents the settings PV001 to
  PV016, PV025, PVPRIO and PV-ROOMS; not one of those identifiers appears in
  the parameter column of 812170. Only the live values are addressable.
- **The same two values sit on two other buses**, as BACnet objects 74 (Analog
  Value) and 4122 (Analog Input) on UDP port 47808, and as EIB/KNX datapoints
  995 and 997. The Analog Value / Analog Input split mirrors the
  holding/input register split that turns out to be immaterial on the wire.
- **In a cascade, 74 is a surplus signal only.** Every PV signal but the
  digital input is available there, and of the regulation modes only the
  surplus one stays active.

Nothing on the Smart Grid side is addressable at all: tariff signals arrive on
two digital inputs (terminals 112/113 and 118/119) and hourly tariffs over
myiDM.

The PDFs live in `manual/`, which git ignores; they are the manufacturer's, not
ours to redistribute.

## Community work

None of it is wrong to consult, and none of it should be trusted over the
manual.

**kodebach/hacs-idm-heatpump.** Python, MIT, a Home Assistant custom component,
the longest-standing project aimed squarely at Navigator 2.0. Actively
maintained. Its register definitions live in one module inside the component;
there is no library to reuse. Its README is honest about the weak spot: for
pump speeds, valve positions and unavailability indicators, "the documentation
from IDM does not give any information for these sensors … this is a bit of a
guess."

**Xerolux/idm-heatpump-api** and **idm-heatpump-hass.** Python, MIT, started
March 2026. Better engineered — the library is separate from the integration,
it is typed, it has tests, and register definitions carry metadata including a
source reference. It aims much wider (Navigator 2.0, 10 and Pro) and says
plainly that its Navigator 2.0 coverage is incomplete and awaiting "broader raw
detection captures". Its register map is derived from the 2025 Navigator 10
specification plus reverse engineering, not from 812170.

**chincherpa/idm_control.** A markdown transcription of a parameter list — but
of 812049, the Navigator 1.0/1.7 manual. Useful as a reminder that the
generations differ; useless for this controller.

**evcc** discussions
([#11905](https://github.com/evcc-io/evcc/discussions/11905),
[#19002](https://github.com/evcc-io/evcc/issues/19002)) are the best source for
the PV surplus path in practice: address 74 to tell the pump the current
surplus in watts, 1710 to request heating, 4122 to read power draw.

The **Home Assistant community thread** "IDM heatpump integration via modbus
(pure HA)" documents the plain-YAML approach with the stock `modbus:`
integration. It confirms the word order problem (`swap: word`), recommends
scan intervals of 5 seconds for power and 30 for temperatures, and leaves the
encoding of address 86 unresolved. It is `Batteriefüllstand`, a `WORD` in
percent, and it is in the parameter list of revision 10 — under the access
right `RW/RO`, which chapter 4.1 does not define. A machine without a battery
answers the `WORD` sentinel rather than 0; see
[verification-2026-09-19.md](verification-2026-09-19.md).

A recurring warning across loxforum and iobroker: querying too many parameters
at once makes the Navigator stall. One user staggers intervals at 55, 56 and
57 seconds to avoid collisions. This library therefore paces its requests by
default rather than treating that as tuning.

## What the manual does not say, and this project establishes

Reading all 663 documented addresses off a machine whose configuration is known
answered three questions the documentation leaves open. The measurements are in
[verification-2026-09-19.md](verification-2026-09-19.md); the conclusions:

1. **Absence has a sentinel value, per datatype.** A sensor that is not fitted
   does not fail to answer — it answers with `-1.0` for a float, `255` for a
   `UCHAR`, `65535` for a `WORD`. Since no documented `UCHAR` has a maximum
   above 95 and no `WORD` above 100, these cannot collide with real readings.
   This is the "unavailable status indicator" kodebach could not pin down.

2. **A `WORD` carrying a temperature is two's complement.** The bivalence
   points read 65531 and 65516, which are the documented -5 and -20 degrees.
   The manual calls the type `WORD` and says nothing about sign. One
   consequence is an ambiguity the protocol cannot resolve: a bivalence point
   genuinely set to -1 degree is indistinguishable from the absence sentinel.

3. **Function codes 3 and 4 serve the same address space.** The manual and the
   community are inconsistent about which to use — 812184 calls 74 a holding
   register and 4122 an input register. In practice both codes return identical
   data for both. Holding registers are the better default because writing will
   need them.

A fourth finding matters for anyone auto-detecting a system's layout:
**configured heating circuits cannot be told apart from unconfigured ones by
their settings.** The parameters for circuits B and E to G, which do not exist
on this machine, hold plausible factory defaults (heating curve 1.2, heating
limit 15 degrees), not sentinels. Only the read-only sensor values and the
"active operating mode" registers 1498 to 1504 report absence honestly.

## Open questions

- **The `RW/RO` access right.** 166 of the 663 registers carry it — the
  energy management block at 74 to 86 and every zone module room value — and
  chapter 4.1 defines only `RO`, `RW` and `W`. Read as "the building
  management system may supply this, and may read it back", which is what the
  worked examples in chapter 4.3 do with them. Whether writing takes effect
  without the matching menu parameter set to "Ja" is untested; writing is not
  implemented. For the PV block there is at least a named gate — PV008, see
  above — and it is not itself addressable.
- **Revision drift.** Revision 10 documents software 20.21-101; this machine
  runs 20.24. No address in the manual is missing from the machine, so nothing
  was removed, but the manual cannot say what was *added*. Worth asking iDM
  support whether a later revision exists — revision numbers run per document,
  so 812184 reaching revision 13 says nothing about 812170, and the Loxone
  mirror still serves revision 10 byte for byte
  (md5 `5cff6722aee3655431b2d4166a6b3d5a`).

  Two later reprints constrain the drift for one block. 812184 rev. 13
  (November 2024) and the Navigator 10 excerpt (January 2026) both print
  addresses 74 to 86 and 4122 with unchanged datatypes and defaults — across
  two years and a controller generation. The same two revisions show that
  printed enumerations *do* drift: PV013 went from "Ja/Nein" to
  "Nein/Automatik/Immer", and PV008 gained four inverter manufacturers.
- **Enumerations are printed once per family.** The manual gives the operating
  mode codes beside heating circuit A (address 1393) and leaves B to G
  implicit, and likewise for zone modules. The transcription in `data/` records
  only what is literally printed; extending an encoding across a family is a
  judgement call and has not been made yet.
- **`UCHAR` value 254.** Addresses 1714 and 1715 return 254, where every other
  unfitted `UCHAR` returns 255. Whether 254 is a second sentinel or a real
  value is not known; the library currently treats both as absence.

## Sources

- [812170 rev. 10, Modbus TCP Navigatorregelung 2.0](https://api.library.loxone.com/downloader/file/647/Modbus%20TCP_Navigator%202.0_DE.pdf)
- [812184 rev. 13, myiDM+energy Navigator 2.0](https://www.idm-energie.at/wp-content/uploads/2021/04/tu_de_812184_myiDMenergy_PV_Variable-Stromtarife_Navigator-2.0-2.pdf)
  — the 26-page file under `uploads/2023/10/` is an excerpt of an earlier
  revision, printed pages 11 to 36
- [The same chapter for the Navigator 10, January 2026](https://www.idm-energie.at/wp-content/uploads/2026/01/Gebaeudeleittechnik-Smartfox.pdf)
  — three pages, filed under a name that hides what it is
- [kodebach/hacs-idm-heatpump](https://github.com/kodebach/hacs-idm-heatpump)
- [Xerolux/idm-heatpump-api](https://github.com/Xerolux/idm-heatpump-api)
- [chincherpa/idm_control](https://github.com/chincherpa/idm_control/blob/master/modbus_tcp_navigator.md)
- [evcc discussion 11905](https://github.com/evcc-io/evcc/discussions/11905)
- [Home Assistant community: IDM heatpump integration via modbus](https://community.home-assistant.io/t/idm-heatpump-integration-via-modbus-pure-ha/701473)

## Finding documents on the iDM site

idm-energie.at runs WordPress with the REST API open, so the document list can
be read out rather than guessed at. Filenames are not a reliable guide — the
Navigator 10 chapter above is called `Gebaeudeleittechnik-Smartfox.pdf` and
carries no document number, while the number-bearing files sit under an upload
folder (`2021/04/`) that has nothing to do with their date.

Every published PDF, newest first — 1364 of them at the time of writing:

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
behind the partner portal stays invisible. And 812170 is not in the library at
all: a search for `812` returns fifteen files, none of them it, and the obvious
guesses (`Modbus-TCP.pdf`, `tu_de_812170_*.pdf`, tried across several upload
folders) all 404. For that document the Loxone mirror remains the only source.
