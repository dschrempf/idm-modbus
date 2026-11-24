# Modbus TCP closes a connection idle for 12.25 s; the websocket stays open at 60 s

2026-11-24, evening, on 20.24-2608. A watch every 20 s had lost every
other round, so the idle time after which the controller ends a connection
was measured, on both channels. Times are the host's.

The controller closes a Modbus TCP connection, with a FIN, 12.25 to 12.30 s
after its last answer, and a request after that fails. A connection in use
stays open for hours. The websocket of the web backend was not closed at
60 s idle.

## What was done

**The watch that lost rounds.** `idm-dump --watch 20` of eight registers
read all eight at 21:29:25. Its next round, at 21:29:44.67, 18.3 s after
the last read, found the connection closed: the first read failed with
`connection closed`, and the seven after it read as errors with no
session. The round after that opened a new session and read all eight,
and so on for two minutes
(`captures/navigator-10-watch-20.24-2608-2026-11-24-2129.jsonl`, and its
`.stderr`).

**Watches of one register**, 1008, at three periods, one after another
and with no other client:

| Period | Idle before a read | Rounds | Lost                                           | Capture                                         |
| ------ | ------------------ | ------ | ---------------------------------------------- | ----------------------------------------------- |
| 14 s   | 13.4 s             | 4      | the second and the fourth, `connection closed` | `navigator-10-watch-20.24-2608-2026-11-24-2138` |
| 12 s   | 11.9 s             | 4      | none                                           | `navigator-10-watch-20.24-2608-2026-11-24-2139` |
| 13 s   | 12.5 s             | 5      | the second and the fourth, `connection closed` | `navigator-10-watch-20.24-2608-2026-11-24-2140` |

**A raw socket**, four times from 21:41 to 21:42: connect to port 502,
read 1008 with function code 3, then wait without sending anything, and
time how the connection ends:

    s = socket.create_connection((HOST, 502), timeout=5)
    s.sendall(struct.pack(">HHHBBHH", 1, 0, 6, 1, 3, 1008, 2))
    s.recv(256)                 # the answer; t0 = time.monotonic()
    s.settimeout(120)
    s.recv(256)                 # b"" on a FIN; how long after t0

Each time the controller closed it with a FIN, `recv` returning empty,
after 12.295, 12.247, 12.247 and 12.272 s.

**The web backend**, `idm-web --watch` of 4768 `N2_SENSORS` at Kunde
level, at 20 s for five rounds and at 60 s for four
(`captures/navigator-10-webwatch-20.24-2608-2026-11-24-2142.jsonl`, `-2144`).
The client sends nothing between rounds, no websocket ping either.

## What the machine did

Modbus TCP: a request 12.5 s or more after the last answer fails, one
11.9 s after succeeds. The raw socket puts the edge at 12.25 to 12.30 s,
measured from the answer; the controller closes the connection then, on
its own, rather than refusing the next request.

The web backend answered every round of both watches, with no error, on
the one connection each opened.

## What it settles

- **The idle timeout of Modbus TCP is 12.25 s**, and it is a timeout of
  idleness, not of a connection's lifetime: a watch every 10 s held one
  connection for 1 h 38 min, its longest silence 7.5 s
  (`captures/navigator-10-watch-20.24-2608-2026-11-09-1450.jsonl`, where a
  new connection would have followed a line with status `error`, and none
  is).
- **Every watch and drive before this one ran below it**, at 5 or 10 s, so
  none lost a round to it. The errors in two of them have other causes: in
  `captures/navigator-10-watch-20.24-2608-2026-11-07-2120.jsonl` the
  restart, which reset the connection 8.4 s after the last read
  ([2026-11-07-restart](2026-11-07-restart.md)); in
  `captures/navigator-10-watch-20.24-1574-2026-10-15-1418.jsonl` a read
  that got no answer 4.4 s after the last one, followed by two rounds that
  got none either.
- **The websocket has no such timeout below 60 s.**

## After the fix

A round now retires a session idle past `pollIdleLimitMicroseconds` and
opens another ([modbus.md](../modbus.md#an-idle-connection)). The same
watches read every round: at 13 s, 1008 five times
(`captures/navigator-10-watch-20.24-2608-2026-11-24-2216.jsonl`); at 20 s,
the eight registers of the watch that lost rounds, four times
(`-2217`); and at 60 s, 1008 and 1012 three times (`-2218`).

## What it does not settle

- **Whether the timeout is a setting** of the controller, or differs by
  software: it was measured on 20.24-2608 only, and no capture of
  20.24-1574 was idle long enough to show it.
- **Whether the websocket closes after a longer silence** than 60 s.
