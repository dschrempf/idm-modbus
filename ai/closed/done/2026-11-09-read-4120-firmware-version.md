# Read 4120, a firmware version by Xerolux's account

Xerolux/idm-heatpump-api reads 4120 as `firmware_version`, a `FLOAT` its
model probe rounds to two places (`idm_heatpump/registers.py` and
`client.py`, in `community/`). Its own comment says some Navigator 10
builds reject the register. Neither 812170 nor 812663 prints 4120, the
controller's register page `N2_GLTMON` does not list it, and on a Navigator
2.0 seaspotter/ioBroker.idm-modbus saw exception 02. It has never been read
here.

## Steps

1. `idm-dump HOST --widths 4120` into a widths capture: whether it answers,
   and at what width.
2. If it answers: its raw words, decoded as a low-word-first `FLOAT`,
   against the software the session reads, 20.24-2608. A float cannot
   hold `20.24-2608` whole; note which part it carries, if any.
3. A dated `doc/` for the finding either way, and `doc/research.md` and
   `doc/software-versions.md` updated. A row in the table goes through
   `tools/transcribe.py` like every row the manual lacks, so it needs a
   source the script reads; if 4120 is worth a row, settle that source
   first, in `decide-how-a-measured-fact-enters-the-table`.

## 2026-11-09: exception 02, by function code 3 and 4

On 20.24-2608 4120 is not there. Function code 3, as one register and as
two, and 4121 alone, answer exception 02
(`captures/navigator-10-widths-20.24-2608-2026-11-09-1024.json`); function
code 4, which the library uses, as one register and as two, by hand, too.
`doc/verification-2026-11-09-firmware-register.md` records it, and
`doc/research.md` and `doc/software-versions.md` cite it. No value, so no
row for the table, and nothing for
`decide-how-a-measured-fact-enters-the-table`.
