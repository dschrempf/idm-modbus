#!/usr/bin/env python3
"""Write a schedule of values to 74, the PV surplus, to see what the controller does.

A test driver, not a strategy: the schedule is fixed before the run, and the
only thing read from the machine is when the compressor starts and stops and
what it draws, so a run can be repeated and its result stated. It writes
through `idm-write`, so every guard of the library holds, and reads 1100 and
4122 from the file of a running `idm-dump --watch`, so the controller has no
third client:

    cabal run idm-dump -- HOST --watch 10 74 1008 1090 1091 1100 1074 4122 1004 1098 > WATCH
    tools/drive74.py HOST WATCH --final -0.5 1.7/60/ein+210 1.0-4122/20/ein+2700 -0.5/60/aus \
      > captures/navigator-2.0-write-SOFTWARE-YYYY-MM-DD-HHMM.log

A phase is VALUE/PERIOD/UNTIL. VALUE is a number in kW, or T-4122, the
number T minus the last 4122 of the watch, which is what a grid meter reads
with T kW of PV and the pump the only load. PERIOD is the seconds between
writes; a phase writes when it begins. UNTIL ends the phase:

    ein          once 1100 reads Ein
    ein+SECONDS  that long after 1100 first read Ein
    +SECONDS     that long after the phase began
    aus          once 1100 reads Aus

Once 1100 has read Ein, 1100 reading Aus ends the schedule, whatever phase
runs: a run that stops is over. The schedule also ends when its last phase
does, on SIGTERM and on SIGINT. In every case the --final value is written
once before exit, so the driver never leaves behind a value it was writing.
The first line of the log names the driver's pid, the one to send SIGTERM:
a pid taken from `$!` may be a shell's.
"""

import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time
from datetime import datetime

# The oldest 4122 a T-4122 phase uses; older, it skips the write.
FRESH_SECONDS = 25

# Seconds between reads of the watch file.
POLL_SECONDS = 1


class Stop(Exception):
    """A signal asked the driver to end."""


def log(line):
    print(f"{datetime.now():%H:%M:%S} {line}", flush=True)


def parse_value(text):
    m = re.fullmatch(r"(-?[\d.]+)-4122", text)
    if m:
        return ("meter", float(m.group(1)))
    return ("fixed", float(text))


def parse_until(text):
    if text in ("ein", "aus"):
        return (text, None)
    m = re.fullmatch(r"ein\+(\d+)", text)
    if m:
        return ("ein+", int(m.group(1)))
    m = re.fullmatch(r"\+(\d+)", text)
    if m:
        return ("+", int(m.group(1)))
    raise ValueError(text)


def parse_phase(text):
    try:
        value, period, until = text.split("/")
        return {"text": text, "value": parse_value(value), "period": int(period), "until": parse_until(until)}
    except ValueError:
        sys.exit(f"{text}: not a phase VALUE/PERIOD/UNTIL; see the docstring")


class Watch:
    """The last 1100 and 4122 an `idm-dump --watch` file holds, read as it grows."""

    def __init__(self, path):
        self.file = open(path)
        self.partial = ""
        self.last = {}

    def poll(self):
        self.partial += self.file.read()
        *lines, self.partial = self.partial.split("\n")
        for line in lines:
            try:
                r = json.loads(line)
            except ValueError:
                continue
            if r.get("status") == "ok" and r["address"] in (1100, 4122):
                self.last[r["address"]] = (r["value"], datetime.fromisoformat(r["time"]))

    def running(self):
        return self.last.get(1100, (None,))[0] == 1

    def draw(self):
        """4122 if it is fresh, else None."""
        if 4122 not in self.last:
            return None
        value, at = self.last[4122]
        age = (datetime.now(at.tzinfo) - at).total_seconds()
        return value if age <= FRESH_SECONDS else None


def write(writer, host, value):
    p = subprocess.run([writer, host, "74", f"{value:.2f}"], capture_output=True, text=True)
    out = (p.stdout + p.stderr).strip().replace("\n", " | ")
    log(f"{out} [exit {p.returncode}]")


def phase_over(phase, watch, ein, began):
    kind, n = phase["until"]
    now = time.time()
    if kind == "ein":
        return ein is not None
    if kind == "ein+":
        return ein is not None and now - ein >= n
    if kind == "+":
        return now - began >= n
    return not watch.running()


def run(host, watch, writer, phases):
    ein = None
    for phase in phases:
        log(f"phase {phase['text']}")
        began = time.time()
        last = None
        while True:
            watch.poll()
            if ein is None and watch.running():
                ein = time.time()
                log("1100 Ein")
            elif ein is not None and not watch.running():
                log("1100 Aus")
                return
            if phase_over(phase, watch, ein, began):
                break
            if last is None or time.time() - last >= phase["period"]:
                kind, x = phase["value"]
                if kind == "fixed":
                    write(writer, host, x)
                else:
                    draw = watch.draw()
                    if draw is None:
                        log("4122 is not fresh; no write")
                    else:
                        log(f"4122 {draw:.2f}")
                        write(writer, host, round(x - draw, 2))
                last = time.time()
            time.sleep(POLL_SECONDS)


def main(argv):
    try:
        host, watch_path, flag, final, *phase_args = argv[1:]
        if flag != "--final" or not phase_args:
            raise ValueError
        final = float(final)
    except ValueError:
        sys.exit(f"usage: {argv[0]} HOST WATCH --final VALUE PHASE...")
    phases = [parse_phase(p) for p in phase_args]
    writer = ""
    if shutil.which("cabal"):
        writer = subprocess.run(["cabal", "list-bin", "exe:idm-write"], capture_output=True, text=True).stdout.strip()
    if not os.access(writer, os.X_OK):
        sys.exit("no idm-write: run this inside `nix develop` after `cabal build`")

    def stop(signum, frame):
        raise Stop(signal.Signals(signum).name)

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    log(f"pid {os.getpid()}; final {final}")
    try:
        run(host, Watch(watch_path), writer, phases)
    except Stop as e:
        log(f"stopped by {e}")
    finally:
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        log("final")
        write(writer, host, final)
        log("done")


if __name__ == "__main__":
    main(sys.argv)
