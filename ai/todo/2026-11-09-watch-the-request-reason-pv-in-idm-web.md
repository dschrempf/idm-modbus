# Watch the request reason, PV among it, in `idm-web`

`idm-web --watch` reads settings only, so no run on 74 so far recorded
whether the controller itself registered a PV request. That reason would
settle questions the runs leave open (`doc/pv-control.md`, observation 2):
whether a start was PV's or a heating circuit's, why a start waited 30
minutes after a PV stop, and what a stop was. Wanted soon, before the next
run on 74 or 88 (`pv-control-of-74-and-88`).

## What is known

The reason is a bitmask per mode, decoded by the web interface's
JavaScript; the table is in `doc/pv-control.md`, "The sources": in heating
mode bit 32 is `RD_REQ_PV`, more than one bit reads `RD_REQ_MORE_DEMANDS`,
and hot water and cooling have tables of their own. Two frames may carry
it:

- `system` `overview`, `heatpump.info`, which the JavaScript reads.
  At rest the capture has no `info` in `heatpump`
  (`captures/navigator-10-webapi-20.24-2608-2026-11-06-1148.json`).
- `home` `detail`, whose widgets 10 and 17 carry an `operationMode`, 0 at
  rest (`captures/navigator-10-webapi-20.24-2608-2026-11-07-2140.json`).
  Xerolux/idm-heatpump-api decodes the reason from these widgets, with an
  `info` beside `operationMode` while a request stands, one widget for
  heating and one for hot water.

Neither frame has been captured during a run.

## Steps

1. During a run, a `tools/webprobe.py` capture: which of the two frames
   carries `info`, and whether it agrees with the display. No code needed.
2. In `IDM.Navigator.Web`, a `Query` constructor for the frame that carries
   it (both, if they differ), and a parser to a type: the mode, and the set
   of reasons, a constructor per bit, keeping a bit the table does not name
   rather than dropping it.
3. `idm-web --watch` records it on every round beside the settings, and
   `--show` or `--status` prints it.

## Design, settled on 2026-11-09

- The watch asks for it behind a flag, `idm-web HOST --watch SECONDS
  [--reason] SETTING...`: a field of `Watch`, not a pseudo setting id, so a
  watch without it is unchanged.
- Each frame asked is a line of its own, an entry of a `webapi` capture like
  every other line, its `request` the frame's and its responses verbatim; no
  parsed reason in the capture. `captures/README.md` names the requests.
  `tools/runtable.py` reads `settingId` from every line and would fail on
  one without it; it learns to decode these lines, or to skip them.
- Both reads are `overview` and `detail`, inside the fence of
  `web-backend-and-captures`; `home` and `system` are already asked by
  `tools/webprobe.py`.

Which frame, or both, the flag asks stays with step 1.

A new `Query`, an `idm-web` argument and the capture format go into
`Changelog.md`.
