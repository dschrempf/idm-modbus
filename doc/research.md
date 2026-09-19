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

Supporting document 812184, "myiDM+energy – Navigator 2.0", covers the
photovoltaic side and is published openly by iDM. It is where addresses 74
(current PV surplus) and 4122 (current power draw) are described.

A copy of both PDFs is filed with the house documents rather than in this
repository; they are the manufacturer's, not ours to redistribute.

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
encoding of address 86 unresolved.

A recurring warning across loxforum and iobroker: querying too many parameters
at once makes the Navigator stall. One user staggers intervals at 55, 56 and
57 seconds to avoid collisions. This library therefore paces its requests by
default rather than treating that as tuning.

## What the manual does not say, and this project establishes

Reading all 497 documented addresses off a machine whose configuration is known
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

- **Revision drift.** Revision 10 documents software 20.21-101; this machine
  runs 20.24. No address in the manual is missing from the machine, so nothing
  was removed, but the manual cannot say what was *added*. Worth asking iDM
  support whether a later revision exists.
- **Enumerations are printed once per family.** The manual gives the operating
  mode codes beside heating circuit A (address 1393) and leaves B to G
  implicit, and likewise for zone modules. The transcription in `data/` records
  only what is literally printed; extending an encoding across a family is a
  judgement call and has not been made yet.
- **Address 86.** Unresolved in the Home Assistant thread, and not in the
  parameter list of revision 10 either.
- **`UCHAR` value 254.** Addresses 1714 and 1715 return 254, where every other
  unfitted `UCHAR` returns 255. Whether 254 is a second sentinel or a real
  value is not known; the library currently treats both as absence.

## Sources

- [812170 rev. 10, Modbus TCP Navigatorregelung 2.0](https://api.library.loxone.com/downloader/file/647/Modbus%20TCP_Navigator%202.0_DE.pdf)
- [812184, myiDM+energy Navigator 2.0](https://www.idm-energie.at/wp-content/uploads/2023/10/tu_de_812184_myiDMenergy-Navigator-2.0.pdf)
- [kodebach/hacs-idm-heatpump](https://github.com/kodebach/hacs-idm-heatpump)
- [Xerolux/idm-heatpump-api](https://github.com/Xerolux/idm-heatpump-api)
- [chincherpa/idm_control](https://github.com/chincherpa/idm_control/blob/master/modbus_tcp_navigator.md)
- [evcc discussion 11905](https://github.com/evcc-io/evcc/discussions/11905)
- [Home Assistant community: IDM heatpump integration via modbus](https://community.home-assistant.io/t/idm-heatpump-integration-via-modbus-pure-ha/701473)
