# The web backend: its two sources, the probe's fence, and the user level

Read before changing `tools/webprobe.py`, `idm-web` or the
`IDM.Navigator.Web` modules, or before reading a web capture or the
hand-written web TSV as evidence.

## Two web sources

`data/navigator-10-web-*.tsv` is written by hand: what the controller's own
web pages showed, at the minute they were read. It carries no addresses, so
the mapping it tests is stated only in the register table; the join is on the
sensor designator a register name already holds.

`captures/navigator-10-webapi-*.json` is what the controller's web interface
answered, captured rather than transcribed. It is the stronger witness of the
two, because the settings it walks name their value with the manufacturer's
own parameter identifier, the `FW030` and `BV002` of the parameter list, so
the join to the register table is on the identifier the table already
carries. It is also the only source that carries time: the graph it captures
says when the machine ran, which is what a rise in a counter has to be
attributed to. The controller records every channel `graph`/`traverse`
lists whether or not a graph holds it, about eight days back; a graph only
chooses what a read returns, and creating one is a `save`, done by hand in
the web interface. Since 2026-11-09 seven graphs hold all 37 channels of the
Kunde level; the 17 more of the Fachmann level, the refrigerant circuit's,
are in 106 and 107 since 2026-11-10. B33, the flow, is no channel at either
level (`doc/verification-2026-11-09-graphs-record-every-channel.md`). A graph
answers those of its channels that belong to the level the controller is at
when it is read: at Kunde level 106 answers none and 107 only 53, and the
built-in graph 2, of level 2, is left out of `graph`/`overview` but answers
`detail` with its Kunde channels
(`doc/verification-2026-11-10-a-graph-answers-the-channels-of-the-current-level.md`). The
web interface's JavaScript (`main-7UP7UE6I.js`, served by the controller,
read 2026-11-10) asks history only as `graph`/`detail {id, fromSecs,
toSecs, stepSecs}`, of a saved graph, never of a list of channels: a channel
no graph holds has no read of its history. A run reads the refrigerant
circuit live instead, from the settings pages 4768 `N2_SENSORS` and 5888
`N2_EVR_OVERVIEW` in its web watch. The capture is verbatim but for the code that opens the
controller and the strings that name the machine, which are replaced by a
visible marker.

## What `tools/webprobe.py` may send

It writes the capture over the websocket the web interface itself uses,
sending only the three read commands the controller's own JavaScript names,
`overview`, `detail` and `traverse`. The protocol's `save` and `execute` must
stay out of that script, and so must the two reads that open the relay test
and ask for user level 4.

What the capture contains depends on the user level the controller is left
at; the script never raises it. At Fachmann level the settings tree also
holds controls — the relay test, a reboot, resets. The web interface acts only
on a `save` or `execute`, but of the controls only `N2_PING` has been asked
its `detail`, so the walk asks `detail` only of the item types in
`VALUE_ITEMS` and never opens the menus in `CLOSED_MENUS`; a new item type
stays unasked until someone has seen what its `detail` does. `idm-web --show`
asks whatever id it is given.

## The user level

`IDM.Navigator.Web.Level` enters the Fachmann level with a `setting`/`save` of
item 12503, a code spelled from the controller's clock, as a number, from
Kunde only, and leaves it by acknowledging the `N2_USERLEVELACTIVE` notice.
Both work on the machine, and the display switches with them. The level is
the controller's, not the connection's: it holds until it is left or the
controller ends it, sixty minutes from the entry, however often it was
read meanwhile, on both softwares
(`doc/verification-2026-11-09-heating-run-as-on-1574.md`). An entry sent
seconds after a leave answered success and left the level at Kunde; sent
again 20 s later it took (2026-11-10,
`captures/navigator-10-level-20.24-2608-2026-11-10-2056.log`). The frost
protection wizard's code page is not a way in: it answers "wizard is not
available!" unless a wizard runs.

Xerolux/idm-heatpump-hass, `docs/wiki/Navigator-Protocol-Analysis.md` in
`community/`, says the opposite: that a code spelled from the clock opens
the display's service menu only, and the websocket's technician level needs
a per-installation code from iDM's service partners. It tried another route,
`authentication/save` with `{"userlevel": 4, "code": …}`, which the
controller's JavaScript sends and which answers `{"authorized": false}` to a
wrong code. On 12503 it reports a "wrong" entry that answered with notice
20005 `N2_USERLEVELACTIVE` — "Fachmanncode aktiv" in the web interface's
translations, the notice an entry raises here: most likely an entry that
worked, read as a failure. Two of its reports bear on `Level`
and are untested here: repeated wrong entries block the code input for a
while (`N2_USERLEVELINPUTBLOCKED`), so a retry of the entry must stay
bounded; and several websocket sessions at once answered without
interfering.
