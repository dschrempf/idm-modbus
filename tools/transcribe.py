#!/usr/bin/env python3
"""Transcribe the iDM parameter list into the tables under data/.

The manufacturer's manual is a PDF and is not redistributed here. Obtain it
(iDM document 812663 revision 0, "Modbus TCP Navigator 10"; support sends
it on request, and doc/research.md says where else it is), put it in manual/,
which git ignores, and feed it in:

    tools/transcribe.py manual/812663-rev0.pdf [--scan SCAN]
        [--webapi WEBAPI --widths WIDTHS]

The script reads the PDF with pdftotext, which the development shell
provides: its text with the column layout preserved, and the height of each
word, which is what tells a remark from a name.

The observed column says whether the reference machine answered for an
address. It comes from the scan, captures/navigator-10-scan-SOFTWARE-DATE.json, when
one is given, and is otherwise carried over from the table being replaced: the
captures are not in the repository.

The controller lists the addresses it serves on a page of its own web
interface, N2_GLTMON, and lists some the manual does not. Given a webapi
capture holding that page and a widths capture of those addresses, the table
gains them, marked as coming from that page rather than from the manual.
Without the two, they are carried over like the observed column. Where the
manual prints an address too, its row stands, unless the width measured
contradicts its datatype; then the manual's row goes, the page's row takes
its place if the page names it, and the script says so. A manual row two
registers wide whose second register is a row of the page goes too, so the
carried-over rows drop it again.

The page names no parameter identifier, and the settings tree, which does,
names no address. Which identifier a row of the page carries was settled by
moving a setting and watching which register followed, and is written by hand
in data/navigator-10-gltmon-parameters.tsv, which this script reads and never
writes. Given a webapi capture, each identifier is checked against it: the
tree must hold it, at the value the page printed for its address.

The table describes one software of the controller, the one its captures
were read on, and data/navigator-10-software.tsv states it by hand; this
script reads that file and never writes it. A capture read on another
software is refused: a scan or a widths capture by the major, minor and patch
it records, a webapi capture by the series, major and minor of the version it
records, or, in a capture from before captures recorded it, of the version its
N2_SYSTEM_INFO page prints. A capture that names no software is taken
unchecked, with a note.

Of the writable registers, those listed in data/navigator-10-targets.tsv,
which this script reads and never writes, are the ones a write may go to. The
file gives each an English name, and the script writes them as the type
src/IDM/Navigator/Target.hs, with what a write to each costs taken from the
table.

The column layout is what carries the meaning: the list is not consistent about
the order of its cells, so a cell is read according to where it is printed.

Writing the tables and the module is the only way they should ever change. Editing them by
hand makes the next revision of the manual impossible to apply cleanly.
"""

import argparse
import csv
import html
import json
import re
import subprocess
import sys
from pathlib import Path

from webprobe import REDACTED

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
ENUM = re.compile(r"(?<![\d.-])(?P<code>-?\d{1,3})\s*\.\.\.\s*(?P<label>\S.*?)\s*$")
# a footnote marker, printed alone in a cell or attached to the end of a name
FOOTNOTE_CELL = re.compile(r"^[*\d]\)$")
FOOTNOTE = re.compile(r"\s*\d\)$")
NUMBER = re.compile(r"-?\d+(?:[.,]\d+)?")
# how far a cell may sit from its heading and still belong to that column
SLACK = 4
# how much smaller, in points, a remark is set than the name it follows; the
# two revisions set names at 8.3 and 9.7 points and remarks at 7.3
FONT_SLACK = 0.5

HERE = Path(__file__).resolve().parent.parent

# the part of an A4 page, in points from its left edge, that the list is
# printed in: 812663 prints a thumb index, 9 to 13, at the edge of every page,
# which the layout text would otherwise set into the rows beside it
TYPE_AREA = (30, 565)


def pdftotext(pdf, mode):
    left, right = TYPE_AREA
    crop = ["-x", str(left), "-y", "0", "-W", str(right - left), "-H", "842"]
    return subprocess.run(
        ["pdftotext", mode, *crop, str(pdf), "-"],
        check=True, capture_output=True, text=True, encoding="utf-8",
    ).stdout


# a word of pdftotext -bbox: its box and its text
BBOX_WORD = re.compile(
    r'<word xMin="[^"]*" yMin="(?P<top>[^"]*)" xMax="[^"]*" '
    r'yMax="(?P<bottom>[^"]*)">(?P<text>[^<]*)</word>'
)


def font_heights(text, bbox):
    """The height of the type a cell of the layout text is set in.

    The layout text and pdftotext's word boxes are two views of one PDF, page
    by page. A cell is found on its page as the run of words it consists of,
    and its height is that of its first word. A cell found nowhere, or at two
    heights, is refused: the layout text would then be read against the wrong
    type.
    """
    pages = [
        [
            (html.unescape(w["text"]), float(w["bottom"]) - float(w["top"]))
            for w in BBOX_WORD.finditer(page)
        ]
        for page in bbox.split("<page ")[1:]
    ]
    # the line numbers of str.splitlines, which ends a line at a form feed too
    page_of, n = [], 0
    for line in text.splitlines(keepends=True):
        page_of.append(n)
        n += line.endswith("\f")

    def height(line, cell):
        words, found = cell.split(), set()
        page = pages[page_of[line]]
        for k in range(len(page) - len(words) + 1):
            if all(page[k + m][0] == w for m, w in enumerate(words)):
                found.add(round(page[k][1], 1))
        if len(found) != 1:
            sys.exit(f"{cell!r} on page {page_of[line] + 1}: at heights {sorted(found)}")
        return found.pop()

    return height


def columns(head):
    """Where each column starts, read off a page heading."""
    return dict(zip(FIELDS, (head.find(h) for h in HEADINGS)))


def cells(line, start=0):
    """The printed cells of a line, each with the column it starts in."""
    return [(m.group(), m.start()) for m in CELL.finditer(line) if m.start() >= start]


def field_of(cols, at):
    """The column a cell belongs to: the nearest heading."""
    return min(cols, key=lambda f: abs(cols[f] - at))


def numeric_field_of(cols, at):
    """The column a number belongs to: the nearest numeric heading."""
    return field_of({f: cols[f] for f in ("min", "max", "default")}, at)


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


def parse_rows(text, height):
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
            if FOOTNOTE_CELL.match(cell):
                continue
            f = field_of(cols, at)
            # no unit is a number: a default printed nearer the unit's heading
            if f == "unit" and is_number(cell):
                f = numeric_field_of(cols, at)
            row[f].append(cell)
        name, more_unit = continuation(lines, i, cols, one(row["name"]), height)
        row["name"] = [name]
        row["unit"] += more_unit
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


def continuation(lines, i, cols, name, height):
    """The name of the row on line i, with the lines that continue it, and
    the unit cells they hold.

    A name too long for its column, and occasionally its unit, run on into the
    next line. A remark is printed in the same column, after a blank line or,
    from revision 12 on, directly below, and only its smaller type tells it
    from the name: the first line set smaller than the name ends the row.
    """
    unit, size = [], None
    for j in range(i + 1, len(lines)):
        line = lines[j]
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
        more = [c for c, at in taken if field_of(cols, at) != "unit"]
        if more:
            size = size or height(i, name)
            if height(j, more[0]) < size - FONT_SLACK:
                break
        unit += [c for c, at in taken if field_of(cols, at) == "unit"]
        for cell in more:
            name = join_name(name, cell)
    return name, unit


def partition(p, xs):
    return [x for x in xs if p(x)], [x for x in xs if not p(x)]


def one(found):
    return found[0] if found else ""


# the letter or number that tells one member of a family from the next
FAMILY_TAIL = re.compile(r" (?:[A-G]|[1-9])$")
# the zone module, which leads a name rather than ending it
FAMILY_MODULE = re.compile(r"^Zonenmodul \d+ ")


def family(r):
    """What a register shares with the others the manual lists it beside.

    Heating circuits A to G, compressors 1 to 4, and zone modules 1 to 10 with
    their rooms 1 to 6 get an address each, but the enumeration of their values
    is printed once, beside the first of them. Members are alike in everything
    but the letter or number ending the name and the number of the zone module.
    """
    stem = FAMILY_MODULE.sub("Zonenmodul ", FAMILY_TAIL.sub("", r["name"]))
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


# a row of the N2_GLTMON page: address, name, access, value, the value last
# written over Modbus
GLT_ROW = re.compile(
    r"<tr><td>(\d+)</td><td>(.*?)</td><td>(\w+)</td>"
    r"<td[^>]*>(.*?)</td><td[^>]*>(.*?)</td></tr>"
)
# the page prints the name, a space, and the unit in parentheses or nothing:
# a name with no unit ends in that space, which keeps its own parentheses
GLT_NAME = re.compile(r"^(?P<name>.*?)\s*(?:\((?P<unit>[^()]*)\))?$")


def read_software(path):
    """The software the table describes, written by hand: series, major and
    minor, and the patch, None where it is unknown."""
    with path.open(newline="") as fh:
        rows = list(csv.DictReader(fh, delimiter="\t"))
    if len(rows) != 1:
        sys.exit(f"{path}: one row expected, found {len(rows)}")
    (r,) = rows
    return {
        "series": int(r["series"]),
        "major": int(r["major"]),
        "minor": int(r["minor"]),
        "patch": None if r["patch"] == "unknown" else int(r["patch"]),
    }


def software_text(s):
    patch = "unknown" if s["patch"] is None else s["patch"]
    return f"{s['series']}.{s['major']}-{s['minor']}, patch {patch}"


def web_version(text):
    """Series, major and minor of the version N2_SYSTEM_INFO prints,
    T_NAV10_20.24-2608-g0c686ed41, or None."""
    m = re.fullmatch(r"(\d+)\.(\d+)-(\d+)(?:-.*)?", text.rsplit("_", 1)[-1])
    return tuple(int(g) for g in m.groups()) if m else None


def system_info_version(frames):
    """The version the N2_SYSTEM_INFO page of a webapi capture prints, if it
    holds the page."""
    for d in setting_details(frames):
        if d.get("name") == "N2_SYSTEM_INFO":
            m = re.search(r"<td>Software Version</td><td>([^<]*)</td>", d["value"])
            if m:
                return m.group(1)
    return None


def modbus_entries(path, capture, software):
    """The entries of a scan or a widths capture, once the software it
    records is the table's. A capture from before captures recorded it is a
    bare list, and is taken unchecked."""
    if isinstance(capture, list):
        print(f"{path}: records no software; not checked", file=sys.stderr)
        return capture
    read = capture["software"]
    if read is None or read["status"] != "ok":
        sys.exit(f"{path}: the software could not be read: {read}")
    if (read["major"], read["minor"], read["patch"]) != (
        software["major"], software["minor"], software["patch"]
    ):
        sys.exit(
            f"{path}: read on major {read['major']}, minor {read['minor']}, "
            f"patch {read['patch']}; data/navigator-10-software.tsv states "
            f"{software_text(software)}"
        )
    return capture["entries"]


def webapi_entries(path, capture, software):
    """The entries of a webapi capture, once the software it was read on is
    the table's: as the capture records it, or, in a capture from before, as
    its N2_SYSTEM_INFO page prints it."""
    if isinstance(capture, list):
        frames, text = capture, system_info_version(capture)
        if text is None:
            print(f"{path}: names no software; not checked", file=sys.stderr)
            return frames
    else:
        frames, text = capture["entries"], capture["software"]
        if not isinstance(text, str):
            sys.exit(f"{path}: the software could not be read: {text}")
    if web_version(text) != (software["series"], software["major"], software["minor"]):
        sys.exit(
            f"{path}: read on {text}; data/navigator-10-software.tsv states "
            f"{software_text(software)}"
        )
    return frames


def setting_details(capture):
    """Every setting a webapi capture asked the detail of, in order."""
    return [
        r["settingDetail"]
        for frame in capture
        for r in frame.get("responses") or []
        if "settingDetail" in r
    ]


def gltmon_page(capture):
    """The last N2_GLTMON page a webapi capture holds."""
    pages = [
        d["value"] for d in setting_details(capture) if d.get("name") == "N2_GLTMON"
    ]
    if not pages:
        sys.exit("the webapi capture holds no N2_GLTMON page")
    return pages[-1]


def read_joins(path):
    """The hand-written parameter identifiers of the page's rows, by address."""
    with path.open(newline="") as fh:
        rows = csv.DictReader(fh, delimiter="\t")
        return {int(r["address"]): r["parameter"] for r in rows}


def join_parameters(joins, registers):
    """Give the page's rows the identifiers written for them.

    Refused: an address that is not a row of the page, and an identifier some
    other row already carries, since the join would then name two registers.
    """
    for a, p in joins.items():
        if registers.get(a, {}).get("source") != "gltmon":
            sys.exit(f"{a} is given the parameter {p} but is not a row of N2_GLTMON")
    for a, p in joins.items():
        holders = [b for b, r in registers.items() if r["parameter"] == p]
        holders += [b for b, q in joins.items() if q == p and b != a]
        if holders:
            sys.exit(f"{a} is given the parameter {p}, which {holders[0]} carries too")
    for a, p in joins.items():
        registers[a]["parameter"] = p


def check_joins(joins, page, capture):
    """Refuse a join the capture contradicts.

    Both values come from the same walk, minutes apart: the page's for the
    address and the tree's for the identifier. Agreeing proves little where
    circuits share a value, but disagreeing proves the join wrong.
    """
    tree = {
        d["param"]: d["value"]
        for d in setting_details(capture)
        if "param" in d and "value" in d
    }
    shown = {
        int(a): html.unescape(v).strip() for a, _, _, v, _ in GLT_ROW.findall(page)
    }
    for a, p in joins.items():
        if p not in tree:
            sys.exit(f"the settings tree of the capture lacks {p}, given to {a}")
        v = shown.get(a)
        if v is None or not is_number(v) or float(v) != float(tree[p]):
            sys.exit(f"{a} printed {v!r} on the page, where {p} holds {tree[p]}")


def width(reads, a):
    """How many registers the value at an address spans, by a widths capture.

    Two registers answer when asked for two, and the address inside them
    refuses on its own. One register refuses to be read as two, unless another
    follows it; that one then answers on its own.
    """
    def ok(at, q):
        r = reads.get((at, q))
        return r is not None and r["status"] == "ok"

    def refused(at, q):
        return (at, q) in reads and not ok(at, q)

    if ok(a, 2) and refused(a + 1, 1):
        return 2
    if ok(a, 1) and (refused(a, 2) or ok(a + 1, 1)):
        return 1
    return None


# how many registers a datatype spans
WIDTH = {"FLOAT": 2, "DWORD": 2}


def prefer_manual(a, measured, manual):
    """Whether the manual's row stands where the page lists the address too.

    The manual states what the page does not, persistence, range, default and
    enumerations, so its row stands, unless the width the reads measured
    contradicts its datatype.
    """
    if a not in manual:
        return False
    printed = WIDTH.get(manual[a]["datatype"], 1)
    if measured is None or measured == printed:
        return True
    print(
        f"dropped {a} of the manual: it prints a {manual[a]['datatype']}, "
        f"the reads measured {measured} registers",
        file=sys.stderr,
    )
    return False


def drop_overlapped(registers):
    """Drop a manual row two registers wide whose second register is a row
    of the page, which the reads measured as a value of its own."""
    for a in sorted(registers):
        r, next_ = registers.get(a), registers.get(a + 1)
        if (
            r and r["source"] == "manual" and WIDTH.get(r["datatype"]) == 2
            and next_ and next_["source"] == "gltmon"
        ):
            print(
                f"dropped {a} of the manual: its {r['datatype']} overlaps "
                f"{a + 1} of N2_GLTMON",
                file=sys.stderr,
            )
            del registers[a]


def gltmon_rows(page, reads, manual):
    """The registers the page lists and the manual does not, or not as the
    reads measured them.

    The page states an address, a name with its unit, and an access right; the
    datatype comes from the measured width, and nothing states persistence,
    range or default. A row without a name, with a value that is neither a
    number, true, false nor redacted, or with no decisive width stays out;
    where the width contradicts the manual, the manual's row goes out with it.
    """
    out = {}
    for addr, name, access, value, _ in GLT_ROW.findall(page):
        a = int(addr)
        if prefer_manual(a, width(reads, a), manual):
            continue
        manual.pop(a, None)
        m = GLT_NAME.match(html.unescape(name))
        value = html.unescape(value).strip()
        read = not value or is_number(value) or value in ("true", "false", REDACTED)
        why = (
            "no name" if not m.group("name")
            else "its value is not a number" if not read
            else None
        )
        w = None if why else width(reads, a)
        if not why and w is None:
            why = "its width was not measured, or the reads cannot tell"
        if why:
            print(f"left out {a}: {why}", file=sys.stderr)
            continue
        out[a] = dict(
            address=a,
            datatype={2: "FLOAT", 1: "one-register"}[w],
            access=access,
            persistence="unknown",
            name=m.group("name"),
            parameter="", min="", max="", default="",
            unit=m.group("unit") or "",
            source="gltmon",
        )
    return out


# a member of a family the manual prints per heating circuit or zone module
FAMILY_MEMBER = re.compile(r"(?:^|\s)[A-G](?:\s|$)|^Zonenmodul \d+ ")
CONSTRUCTOR = re.compile(r"[A-Z][A-Za-z0-9]*")
# what Haddock would read as markup inside @...@
HADDOCK_SPECIAL = re.compile(r"([\\/'`\"@<>*_$#])")


def read_targets(path, registers):
    """The hand-written names of the registers a write may go to.

    Refused: an address the table lacks or nothing may write, a write-only
    register whose write costs an EEPROM cycle, which a write saves only by
    reading first, a name that is no constructor or names two registers, and
    a member of a family, which would need a circuit or a zone module as an
    argument and is not written yet.
    """
    with path.open(newline="") as fh:
        rows = [(int(r["address"]), r["name"]) for r in csv.DictReader(fh, delimiter="\t")]
    names = [n for _, n in rows]
    for a, n in rows:
        r = registers.get(a)
        if r is None:
            sys.exit(f"target {n} at {a}: the table has no register there")
        if r["access"] == "RO":
            sys.exit(f"target {n} at {a}: the register is read-only")
        if r["access"] == "W" and r["persistence"] != "volatile":
            sys.exit(f"target {n} at {a}: write-only, and a write costs an EEPROM cycle")
        if not CONSTRUCTOR.fullmatch(n) or names.count(n) > 1:
            sys.exit(f"target {n} at {a}: not a constructor name, or not unique")
        if FAMILY_MEMBER.search(r["name"]):
            sys.exit(f"target {n} at {a}: {r['name']!r} is a family member")
    if len({a for a, _ in rows}) != len(rows):
        sys.exit("a target address is named twice")
    return sorted(rows)


def haddock_code(text):
    return "@" + HADDOCK_SPECIAL.sub(r"\\\1", text) + "@"


def target_module(targets, registers):
    """The source of IDM.Navigator.Target."""

    def cost(a):
        return "Free" if registers[a]["persistence"] == "volatile" else "EepromCycle"

    def comment(a):
        r = registers[a]
        unit = f", {r['unit']}" if r["unit"] else ""
        return f"  -- | {a} {haddock_code(r['name'])}{unit}"

    out = [
        "{-# LANGUAGE DataKinds #-}",
        "{-# LANGUAGE GADTs #-}",
        "{-# LANGUAGE KindSignatures #-}",
        "{-# LANGUAGE StandaloneDeriving #-}",
        "{-# LANGUAGE TemplateHaskell #-}",
        "",
        "-- |",
        "-- Module      :  IDM.Navigator.Target",
        "-- Description :  The registers a write may go to",
        "-- Copyright   :  2026 Dominik Schrempf",
        "-- License     :  BSD-3-Clause",
        "--",
        "-- Generated by @tools\\/transcribe.py@ from",
        "-- @data\\/navigator-10-targets.tsv@: edit that file, not this one.",
        "--",
        "-- Of the writable registers of the table, only those listed there are",
        "-- reachable. Listing one goes with trying on a machine that a write to it",
        "-- takes effect. Each constructor's comment gives the register's name in the",
        "-- parameter list.",
        "module IDM.Navigator.Target",
        "  ( Target (..),",
        "    SomeTarget (..),",
        "    targetRegister,",
        "    targetCost,",
        "    targets,",
        "  )",
        "where",
        "",
        "import IDM.Modbus.TCP (Address (..))",
        "import IDM.Navigator.Register",
        "import IDM.Navigator.Target.Splice (costAt, registerOf)",
        "",
        "-- | A register a write may go to, by what a write to it costs.",
        "data Target (c :: Cost) where",
    ]
    for a, n in targets:
        out += [comment(a), f"  {n} :: Target '{cost(a)}"]
    out += [
        "",
        "deriving instance Show (Target c)",
        "",
        "deriving instance Eq (Target c)",
        "",
        "-- | A target whose cost 'targetCost' tells.",
        "data SomeTarget where",
        "  SomeTarget :: Target c -> SomeTarget",
        "",
        "-- | The register, as the table has it.",
        "targetRegister :: Target c -> Register",
        "targetRegister t = case t of",
    ]
    out += [f"  {n} -> $$(registerOf (Address {a}))" for a, n in targets]
    out += [
        "",
        "-- | What a write costs, from the table; the build fails where a",
        "-- constructor's type says otherwise.",
        "targetCost :: Target c -> SCost c",
        "targetCost t = case t of",
    ]
    out += [f"  {n} -> $(costAt (Address {a}))" for a, n in targets]
    out += [
        "",
        "-- | Every target, in address order.",
        "targets :: [SomeTarget]",
        "targets =",
    ]
    out += [f"  {'[' if i == 0 else ','} SomeTarget {n}" for i, (_, n) in enumerate(targets)]
    out += ["  ]", ""]
    return "\n".join(out)


def main():
    args = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    args.add_argument("manual", type=Path)
    args.add_argument("--scan", type=Path)
    args.add_argument("--webapi", type=Path)
    args.add_argument("--widths", type=Path)
    args = args.parse_args()
    if (args.webapi is None) != (args.widths is None):
        sys.exit("--webapi and --widths go together")

    text = pdftotext(args.manual, "-layout")
    height = font_heights(text, pdftotext(args.manual, "-bbox"))
    data = HERE / "data"
    table = data / "navigator-10-registers.tsv"
    with table.open(newline="") as fh:
        previous = {int(r["address"]): r for r in csv.DictReader(fh, delimiter="\t")}
    software = read_software(data / "navigator-10-software.tsv")
    if args.scan:
        scan = json.loads(args.scan.read_text())
        observed = {
            r["address"]: {"ok": "present", "exception": "absent"}.get(r["status"])
            for r in modbus_entries(args.scan, scan, software)
        }
    else:
        observed = {a: r["observed"] for a, r in previous.items()}

    registers = parse_rows(text, height)
    enums = share_within_families(parse_enums(text, registers), registers)
    for r in registers.values():
        r["source"] = "manual"
    joins = read_joins(data / "navigator-10-gltmon-parameters.tsv")
    if args.webapi:
        widths = json.loads(args.widths.read_text())
        reads = {
            (r["address"], r["quantity"]): r
            for r in modbus_entries(args.widths, widths, software)
        }
        capture = webapi_entries(
            args.webapi, json.loads(args.webapi.read_text()), software
        )
        page = gltmon_page(capture)
        registers |= gltmon_rows(page, reads, registers)
    else:
        registers |= {
            a: {**r, "address": a, "parameter": ""}
            for a, r in previous.items()
            if r.get("source") == "gltmon"
            and not prefer_manual(a, WIDTH.get(r["datatype"], 1), registers)
        }
    drop_overlapped(registers)
    join_parameters(joins, registers)
    if args.webapi:
        check_joins(joins, page, capture)

    with table.open("w", newline="") as fh:
        w = csv.writer(fh, delimiter="\t", lineterminator="\n")
        w.writerow(
            "address datatype access persistence name parameter "
            "min max default unit source observed".split()
        )
        for a in sorted(registers):
            r = registers[a]
            w.writerow(
                [
                    r["address"], r["datatype"], r["access"], r["persistence"],
                    r["name"], r["parameter"], r["min"], r["max"], r["default"],
                    r["unit"], r["source"],
                    observed.get(a) or "untested",
                ]
            )

    targets = read_targets(data / "navigator-10-targets.tsv", registers)
    (HERE / "src" / "IDM" / "Navigator" / "Target.hs").write_text(
        target_module(targets, registers), encoding="utf-8"
    )

    with (data / "navigator-10-enums.tsv").open("w", newline="") as fh:
        w = csv.writer(fh, delimiter="\t", lineterminator="\n")
        w.writerow(["address", "code", "label"])
        for (a, c), label in sorted(enums.items()):
            w.writerow([a, c, label])

    print(
        f"{len(registers)} registers, "
        f"{sum(r['source'] == 'gltmon' for r in registers.values())} of them "
        f"from N2_GLTMON, {len(enums)} enumerated values over "
        f"{len({a for a, _ in enums})} addresses, {len(targets)} targets",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
