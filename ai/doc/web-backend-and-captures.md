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
attributed to. The capture is verbatim but for the code that opens the
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
controller ends it. On 20.24-1574 that was sixty minutes from the entry,
however often it was read meanwhile; on 20.24-2608 it was after 8 minutes,
after 10, and not within 73, and what ends it is unknown
(`fachmann-level-duration-and-renewal`). The frost protection wizard's code page is not a way in: it
answers "wizard is not available!" unless a wizard runs.

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
