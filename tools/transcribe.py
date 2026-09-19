#!/usr/bin/env python3
"""Transcribe the iDM parameter list into the tables under data/.

The manufacturer's manual is a PDF and is not redistributed here. Obtain it
(iDM document 812170 for Navigator 2.0; support sends it on request, and the
Loxone library mirrors revision 10), extract its text preserving the column
layout, and feed that in:

    pdftotext -layout 812170.pdf 812170.txt
    tools/transcribe.py 812170.txt data/navigator-2.0-scan-2026-09-19.json

Writing the tables is the only way they should ever change. Editing them by
hand makes the next revision of the manual impossible to apply cleanly.
"""

import csv
import json
import re
import sys
from pathlib import Path

ROW = re.compile(
    r"^\s*(?P<eeprom>\*?)(?P<addr>\d{1,4})\s+"
    r"(?P<dtype>FLOAT|UCHAR|WORD|CHAR|BOOL|INT|DWORD)\s+"
    r"(?P<access>RO|RW|W)\s+"
    r"(?P<tail>\S.*?)\s*$"
)
# the access right alone, for lines that continue a row
ROW_HEAD = re.compile(
    r"^\s*\*?\d{1,4}\s+(FLOAT|UCHAR|WORD|CHAR|BOOL|INT|DWORD)\s+(RO|RW|W)\s"
)
UNIT = re.compile(r"\[(?P<unit>[^\]]*)\]\s*$")
# enumerations are printed beside the row they belong to, as "4 ... Nur Warmwasser"
ENUM = re.compile(r"(?<![\d.])(?P<code>\d{1,3})\s*\.\.\.\s*(?P<label>\S.*?)\s*$")
FOOTNOTE = re.compile(r"\s*\d\)$")
NUMBER = re.compile(r"-?\d+(?:[.,]\d+)?")

HERE = Path(__file__).resolve().parent.parent


def parse_rows(text):
    """Every register the parameter list describes, in order of appearance."""
    out = {}
    for line in text.splitlines():
        m = ROW.match(line)
        if not m:
            continue
        addr = int(m.group("addr"))
        if addr in out:  # page headers repeat; the first occurrence wins
            continue
        tail = m.group("tail")
        unit = None
        u = UNIT.search(tail)
        if u:
            unit = u.group("unit")
            tail = tail[: u.start()].rstrip()
        cols = [c.strip() for c in re.split(r"\s{2,}", tail) if c.strip()]
        name = FOOTNOTE.sub("", cols[0]) if cols else ""
        rest = cols[1:]
        # trailing numeric columns are minimum, maximum and default, in that
        # order, preceded by the controller's own parameter identifier
        nums = []
        while rest and NUMBER.fullmatch(rest[-1]):
            nums.insert(0, rest.pop().replace(",", "."))
        lo = hi = default = ""
        if len(nums) == 3:
            lo, hi, default = nums
        elif len(nums) == 2:
            lo, hi = nums
        elif len(nums) == 1:
            default = nums[0]
        out[addr] = dict(
            address=addr,
            datatype=m.group("dtype"),
            access=m.group("access"),
            persistence="eeprom" if m.group("eeprom") else "volatile",
            name=name,
            parameter=rest[0] if rest else "",
            min=lo,
            max=hi,
            default=default,
            unit=unit or "",
        )
    return out


def parse_enums(text, known):
    """Enumerated values, attached to the most recent register."""
    out, current = {}, None
    for line in text.splitlines():
        if ROW_HEAD.match(line):
            current = int(re.match(r"\s*\*?(\d{1,4})", line).group(1))
        m = ENUM.search(line.rstrip())
        if not m or current is None or current not in known:
            continue
        label = m.group("label")
        # reject prose that merely happens to look like an enumeration
        if len(label) > 40 or any(t in label for t in ("...", ")", "werden", "siehe")):
            continue
        out.setdefault((current, int(m.group("code"))), label)
    return out


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    text = Path(sys.argv[1]).read_text(encoding="utf-8")
    scan = {}
    if len(sys.argv) == 3:
        scan = {r["address"]: r for r in json.loads(Path(sys.argv[2]).read_text())}

    registers = parse_rows(text)
    enums = parse_enums(text, registers)

    data = HERE / "data"
    with (data / "navigator-2.0-registers.tsv").open("w", newline="") as fh:
        w = csv.writer(fh, delimiter="\t", lineterminator="\n")
        w.writerow(
            "address datatype access persistence name parameter "
            "min max default unit observed".split()
        )
        for a in sorted(registers):
            r = registers[a]
            status = scan.get(a, {}).get("status")
            w.writerow(
                [
                    r["address"], r["datatype"], r["access"], r["persistence"],
                    r["name"], r["parameter"], r["min"], r["max"], r["default"],
                    r["unit"],
                    {"ok": "present", "exception": "absent"}.get(status, "untested"),
                ]
            )

    with (data / "navigator-2.0-enums.tsv").open("w", newline="") as fh:
        w = csv.writer(fh, delimiter="\t", lineterminator="\n")
        w.writerow(["address", "code", "label"])
        for (a, c), label in sorted(enums.items()):
            w.writerow([a, c, label])

    print(
        f"{len(registers)} registers, {len(enums)} enumerated values over "
        f"{len({a for a, _ in enums})} addresses",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
