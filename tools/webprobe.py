#!/usr/bin/env python3
"""Capture what the Navigator's own web pages are showing, over its websocket.

The controller's web interface is a single-page application; the pages carry no
values, they arrive over a websocket on port 61220 and the local PIN travels in
the URL:

    tools/webprobe.py 192.168.0.200 PIN > captures/navigator-2.0-webapi-2026-09-24-1535.json

Every request this sends is a read: `overview`, `detail` or `traverse`, which is
the whole read side of the protocol -- the controller's own JavaScript names
these three and nothing else. It also has `save` and `execute`; this script must
never learn to send them. Nothing it writes is interpreted either -- the
response goes into the capture verbatim, under the request that provoked it --
so a correction to the register table cannot leave a capture asserting something
else. The PIN stays out of the capture.

Three kinds of request. The pages of the web interface answer with whatever they
display, keyed by their own names. The settings tree answers with the
manufacturer's parameter identifier -- `param`, the manual's `FW030`, `BV002`
-- next to the live value, which is the one place the web interface and the
register table speak the same vocabulary. The tree is walked: `overview` on a
`sub` yields its children, `detail` on an item that holds a value yields the
value. What the tree shows depends on the user level of the controller; this
reads whatever the level it is left at exposes, and never raises it. Above the
user's own level the tree also holds controls -- the relay test, a reboot, a
reset -- so an item is asked only when its type is known to hold a value, and
the menus that exist to act on the machine are not opened.

The third is the graph, and it is the only source here that carries time: the
controller keeps a sampled history of the sensors it plots, and of whether it
was heating, making hot water or defrosting. A register says what is true now
and a page says what has accumulated; the graph is what says when the machine
ran, which is what a rise in a counter has to be attributed to. It reaches back
about a week. `traverse` lists every channel that could be plotted, which is
more than any graph holds -- but reading a channel no graph holds would mean
creating one, and that is a `save`.

Two of the controller's reads are deliberately not sent. `relaytest`/`overview`
opens the relay test, and `authentication`/`overview` asks with `userlevel` 4.

One thing is not verbatim: the settings tree hands out the code that opens the
controller, and the pages name the machine. Those are redacted, in the open.

The Navigator stalls when polled hard, hence one connection for the whole run
and a pause between requests. For scale: the manufacturer's own client polls a
settings page every 500 ms and a status page every 5 s.
"""

import base64
import json
import os
import re
import socket
import sys
import time
from datetime import datetime, timezone

PORT = 61220
# how long to wait for a response, which is also the pause before the next
# request: the Navigator answers in well under a second
REQUEST_INTERVAL_SECONDS = 2.0
# how long to keep listening after the last request
DRAIN_SECONDS = 5.0
# the root of the settings tree
SETTINGS_ROOT = "-1"

# The pages of the web interface, in the order a reader would walk them. A
# heating circuit is addressed by the letter the manual gives it.
REQUESTS = [
    {"controller": "status", "command": "overview"},
    {"controller": "home", "command": "overview"},
    {"controller": "home", "command": "detail"},
    {"controller": "system", "command": "overview"},
    {"controller": "system.freshwater", "command": "detail"},
    {"controller": "system.heatingcircuit", "command": "detail", "data": {"hcId": "A"}},
    {"controller": "system.heatingcircuit", "command": "detail", "data": {"hcId": "C"}},
    {"controller": "system.heatingcircuit", "command": "detail", "data": {"hcId": "D"}},
    {"controller": "system.heatpump.performance", "command": "detail"},
    {"controller": "energyflow", "command": "overview"},
    {"controller": "statistic", "command": "overview"},
    # a statistic is addressed by the `type` its overview gives it, and period
    # 0 answers with every period at once, the cumulative `total` among them
    *(
        {
            "controller": "statistic",
            "command": "detail",
            "data": {
                "statisticType": statistic,
                "periodType": 0,
                "statisticSubType": None,
            },
        }
        for statistic in (6, 0, 3)  # heat quantities, runtimes, energy management
    ),
    {"controller": "notification", "command": "overview"},
    {"controller": "weather", "command": "detail"},
]

READ_COMMANDS = ("overview", "detail", "traverse")
# reads all the same, and none of this script's business
FORBIDDEN_CONTROLLERS = ("relaytest", "authentication")

# The settings items that hold a value. Every other type is a control -- a
# button, the relay test, a recovery -- or unknown, and is left unasked: at
# Fachmann level the tree carries `action`, `execute`, `relaytest`,
# `treeview`, `vparam` and `frwaparam` items.
VALUE_ITEMS = ("iparam", "hparam", "info")
# menus whose purpose is to act on the machine, not to show it
CLOSED_MENUS = ("N2_RELAY_TEST", "N2_RESET_DATA")

# The spans of the graph, as the web interface's own tabs ask for them:
# `fromSecs` reaches back from now, `stepSecs` 0 lets the controller choose the
# resolution. Eight days is the furthest the interface looks.
GRAPH_SPANS = (
    {"fromSecs": 60 * 60 * 30, "stepSecs": 0},
    {"fromSecs": 60 * 60 * 24 * 8, "stepSecs": 15},
)

REDACTED = "<redacted>"
# The capture is otherwise verbatim. These carry the code that opens the
# controller, or name the machine, and are evidence for nothing here; the
# marker stays so a reader can tell a removal from an absence. The code appears
# twice: as `param` on its own detail, and under its translation key in the
# menu that lists it, where it carries no `param`.
REDACTED_PARAMS = {"SSYSLPIN"}
REDACTED_NAMES = {"N2_NETWORK_LOCAL_CODE"}
REDACTED_VALUE_KEYS = ("value", "displayValue")
REDACTED_KEYS = {"myidmInfo"}
IDENTIFIERS = [
    re.compile(r"m\d+@[0-9a-f]+"),  # the myIDM identifier
    re.compile(r"(?:[0-9A-F]{2}:){5}[0-9A-F]{2}"),  # the MAC address
]


def redact(node):
    """Strip the machine's identity out of a response, in place."""
    if isinstance(node, dict):
        if node.get("param") in REDACTED_PARAMS or node.get("name") in REDACTED_NAMES:
            for key in REDACTED_VALUE_KEYS:
                if key in node:
                    node[key] = REDACTED
        for key in list(node):
            if key in REDACTED_KEYS:
                node[key] = REDACTED
            else:
                redact(node[key])
    elif isinstance(node, list):
        for item in node:
            redact(item)
    return node


def redact_text(text):
    for identifier in IDENTIFIERS:
        text = identifier.sub(REDACTED, text)
    return text


# A websocket client small enough to read, so that this file keeps the one
# dependency transcribe.py has: a Python interpreter.
class WebSocket:
    def __init__(self, host, port, path, timeout=10.0):
        self.sock = socket.create_connection((host, port), timeout=timeout)
        self.sock.settimeout(timeout)
        self.buffer = b""
        key = base64.b64encode(os.urandom(16)).decode()
        handshake = (
            f"GET {path} HTTP/1.1\r\n"
            f"Host: {host}:{port}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n"
            "\r\n"
        )
        self.sock.sendall(handshake.encode())
        while b"\r\n\r\n" not in self.buffer:
            self._fill()
        head, self.buffer = self.buffer.split(b"\r\n\r\n", 1)
        status = head.split(b"\r\n", 1)[0].decode()
        if "101" not in status:
            raise RuntimeError(f"websocket handshake refused: {status}")

    def _fill(self):
        chunk = self.sock.recv(65536)
        if not chunk:
            raise ConnectionError("connection closed by the controller")
        self.buffer += chunk

    def _take(self, n):
        while len(self.buffer) < n:
            self._fill()
        out, self.buffer = self.buffer[:n], self.buffer[n:]
        return out

    def send_text(self, text):
        payload = text.encode()
        header = bytearray([0x81])
        length = len(payload)
        if length < 126:
            header.append(0x80 | length)
        elif length < 1 << 16:
            header.append(0x80 | 126)
            header += length.to_bytes(2, "big")
        else:
            header.append(0x80 | 127)
            header += length.to_bytes(8, "big")
        mask = os.urandom(4)
        header += mask
        masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        self.sock.sendall(bytes(header) + masked)

    def _frame(self):
        first, second = self._take(2)
        fin, opcode = first & 0x80, first & 0x0F
        length = second & 0x7F
        if length == 126:
            length = int.from_bytes(self._take(2), "big")
        elif length == 127:
            length = int.from_bytes(self._take(8), "big")
        # a server frame is never masked
        return fin, opcode, self._take(length)

    def recv_text(self, deadline):
        """The next text message, or None once the deadline passes."""
        message = b""
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return None
            self.sock.settimeout(remaining)
            try:
                fin, opcode, payload = self._frame()
            except TimeoutError:
                return None
            if opcode == 0x8:  # close
                raise ConnectionError("the controller closed the connection")
            if opcode == 0x9:  # ping
                self.sock.sendall(bytes([0x8A, 0x80]) + os.urandom(4))
                continue
            if opcode == 0xA:  # pong
                continue
            message += payload
            if fin:
                return message.decode()

    def close(self):
        try:
            self.sock.sendall(bytes([0x88, 0x80]) + os.urandom(4))
        except OSError:
            pass
        self.sock.close()


def now():
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


class Session:
    """One connection, and the capture it fills."""

    def __init__(self, ws):
        self.ws = ws
        self.capture = []

    def ask(self, request):
        if request["command"] not in READ_COMMANDS:
            raise SystemExit(f"refusing to send a non-read command: {request}")
        if request["controller"] in FORBIDDEN_CONTROLLERS:
            raise SystemExit(f"refusing to send: {request}")
        self.ws.send_text(json.dumps(request))
        sent = now()
        responses = self.drain(REQUEST_INTERVAL_SECONDS)
        self.capture.append(
            {"request": request, "captured": sent, "responses": responses}
        )
        return responses

    def drain(self, seconds):
        messages = []
        deadline = time.monotonic() + seconds
        while (text := self.ws.recv_text(deadline)) is not None:
            message = json.loads(redact_text(text))
            message.pop("remoteSessionId", None)
            messages.append(redact(message))
        return messages


def find_all(node, key):
    """Every value stored under `key`, however deep."""
    if isinstance(node, dict):
        if key in node:
            yield node[key]
        for value in node.values():
            yield from find_all(value, key)
    elif isinstance(node, list):
        for item in node:
            yield from find_all(item, key)


def walk_graphs(session):
    """Every graph the controller offers, over every span the interface plots."""
    session.ask({"controller": "graph", "command": "overview"})
    # the channels that could be plotted, whether or not a graph uses them
    session.ask({"controller": "graph", "command": "traverse"})
    ids = {
        graph["id"]
        for graphs in find_all(session.capture, "graphs")
        for graph in graphs
    }
    for graph_id in sorted(ids):
        for span in GRAPH_SPANS:
            session.ask(
                {
                    "controller": "graph",
                    "command": "detail",
                    "data": {"id": graph_id, **span},
                }
            )


def walk_settings(session, node_id):
    """Depth-first over the settings tree, reading every value it exposes."""
    responses = session.ask(
        {"controller": "setting", "command": "overview", "data": {"settingId": node_id}}
    )
    items = []
    for message in responses:
        items += (message.get("setting") or {}).get("items") or []
    for item in items:
        if item.get("type") == "sub":
            if item.get("name") not in CLOSED_MENUS:
                walk_settings(session, item["id"])
        elif item.get("type") in VALUE_ITEMS:
            session.ask(
                {
                    "controller": "setting",
                    "command": "detail",
                    "data": {"settingId": item["id"]},
                }
            )


def main(host, pin):
    ws = WebSocket(host, PORT, f"/?auth_code={pin}")
    session = Session(ws)
    try:
        hello = ws.recv_text(time.monotonic() + 10.0)
        if hello is None or not json.loads(hello).get("authorized"):
            raise SystemExit(f"the controller did not authorize us: {hello}")
        for request in REQUESTS:
            session.ask(request)
        walk_graphs(session)
        walk_settings(session, SETTINGS_ROOT)
        for message in session.drain(DRAIN_SECONDS):
            session.capture.append(
                {"request": None, "captured": now(), "responses": [message]}
            )
    finally:
        ws.close()
    json.dump(session.capture, sys.stdout, indent=1, ensure_ascii=False)
    sys.stdout.write("\n")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(f"usage: {sys.argv[0]} HOST PIN")
    main(sys.argv[1], sys.argv[2])
