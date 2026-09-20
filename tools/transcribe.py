#!/usr/bin/env python3
"""Transcribe the iDM parameter list into the tables under data/.

The manufacturer's manual is a PDF and is not redistributed here. Obtain it
(iDM document 812170 for Navigator 2.0; support sends it on request, and the
Loxone library mirrors revision 10), put it in manual/, which git ignores,
extract its text preserving the column layout, and feed that in:

    pdftotext -layout manual/812170.pdf manual/812170.txt
    tools/transcribe.py manual/812170.txt data/navigator-2.0-scan-2026-09-19.json

The column layout is what carries the meaning: the list is not consistent about
the order of its cells, so a cell is read according to where it is printed.

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
    r"(?P<access>RW/RO|RO|RW|W)\s+"
    r"(?P<tail>\S.*?)\s*$"
)
# the access right alone, for lines that continue a row
ROW_HEAD = re.compile(
    r"^\s*\*?\d{1,4}\s+(FLOAT|UCHAR|WORD|CHAR|BOOL|INT|DWORD)\s+(RW/RO|RO|RW|W)\s"
)
# every page of the parameter list repeats the column headings
PAGE_HEAD = re.compile(r"Adresse.*Bezeichnung")
HEADINGS = ("Bezeichnung", "Parameter", "Min.", "Max.", "Default-", "Ein-")
FIELDS = ("name", "parameter", "min", "max", "default", "unit")
# a run of text with no two spaces in it: one cell of the printed table
CELL = re.compile(r"\S+(?: \S+)*")
UNIT = re.compile(r"^[\[(]?(?P<unit>.*?)[\])}]?$")
# enumerations are printed beside the row they belong to, as "4 ... Nur Warmwasser"
ENUM = re.compile(r"(?<![\d.])(?P<code>\d{1,3})\s*\.\.\.\s*(?P<label>\S.*?)\s*$")
# a footnote marker, printed alone in a cell or attached to the end of a name
FOOTNOTE_CELL = re.compile(r"^[*\d]\)$")
FOOTNOTE = re.compile(r"\s*\d\)$")
NUMBER = re.compile(r"-?\d+(?:[.,]\d+)?")
# how far a cell may sit from its heading and still belong to that column
SLACK = 4

HERE = Path(__file__).resolve().parent.parent


def columns(head):
    """Where each column starts, read off a page heading."""
    return dict(zip(FIELDS, (head.find(h) for h in HEADINGS)))


def cells(line, start=0):
    """The printed cells of a line, each with the column it starts in."""
    return [(m.group(), m.start()) for m in CELL.finditer(line) if m.start() >= start]


def field_of(cols, at):
    """The column a cell belongs to: the nearest heading."""
    return min(cols, key=lambda f: abs(cols[f] - at))


def is_number(cell):
    return bool(NUMBER.fullmatch(cell))


def strip_footnote(name):
    """Drop a trailing footnote marker.

    A footnote marker and the tail of a sensor designator are printed alike, so
    "Wärmemenge Heizen2)" and "Außentemperatur (B32)" end the same way. The
    marker is the one whose parenthesis closes nothing.
    """
    m = FOOTNOTE.search(name)
    if not m:
        return name
    head = name[: m.start()]
    return head if head.count("(") == head.count(")") else name


def join_name(name, more):
    """Append a line that continues a name, undoing the manual's hyphenation."""
    if name.endswith("-") and more[:1].islower():
        return name[:-1] + more
    if name.endswith("/"):
        return name + more
    return f"{name} {more}" if name else more


def parse_rows(text):
    """Every register the parameter list describes, in order of appearance.

    Which column a cell belongs to is decided by where it is printed rather
    than by the order the cells appear in, because the list is not consistent
    about that order: the cascade block prints the controller's parameter
    identifier after the maximum, where every other page prints it first.
    """
    out = {}
    lines = text.splitlines()
    cols = None
    for i, line in enumerate(lines):
        if PAGE_HEAD.search(line):
            cols = columns(line)
            continue
        m = ROW.match(line)
        if not m or cols is None:
            continue
        addr = int(m.group("addr"))
        if addr in out:  # page headers repeat; the first occurrence wins
            continue
        row = {f: [] for f in FIELDS}
        for cell, at in cells(line, m.start("tail")):
            if not FOOTNOTE_CELL.match(cell):
                row[field_of(cols, at)].append(cell)
        for cell, at in continuation(lines, i, cols):
            if field_of(cols, at) == "unit":
                row["unit"].append(cell)
            else:
                row["name"] = [join_name(one(row["name"]), cell)]
        # a cell printed under a numeric heading but holding no number is the
        # parameter identifier, wherever the list chose to put it
        for f in ("min", "max", "default"):
            row[f], strays = partition(is_number, row[f])
            row["parameter"] += strays
        out[addr] = dict(
            address=addr,
            datatype=m.group("dtype"),
            access=m.group("access"),
            persistence="eeprom" if m.group("eeprom") else "volatile",
            name=strip_footnote(one(row["name"])),
            parameter=one(row["parameter"]),
            min=one(row["min"]).replace(",", "."),
            max=one(row["max"]).replace(",", "."),
            default=one(row["default"]).replace(",", "."),
            unit=UNIT.match(one(row["unit"])).group("unit"),
        )
    return out


def continuation(lines, i, cols):
    """The cells of the lines that continue the row on line i.

    A name too long for its column, and occasionally its unit, run on into the
    next line. Prose and enumerations are set off by a blank line, which is
    what separates them from a continuation here.
    """
    out = []
    for line in lines[i + 1 :]:
        if not line.strip() or ROW.match(line) or PAGE_HEAD.search(line):
            break
        taken = [
            (cell, at)
            for cell, at in cells(line)
            if not FOOTNOTE_CELL.match(cell)
            and (abs(at - cols["name"]) <= SLACK or field_of(cols, at) == "unit")
        ]
        if not taken:  # the footnote legend at the foot of the page
            break
        out += taken
    return out


def partition(p, xs):
    return [x for x in xs if p(x)], [x for x in xs if not p(x)]


def one(found):
    return found[0] if found else ""


# the letter or number that tells one member of a family from the next
FAMILY_TAIL = re.compile(r" (?:[A-G]|[1-9])$")


def family(r):
    """What a register shares with the others the manual lists it beside.

    Heating circuits A to G, and compressors 1 to 4, get an address each, but
    the enumeration of their values is printed once, beside the first of them.
    Members are alike in everything but the letter or number ending the name.
    """
    stem = FAMILY_TAIL.sub("", r["name"])
    if stem == r["name"]:
        return None
    return (stem, r["datatype"], r["access"], r["min"], r["max"], r["unit"])


def share_within_families(enums, registers):
    """Give every member of a family the enumeration printed beside one of them.

    Sharing is refused where more than one member carries a printed
    enumeration: they are then not saying the same thing, and which one holds
    is a question for the manual rather than for this script.
    """
    families = {}
    for a, r in registers.items():
        f = family(r)
        if f:
            families.setdefault(f, []).append(a)
    out = dict(enums)
    for group in families.values():
        printed = sorted({a for a, _ in enums if a in group})
        if len(printed) != 1:
            continue
        source = printed[0]
        for a in group:
            for (b, c), label in enums.items():
                if b == source:
                    out.setdefault((a, c), label)
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
    enums = share_within_families(parse_enums(text, registers), registers)

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
