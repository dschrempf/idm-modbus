# A graph answers the channels of the user level the controller is at

2026-11-10, evening. Two graphs created by hand at Fachmann level to hold
the 17 channels the Fachmann level adds, the refrigerant circuit's, which
no graph held (`doc/verification-2026-11-09-graphs-record-every-channel.md`),
then read at Fachmann and at Kunde level. Times are the controller's clock,
which ran about 30 s ahead of the host's.

A graph's channels are not fixed when it is saved: a read answers those
of them that belong to the level the controller is at when it is read. At
Kunde level a graph of Fachmann channels answers none, and a graph that
mixes the two answers the Kunde ones. A channel put into a graph answers
with its history from before, as at Kunde level.

## What was done

At about 20:50, at Fachmann level, in the web interface, by hand: the
graphs 106 "Temperatures (Fachmann)" and 107 "Pressures and actuators
(Fachmann)" created. A graph takes ten channels at most. 60 M63
`Vorrangventil` went into neither and was added to 107 at 21:42, at
Fachmann level again. Three reads:

- 21:24, a walk at Fachmann level
  (`captures/navigator-10-webapi-20.24-2608-2026-11-10-2124.json`), which
  asks every graph for the last 30 hours (`fromSecs` 108000) and the last
  eight days (691200);
- 21:37, at Kunde level, `detail` of the graphs 2, 106 and 107 for the last
  hour (`captures/navigator-10-webgraph-20.24-2608-2026-11-10-2137.json`);
- 21:42, at Fachmann level, after 60 went into 107: `graph`/`overview` and
  `detail` of 107 over the walk's two spans
  (`captures/navigator-10-webgraph-20.24-2608-2026-11-10-2142.json`).

The two webgraph captures were sent through `tools/webprobe.py`'s
`Session`, which sends only reads.

## What the graphs answered

| Graph                       | Fachmann, 21:24 (107 again at 21:42)           | Kunde, 21:37   |
| --------------------------- | ---------------------------------------------- | -------------- |
| 2 `Kältewerte`              | 23, 91, 145, 146, 188, 10000 to 10004          | 10000 to 10004 |
| 106 Temperatures (Fachmann) | 23, 26, 28, 91, 145, 146, 149, 182, 188        | none           |
| 107 Pressures and actuators | 29, 53, 55, 76, 93, 148, 153, 180; 60 at 21:42 | 53             |

Graph 2 is built in, at user level 2. At Kunde level `graph`/`overview`
leaves it out of its list, but `detail` with its `id` answers it, with the
channels of the Kunde level it holds. 106 and 107 carry user level 0 and
are listed at both levels. 53, the
compressor M1, is a Kunde channel, and the only one 107 answered at Kunde
level. 148 `T23xPRS` is the compressor's speed, in rps.

At Fachmann level every channel of 106 and 107 answered with points from
before the graph was created, back to 2026-11-02 18:21 in the eight-day
span. 60, added at 21:42, answered 5 points in the 30-hour span, the first
at 2026-11-10 09:59:59, and 25 in the eight-day span, from 2026-11-04
10:00:28, each 0 or 1: a state channel, a point per change. It opens with
10003 `N2_HOTWATER`, the hot water stage of graph 2 in the walk of 21:24,
every morning at 10:00, and closes with it, within 17 s until 2026-11-08
and in the same second after. Twice, on 2026-11-04 and 2026-11-05, it
opened about 4.5 minutes before 10003 rose again; on 2026-11-08 from
02:00:00 to 02:05:00 it opened with 10003 at 0. On 2026-11-10 it opened
at 09:59:59 and again at 12:59:59: the hot water window was moved that day
to 13:00, so from 2026-11-11 it opens at 13:00.

## What it settles

- **The Fachmann channels can be read after the fact**, all 17 of them,
  from 106 and 107, but only at Fachmann level: a read of them enters it
  first, `idm-web HOST --enter-fachmann`.
- **A run does not read them from a graph.** A graph is changed by hand
  and answers by the level, so a run reads the refrigerant circuit live
  from its web watch, from 4768 `N2_SENSORS` and 5888 `N2_EVR_OVERVIEW`.

## What it does not settle

- **Whether a graph saved at Kunde level answers a Fachmann channel at
  Fachmann level.** At Kunde level `graph`/`traverse` lists only the 37
  Kunde channels, so the web interface offers no other.
- **What opened M63 on 2026-11-08 from 02:00 to 02:05** with no hot water
  stage.

## Reproducing

Create the graphs in the web interface at Fachmann level, then

    IDM_PIN=... cabal run idm-web -- HOST --enter-fachmann
    IDM_PIN=... tools/webprobe.py HOST > webapi-fachmann.json
    IDM_PIN=... cabal run idm-web -- HOST --leave-fachmann
    IDM_PIN=... tools/webprobe.py HOST > webapi-kunde.json
