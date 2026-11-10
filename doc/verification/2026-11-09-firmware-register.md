# 4120 answers exception 02: no firmware version there

2026-11-09, morning. One read of 4120, which Xerolux/idm-heatpump-api reads
as `firmware_version`, a `FLOAT` its model probe rounds to two places. Neither
812170 nor 812663 prints 4120, and the controller's register page
`N2_GLTMON` does not list it. On a Navigator 2.0, seaspotter/ioBroker.idm-modbus
saw exception 02 there; the library's own comment says some Navigator 10
builds reject it.

On 20.24-2608 4120 is not there. Read as one register and as two, by
function code 3 and by function code 4, it answers exception 02, illegal
data address, and so does 4121 on its own. The software stays readable at
522 to 526 ([software-versions.md](../software-versions.md)), and the table gets
no row for 4120.

## What was recorded

`idm-dump HOST --widths 4120` at 10:24, function code 3
(`captures/navigator-10-widths-20.24-2608-2026-11-09-1024.json`). The session
read the software as 24, 2608, 0.

| Address | Quantity | Answer       |
| ------- | -------- | ------------ |
| 4120    | 1        | exception 02 |
| 4120    | 2        | exception 02 |
| 4121    | 1        | exception 02 |

The library reads with function code 4 by default, and its model probe asks
for two registers. Function codes 3 and 4 return the same data on this
machine wherever both were tried ([2026-09-19-scan.md](2026-09-19-scan.md)),
but that covers only addresses that answer. So 4120 was read again by
function code 4, unit 1, by hand, a few minutes after the capture; no tool
here writes that read into a capture:

    request  412100000006 01 04 1018 0001   response  412100000003 01 84 02
    request  412200000006 01 04 1018 0002   response  412200000003 01 84 02

Both answer exception 02.

## What this leaves

The version over Modbus is 522, 524 and 526. 4116, which the page names
`Firmware Version IDM` and prints as the version string, reads no version
([2026-10-14-gltmon.md](2026-10-14-gltmon.md)),
and 528, the build, reads 0. Whether 4120 answers on a software other than
20.24-2608, and on which, is not known here.
