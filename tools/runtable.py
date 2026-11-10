#!/usr/bin/env python3
"""Line up a run's captures by time: what was written, what the controller read, what it did.

One row per round of an `idm-dump --watch`: every address the watch reads,
the mean of 74 over the window the controller averages it over (`PV011`, 2
minutes by default), and, given a webwatch of 6245 and 10263, the
compressor's speed and motor power and the PV page's forecast. A webwatch
with `--reason` adds the heat pump's `operationMode` and the bits of its
`info`, joined by `+`, whose names per mode `IDM.Navigator.Web` states. The mean is
taken from the write log where one is given, whose times are exact, and from
the watch's reads of 74 otherwise:

    tools/runtable.py WATCH [--web WEBWATCH] [--writes LOG] [--mean SECONDS]
                            [--from HH:MM:SS] [--to HH:MM:SS] [--last]

`--last` prints the newest row only, as a status line while a run goes on.
It reproduces the table of `doc/verification-2026-11-06-pv-surplus-loop.md`
to within one round of the watch.
"""

import argparse
import json
import re
from bisect import bisect_right
from datetime import datetime, timedelta


def read_watch(path):
    rows = []
    for line in open(path):
        try:
            r = json.loads(line)
        except ValueError:
            continue
        if r.get("status") == "ok":
            rows.append((datetime.fromisoformat(r["time"]), r["address"], r["value"]))
    return rows


def html_cells(html):
    return [c.strip() for c in re.sub(r"<[^>]+>", "|", html).split("|") if c.strip()]


def bits(n):
    return "+".join(str(1 << i) for i in range(n.bit_length()) if n >> i & 1) or "0"


def read_web(path):
    """(time, field, value) from 6245's speed and motor power, 10263's forecast and the heat pump's request."""
    out = []
    for line in open(path):
        try:
            r = json.loads(line)
        except ValueError:
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


def read_writes(path, day):
    out = []
    for line in open(path):
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

    reads = read_watch(a.watch)
    if not reads:
        return
    addresses = list(dict.fromkeys(addr for _, addr, _ in reads))
    pace = addresses[-1]
    if a.writes:
        steps = read_writes(a.writes, reads[0][0])
    else:
        steps = [(t, v) for t, addr, v in reads if addr == 74]
    web = read_web(a.web) if a.web else []
    fields = ["rps", "motor", "forecast"] if web else []
    fields += [f for f in ("mode", "info") if any(field == f for _, field, _ in web)]

    header = ["time"] + [str(x) for x in addresses] + ["mean74"] + fields
    rows = []
    current, w = {}, 0
    for t, addr, v in reads:
        current[addr] = v
        if addr != pace:
            continue
        while w < len(web) and web[w][0] <= t:
            current[web[w][1]] = web[w][2]
            w += 1
        clock = f"{t:%H:%M:%S}"
        if (a.since and clock < a.since) or (a.until and clock > a.until):
            continue
        m = mean(steps, t, a.mean) if steps else None
        rows.append([clock] + [current.get(x) for x in addresses] + [m] + [current.get(f) for f in fields])
    if a.last:
        rows = rows[-1:]
    print("\t".join(header))
    for r in rows:
        print("\t".join(fmt(v) for v in r))


if __name__ == "__main__":
    main()
