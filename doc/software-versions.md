# Software versions

The controller's software as read, by date. Every `verification-*.md` is
dated, so this log says which software a measurement was made on. An update
is re-checked by what a read can check at rest: the scan, the widths, the
settings walk. A measurement of the machine's behavior, a run watched for
hours, is not repeated at each update; it stands with the software it was
made on.

## Where the versions are read

- The web page `N2_SERVICE_INFO`, setting 4838, at Fachmann level: every
  component below. A `webapi` capture holds it.
- The web page `N2_SYSTEM_INFO`, setting 4754, at Kunde level: the software
  version only.
- Since 20.24-2608, over Modbus: 522 major, 524 minor and 526 patch, each one
  register, read 24, 2608 and 0, and rows of the table. The page names 528
  `Software Version (Build Info)` and prints `g0c686ed`, but the register
  reads 0, as 4116 does for the whole version string; the table leaves both
  out. 4120, a `FLOAT` `firmware_version` by Xerolux/idm-heatpump-api,
  answers exception 02
  ([verification-2026-11-09-firmware-register.md](verification-2026-11-09-firmware-register.md)).

Every session of `idm-dump`, `idm-write`, `idm-web` and `tools/webprobe.py`
reads the version when it opens, over Modbus from 522 to 526 or over the web
from `N2_SYSTEM_INFO`, and every capture since 2026-11-05 records it. The
software the table describes is stated in `data/navigator-10-software.tsv`,
and a write goes ahead only on it.

## Log

| Component               | until 2026-11-05                        | since 2026-11-05                |
| ----------------------- | --------------------------------------- | ------------------------------- |
| Software Version        | `T_NAV10_20.24-1574-g183d9b17a`         | `T_NAV10_20.24-2608-g0c686ed41` |
| Version Branch          | `nav10/s_ALM50_release`                 | unchanged                       |
| BE Version              | `1.0-4002-gbf2c72fab`                   | `1.0-4103-g7d7c51074`           |
| ZE Version              | `n2.0_navconfig1099_s_ALM50_master_112` | unchanged                       |
| Bootloader Version      | `V0.58`                                 | unchanged                       |
| Kernel Version          | `kernel_NAV10_20.24-653-g5e65e42d2`     | unchanged                       |
| Display Type            | `MMI23`                                 | unchanged                       |
| uPC SW-Version          | `V3.5 \| Prot: 24`                      | unchanged                       |
| uPC OS-/Boot-Version    | `5.1.6` / `5.1.6`                       | unchanged                       |
| uPC BoardSize, CoreType | `medium`, `4`                           | unchanged                       |

No update went unseen between the readings of the version, on 2026-09-19,
09-24, 09-29, 10-01 and 11-05, provided every update restarts the controller
and the log keeps every restart: since 2026-09-19 `N2_LOG_HISTORY` shows two
restarts, on 2026-09-23 at 08:40 after a user shutdown, between two readings
of 1574, and on 2026-11-05 at 16:09.

The first column was read in `captures/navigator-10-webapi-20.24-1574-2026-09-24-1544.json`,
`…-20.24-1574-2026-09-29-1333.json` and `…-20.24-1574-2026-10-01-1158.json`, all alike, and the
software version on 2026-09-19 (`research.md`). The second was read in
`captures/navigator-10-webapi-20.24-2608-2026-11-05-1624.json`, and over Modbus in
`captures/navigator-10-widths-20.24-2608-2026-11-05-1639.json`.

## 2026-11-05: 20.24-1574 to 20.24-2608

### The update

The controller's log, `N2_LOG_HISTORY` in
`captures/navigator-10-webapi-20.24-2608-2026-11-05-1624.json`, shows the restart and
nothing of an update itself:

    2026-11-5 16:09:46    997  T20ERR_NEUSTART_1
    2026-11-5 16:11:49  20103  N2_ZEVERSIONNOTVALID
    2026-11-5 16:12:49  20999  N2_ERR_999 20103

The display said the version was invalid and offered an install from USB
for about a minute. The same `N2_ZEVERSIONNOTVALID` appeared once before, on
2026-08-20 at 08:47:13, after two `N2_ZENOTCONN`, without any change of
version. The log kept its history back to 2026-04-14, and the operating hours
counted on: `Regler Online` read 2202.0 h on 2026-10-01 at 11:58 and 3047.0 h
at 16:19, the 844 hours between the two. Who started the update is not
recorded.

### What changed

Read on 2026-11-05 between 16:17 and 16:39. The register scan,
`captures/navigator-10-scan-20.24-2608-2026-11-05-1617.json`, is compared with
`…-20.24-1574-2026-10-15-0847.json`. The settings walk, `…-webapi-20.24-2608-2026-11-05-1624.json`
completed by `…-1636.json`, is compared with `…-webapi-20.24-1574-2026-10-01-1158.json`.

- **The register table, as the scan reads it:** the same 682 addresses, the
  same widths, every status the same but one. 1999 `Störmeldungen quittieren`,
  write-only, answered exception 2 before and reads `0000` now.
- **4112 is no longer a `FLOAT`.** Before, 4113 refused a read on its own, so
  4112 was two registers wide (`…-widths-20.24-1574-2026-10-14-1208.json`). Now 4110 to 4114 each
  answer alone. `N2_GLTMON` lists 4112 without a name, at 0.00. It names 4113
  `Sperre Booster 1` and 4114 `Sperre Booster 2`, both RW and `false`, and
  4110 `Sperre` and 4111 without a name, both RW. 4112 reads 0.0 where it
  read -1.0. 4108 keeps its width and its -1.0, renamed
  `Leistungsbegrenzung  (kW)`.
- **`N2_GLTMON` lists 133 addresses, 115 before,** and none is gone. The new
  ones, besides 4110 to 4114: 500 `myiDM-ID`, a `FLOAT`; 506 `Wärmequelle`;
  508 `Wärmepumpentype`, 124 as the heat pump type setting; 520
  `Softwaretype (bitcodiert)`; 522 to 528, the software version; 1174
  `Verriegelung (Bitcodiert nach Stufen)`; and 1950 to 1958 `Alarm Code 1`
  to `5`, which read the notices the web backend reports, 20016 and 20005.
  All of them but 500 are one register wide.
- **The settings tree:** the same items, and two new ones in the PV menu.
  `SSYSPV030` `N2_PVOffGridHousePower` is in kW, 0 to 10, default 0, and
  reads 1.0. `SSYSPV031` `N2_PVStaticHousepwrActive` is No/Yes and reads No.
  The heat pump type list lost twelve `TERRA` variants and gained six. The
  type set, 124 `N2_ALM_2_8`, is in both.
- **Settings values:** 14 changed since 2026-10-01: the room temperature,
  room factor, maximum and minimum flow temperature and time program of
  circuits A, C and D, and the holiday mode. None of them is at its default,
  so none looks like a reset by the update.
- **Graph channels:** the same 59, but 112 and 365, both `T20x_QACT`
  before, are now `N2_THERMAL_PERFORMANCE_POLY` and
  `N2_THERMAL_PERFORMANCE_FLOWSENSOR`.
- **The legionella settings** `FW045` and `FW046` are not in the walks of
  2608, at Kunde level or at Fachmann. The update did not hide them: they
  went on 20.24-1574 already, between `…-webapi-20.24-1574-2026-09-24-1544.json`
  and `…-1574-2026-09-29-1333.json`, when `FW044`, the legionella function,
  went from `N2_HEATPUMP` to `N2_OFF` (`FW044` 3 and 0). Every walk since
  reads it Off and lacks both, so the controller shows them only while the
  function is on. `N2_PING` is in the overview of 4614 in every walk; only
  its `detail` is no longer asked, as the walk asks `detail` of
  `VALUE_ITEMS` alone (`tools/webprobe.py`).
- **The table** was rebuilt on 2608 from the scan
  `captures/navigator-10-scan-20.24-2608-2026-11-05-1912.json`, the widths
  of every address the page lists, `…-widths-20.24-2608-2026-11-05-1850.json`,
  and the walk `…-webapi-20.24-2608-2026-11-05-1859.json`. Every address
  the scan of 16:17 read answered as it did then, and every address new to
  the table answers: the 25 revision 12 added, and the 16 new page rows and
  4126 and 4128 the table takes from the page.
- **The Fachmann level** is still entered with the code spelled from the
  clock (`captures/navigator-10-level-20.24-2608-2026-11-05-1624.log`). It fell back to
  Kunde during the walk, between 16:34:02 and 16:34:04, ten minutes after it
  was entered. Entered again at 16:36:33
  and read every 30 s (`…-level-20.24-2608-2026-11-05-1636.log`), it held at 16:43:56
  and was Kunde at 16:44:27, after seven and a half to eight minutes. Two
  durations that differ by two minutes are no fixed timeout, and neither is
  the sixty minutes measured on 20.24-1574. Entered again for the walk that
  began at 18:59:41 and ended at 19:10:32, it was still Fachmann when left
  after it. What ends the level now is not
  known. On 2026-11-06 it held from the entry at 11:04:38 to 12:17:36 and
  was left by hand after, 73 minutes
  (`captures/navigator-10-level-20.24-2608-2026-11-06-1104.log`): a web
  watch asked a setting every 10 s to 11:48, a walk followed to 11:59, and
  `PV006` was changed at the display meanwhile.

### Re-checked on 20.24-2608

What the documents measured of a run on 20.24-1574 holds as far as a
heating run on 2026-11-09 re-checked it: 1074 follows M73, 1104 reads
`ffff` while the pump is driven, 4122 follows the inverter's motor power,
and the compressor starts 50 s after the request. The Fachmann level held
sixty minutes from the entry under a 10 s watch
([verification-2026-11-09-heating-run-as-on-1574.md](verification-2026-11-09-heating-run-as-on-1574.md)).
Graph channels 112 and 365 are in no graph the controller offers, and a
read cannot reach them. The floor of
[verification-2026-11-05-floor.md](verification-2026-11-05-floor.md) and a
hot water charge stand as measured on 20.24-1574.
