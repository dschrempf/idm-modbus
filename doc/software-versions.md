# Software versions

The controller's software as read, by date. Every measurement in
`verification/` is dated, so this log says which software it was made on. An
update is re-checked by what a read can check at rest: the scan, the widths,
the settings walk. A measurement of the machine's behavior, a run watched for
hours, is not repeated at each update; it stands with the software it was
made on.

## Where the versions are read

- The web page `N2_SERVICE_INFO`, setting 4838, at Fachmann level: every
  component below. A `webapi` capture holds it.
- The web page `N2_SYSTEM_INFO`, setting 4754, at Kunde level: the software
  version only.
- Since 20.24-2608, over Modbus: 522 major, 524 minor and 526 patch
  ([registers.md](registers.md#the-software-version)).

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
software version on 2026-09-19 in [2026-09-19](verification/2026-09-19.md).
The second was read in
`captures/navigator-10-webapi-20.24-2608-2026-11-05-1624.json`, and over Modbus in
`captures/navigator-10-widths-20.24-2608-2026-11-05-1639.json`.

## 2026-11-05: 20.24-1574 to 20.24-2608

The update kept the register map: a scan of the 682 addresses then in the
table read every one as before, answered or refused, with the same widths,
but for 1999, which refused and now reads `0000`. It split 4112 into single
registers, added 18 rows to the register page, two settings to the PV menu,
`SSYSPV030` and `SSYSPV031`, and renamed graph channels 112 and 365. The
Fachmann level stopped lasting a fixed sixty minutes
([2026-11-05-software-update](verification/2026-11-05-software-update.md)).
The table was rebuilt on 20.24-2608 the same day.

What the documents measured of a run on 20.24-1574 holds as far as a
heating run on 2026-11-09 re-checked it: 1074 follows M73, 1104 reads
`ffff` while the pump is driven, 4122 follows the inverter's motor power,
and the compressor starts 50 s after the request
([2026-11-09-heating-run-as-on-1574](verification/2026-11-09-heating-run-as-on-1574.md)).
Graph channels 112 and 365 read since a graph holding them was created by
hand ([2026-11-09-graphs-record-every-channel](verification/2026-11-09-graphs-record-every-channel.md)).
The heating floor ([2026-11-05-floor](verification/2026-11-05-floor.md)) and
the hot water charge
([2026-10-01-charge](verification/2026-10-01-charge.md)) stand as measured on
20.24-1574.
