#!/usr/bin/env python3
"""Line up a run's captures by time: what was written, what the controller read, what it did.

One row per round of an `idm-dump --watch`: every address the watch reads,
the mean of 74 over the window the controller averages it over (`PV011`, 2
minutes by default), and, given a webwatch of 6245 and 10263, the
compressor's speed and motor power and the PV page's forecast. A webwatch
with `--reason` adds the heat pump's `operationMode` and the bits of its
`info`, joined by `+`, whose names per mode `IDM.Navigator.Web` states. A
webwatch with level lines, from `idm-web --watch --fachmann`, adds the user
level each round was read at; in a round not at Fachmann, 6245 has no
answer, and its speed and power are `-` rather than the last ones read.

WATCH is a watch or the drive file of `idm-drive`, which holds the same
read lines and an event line wherever the drive did something. A drive
file's writes of 74 are its `write` events that the controller
acknowledged, and the export of a `pv` phase, the PV less 4122, goes in an
`export` column beside the `written` value, which the bounds may have
clamped; both are in the row of the round whose 4122 they were computed
from. The mean is taken from the writes, of a drive file or of the
`drivepv.py` log `--writes` names, whose times are exact, and from the
watch's reads of 74 otherwise:

    tools/runtable.py WATCH [--web WEBWATCH] [--writes LOG] [--mean SECONDS]
                            [--from HH:MM:SS] [--to HH:MM:SS] [--last]

`--last` prints the newest row only, as a status line while a run goes on.
It reproduces the table of `doc/verification/2026-11-06-pv-surplus-loop.md`
to within one round of the watch.
"""

import argparse
import json
import re
from bisect import bisect_right
from datetime import datetime, timedelta

# The outcomes of a drive's `write` event that went out and were answered.
ACKNOWLEDGED = ("confirmed", "did-not-stick", "unconfirmed", "read-back-failed")


def json_lines(path):
    with open(path) as f:
        for line in f:
            try:
                yield json.loads(line)
            except ValueError:
                continue


def read_watch(path):
    """The reads of a watch or a drive file, as (time, address, value), and a drive file's events, as (time, event)."""
    reads, events = [], []
    for r in json_lines(path):
        if "event" in r:
            events.append((datetime.fromisoformat(r["time"]), r))
        elif r.get("status") == "ok":
            reads.append((datetime.fromisoformat(r["time"]), r["address"], r["value"]))
    return reads, events


def drive_writes(events):
    """The writes of 74 that a drive file records as acknowledged, as (time, value)."""
    return [
        (t, e["value"])
        for t, e in events
        if e["event"] == "write" and e["address"] == 74 and e["outcome"] in ACKNOWLEDGED
    ]


def html_cells(html):
    return [c.strip() for c in re.sub(r"<[^>]+>", "|", html).split("|") if c.strip()]


def bits(n):
    return "+".join(str(1 << i) for i in range(n.bit_length()) if n >> i & 1) or "0"


def read_web(path):
    """(time, field, value) from 6245's speed and motor power, 10263's forecast, the heat pump's request and the level lines."""
    out = []
    for r in json_lines(path):
        if "level" in r and "request" not in r:
            out.append((datetime.fromisoformat(r["captured"]), "level", r["userLevel"]))
            continue
        if not r.get("responses"):
            continue
        t = datetime.fromisoformat(r["captured"])
        if r["request"]["controller"] == "system":
            for m in r["responses"]:
                pump = m.get("system", {}).get("heatpump")
                if pump:
                    out.append((t, "mode", pump["operationMode"]))
                    out.append((t, "info", bits(pump.get("info", 0))))
            continue
        setting = r["request"]["data"]["settingId"]
        if setting not in ("6245", "10263"):
            continue
        html = r["responses"][0].get("settingDetail", {}).get("value", "")
        cells = html_cells(html)
        if setting == "6245":
            for name, field in (("motor speed", "rps"), ("motor power", "motor")):
                if name in cells:
                    out.append((t, field, cells[cells.index(name) + 1]))
        elif setting == "10263" and "mom./prog. Leistung Heizen" in cells:
            out.append((t, "forecast", cells[cells.index("mom./prog. Leistung Heizen") + 1]))
    return out


def fachmann(level):
    """Whether a level line's `userLevel`, as `idm-web` spells it, is the Fachmann level."""
    return level.startswith("Fachmann")


def read_writes(path, day):
    out = []
    with open(path) as f:
        for line in f:
            m = re.match(r"(\d\d:\d\d:\d\d) 74 .*wrote (\S+);", line)
            if m:
                t = datetime.combine(day.date(), datetime.strptime(m.group(1), "%H:%M:%S").time(), day.tzinfo)
                out.append((t, float(m.group(2))))
    return out


def mean(steps, t, window):
    """The mean over (t - window, t] of a step function given as sorted (time, value)."""
    start = t - timedelta(seconds=window)
    i = bisect_right([s for s, _ in steps], start) - 1
    if i < 0:
        return None
    total, at, value = 0.0, start, steps[i][1]
    for s, v in steps[i + 1 :]:
        if s > t:
            break
        total += value * (s - at).total_seconds()
        at, value = s, v
    total += value * (t - at).total_seconds()
    return total / window


def fmt(v):
    if v is None:
        return "-"
    if isinstance(v, float):
        return f"{v:.2f}"
    return str(v)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("watch")
    p.add_argument("--web")
    p.add_argument("--writes")
    p.add_argument("--mean", type=int, default=120)
    p.add_argument("--from", dest="since")
    p.add_argument("--to", dest="until")
    p.add_argument("--last", action="store_true")
    a = p.parse_args()

    reads, events = read_watch(a.watch)
    if a.writes and events:
        p.error("--writes is for a drivepv.py log; a drive file holds its own writes")
    if not reads:
        return
    addresses = list(dict.fromkeys(addr for _, addr, _ in reads))
    pace = addresses[-1]
    if a.writes:
        steps = read_writes(a.writes, reads[0][0])
    elif events:
        steps = drive_writes(events)
    else:
        steps = [(t, v) for t, addr, v in reads if addr == 74]
    exports = [(t, float(e["export"]), float(e["written"])) for t, e in events if e["event"] == "export"]
    web = read_web(a.web) if a.web else []
    fields = ["rps", "motor", "forecast"] if web else []
    fields += [f for f in ("mode", "info") if any(field == f for _, field, _ in web)]
    if any(field == "level" for _, field, _ in web):
        fields = ["level"] + fields
    drive = ["export", "written"] if exports else []

    header = ["time"] + [str(x) for x in addresses] + ["mean74"] + drive + fields
    times, rows = [], []
    current, w = {}, 0
    for t, addr, v in reads:
        current[addr] = v
        if addr != pace:
            continue
        while w < len(web) and web[w][0] <= t:
            _, field, value = web[w]
            current[field] = value
            if field == "level" and not fachmann(value):
                current.pop("rps", None)
                current.pop("motor", None)
            w += 1
        m = mean(steps, t, a.mean) if steps else None
        times.append(t)
        rows.append([t] + [current.get(x) for x in addresses] + [m] + [None for _ in drive] + [current.get(f) for f in fields])
    at = 1 + len(addresses) + 1
    for t, export, written in exports:
        i = bisect_right(times, t) - 1
        if i >= 0:
            rows[i][at : at + 2] = [export, written]
    rows = [[f"{r[0]:%H:%M:%S}"] + r[1:] for r in rows]
    rows = [r for r in rows if not (a.since and r[0] < a.since) and not (a.until and r[0] > a.until)]
    if a.last:
        rows = rows[-1:]
    print("\t".join(header))
    for r in rows:
        print("\t".join(fmt(v) for v in r))


if __name__ == "__main__":
    main()
