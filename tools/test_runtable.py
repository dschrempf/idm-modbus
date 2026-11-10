#!/usr/bin/env python3
"""Tests of `tools/runtable.py`, on the hand-written captures in `tools/fixtures/`.

    python3 tools/test_runtable.py

`fixtures/drive.jsonl` is a drive file with an event of every kind
`idm-drive` writes and a `write` of every outcome but `unconfirmed`;
`watch.jsonl`, `write.log` and `webwatch.jsonl` are a watch, a `drivepv.py`
write log and a webwatch with level lines. Where `captures/` holds write
logs, or the directory `RUNTABLE_CAPTURES` names, a last test runs each with
the watch it belongs to, once as a write log and once recast as a drive
file's `write` events, and asks for the same table.
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
FIXTURES = HERE / "fixtures"
RUNTABLE = HERE / "runtable.py"
CAPTURES = Path(os.environ.get("RUNTABLE_CAPTURES", HERE.parent / "captures"))

sys.path.insert(0, str(HERE))
import runtable  # noqa: E402


def run(*args):
    p = subprocess.run([sys.executable, str(RUNTABLE), *map(str, args)], capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


def table(text):
    """A table written with runs of spaces between cells, as runtable writes it with tabs."""
    return "".join("\t".join(line.split()) + "\n" for line in text.strip().splitlines())


def as_drive(watch, log, out):
    """The watch with the 74 writes of a `drivepv.py` log appended as a drive file's `write` events."""
    reads, _ = runtable.read_watch(watch)
    with open(out, "w") as f:
        begin = {"time": reads[0][0].isoformat(timespec="milliseconds"), "event": "begin", "pid": 4242, "schedule": "schedules/example.toml", "text": ""}
        f.write(json.dumps(begin) + "\n")
        f.write(Path(watch).read_text())
        for t, v in runtable.read_writes(log, reads[0][0]):
            event = {"time": t.isoformat(timespec="milliseconds"), "event": "write", "address": 74, "value": v, "outcome": "confirmed", "detail": None}
            f.write(json.dumps(event) + "\n")


class Drive(unittest.TestCase):
    def test_table(self):
        # The skip and the missing 4122 cost the round at 12:00:31 its row,
        # and the unopened session that at 12:00:51. The export of 12:00:41
        # was clamped, and its write failed, so the mean does not take it.
        code, out, _ = run(FIXTURES / "drive.jsonl", "--mean", "10")
        self.assertEqual(code, 0)
        self.assertEqual(
            out,
            table(
                """
                time      74     1100  4122  mean74  export  written
                12:00:01  -0.50  0     0.00  -       -       -
                12:00:11  2.00   1     1.85  -       0.15    0.10
                12:00:21  0.10   1     2.03  0.14    -0.03   -0.03
                12:00:41  -0.50  1     2.20  -0.03   -0.20   -0.10
                12:01:01  0.10   0     0.00  -0.03   -       -
                """
            ),
        )

    def test_acknowledged(self):
        t = datetime.fromisoformat("2026-11-10T12:00:00+01:00")
        events = [
            (t, {"event": "write", "address": 74, "value": float(i), "outcome": o, "detail": None})
            for i, o in enumerate(["confirmed", "did-not-stick", "unconfirmed", "read-back-failed", "refused", "failed"])
        ]
        events.append((t, {"event": "write", "address": 88, "value": 9.0, "outcome": "confirmed", "detail": None}))
        events.append((t, {"event": "export", "pv": 2.0, "draw": 1.0, "export": 1.0, "written": 0.1}))
        self.assertEqual([v for _, v in runtable.drive_writes(events)], [0.0, 1.0, 2.0, 3.0])

    def test_last(self):
        _, out, _ = run(FIXTURES / "drive.jsonl", "--mean", "10", "--last")
        self.assertEqual(out.splitlines()[1:], ["12:01:01\t0.10\t0\t0.00\t-0.03\t-\t-"])

    def test_range(self):
        _, out, _ = run(FIXTURES / "drive.jsonl", "--mean", "10", "--from", "12:00:11", "--to", "12:00:21")
        self.assertEqual([r.split("\t")[0] for r in out.splitlines()[1:]], ["12:00:11", "12:00:21"])

    def test_no_writes_log(self):
        code, _, err = run(FIXTURES / "drive.jsonl", "--writes", FIXTURES / "write.log")
        self.assertEqual(code, 2)
        self.assertIn("--writes", err)


class Level(unittest.TestCase):
    def test_table(self):
        # Left at 12:00:22 for the renewal, back at 12:00:52; fallen back at
        # 12:01:02, a failed entry at 12:01:12, entered at 12:01:42 and left
        # at 12:01:52. 10263 answers at Kunde, 6245 does not.
        code, out, _ = run(FIXTURES / "watch.jsonl", "--web", FIXTURES / "webwatch.jsonl", "--writes", FIXTURES / "write.log", "--mean", "20")
        self.assertEqual(code, 0)
        rows = [r.split("\t") for r in out.splitlines()]
        self.assertEqual(rows[0], ["time", "74", "4122", "mean74", "level", "rps", "motor", "forecast"])
        self.assertEqual(
            [(r[0], r[4], r[5], r[6]) for r in rows[1:]],
            [
                ("12:00:00", "-", "-", "-"),
                ("12:00:10", "Fachmann (2)", "30.0", "1.2"),
                ("12:00:20", "Fachmann (2)", "32.0", "1.3"),
                ("12:00:30", "Kunde (0)", "-", "-"),
                ("12:00:40", "Kunde (0)", "-", "-"),
                ("12:00:50", "Kunde (0)", "-", "-"),
                ("12:01:00", "Fachmann (2)", "34.0", "1.4"),
                ("12:01:10", "Kunde (0)", "-", "-"),
                ("12:01:20", "Kunde (0)", "-", "-"),
                ("12:01:30", "Kunde (0)", "-", "-"),
                ("12:01:40", "Kunde (0)", "-", "-"),
                ("12:01:50", "Fachmann (2)", "36.0", "1.5"),
                ("12:02:00", "Kunde (0)", "-", "-"),
            ],
        )
        self.assertEqual({r[7] for r in rows[2:]}, {"1.5"})

    def test_without_level_lines(self):
        # A webwatch from before the level lines: no level column, and 6245's
        # last answer stands, as it always has.
        with tempfile.TemporaryDirectory() as d:
            web = Path(d) / "webwatch.jsonl"
            lines = (FIXTURES / "webwatch.jsonl").read_text().splitlines(keepends=True)
            web.write_text("".join(line for line in lines if '"level"' not in line))
            _, out, _ = run(FIXTURES / "watch.jsonl", "--web", web)
        rows = [r.split("\t") for r in out.splitlines()]
        self.assertEqual(rows[0], ["time", "74", "4122", "mean74", "rps", "motor", "forecast"])
        self.assertEqual(rows[4][4:6], ["32.0", "1.3"])

    def test_fachmann(self):
        self.assertTrue(runtable.fachmann("Fachmann (2)"))
        self.assertFalse(runtable.fachmann("Kunde (0)"))
        self.assertFalse(runtable.fachmann("1"))


class Writes(unittest.TestCase):
    def same_table(self, watch, log, *args):
        with tempfile.TemporaryDirectory() as d:
            drive = Path(d) / "drive.jsonl"
            as_drive(watch, log, drive)
            old = run(watch, "--writes", log, *args)
            new = run(drive, *args)
        self.assertEqual(old[0], 0)
        self.assertEqual(old, new)

    def test_log_and_drive_agree(self):
        self.same_table(FIXTURES / "watch.jsonl", FIXTURES / "write.log", "--mean", "20")

    def test_reads_of_74_without_writes(self):
        _, out, _ = run(FIXTURES / "watch.jsonl", "--mean", "20")
        self.assertEqual([r.split("\t")[3] for r in out.splitlines()[1:6]], ["-", "-", "0.29", "0.99", "0.74"])

    @unittest.skipUnless(any(CAPTURES.glob("navigator-10-write-*.log")), f"no write logs in {CAPTURES}")
    def test_captures(self):
        # Each write log with the watch begun last before it on its day.
        watches = sorted(CAPTURES.glob("navigator-10-watch-*.jsonl"))
        for log in sorted(CAPTURES.glob("navigator-10-write-*.log")):
            stamp = log.stem.removeprefix("navigator-10-write-")
            day = stamp.rsplit("-", 1)[0]
            before = [w for w in watches if w.stem.removeprefix("navigator-10-watch-") <= stamp and day in w.stem]
            if not before or "wrote" not in log.read_text():
                continue
            with self.subTest(log=log.name):
                self.same_table(before[-1], log)


if __name__ == "__main__":
    unittest.main()
