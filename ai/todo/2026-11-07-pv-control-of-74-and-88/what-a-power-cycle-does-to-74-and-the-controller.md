# What a power cycle does to 74 and the controller is unknown

## The question

An update restarts the controller unannounced, as on 2026-11-05. A consumer
must know what a restart leaves behind, and the software it brings is the
smaller part of that. Not known:

- Whether 74 comes back as the last value written or as 0, and whether a
  surplus written before still starts a charge after.
- Whether Modbus TCP is still switched on, and how long Modbus and the web
  interface take to answer again. A consumer that finds Modbus off after a
  restart is blind, and so is its recording.
- What the settings hold after: the PV menu, `PV008`, the Gebäudeleittechnik
  menu, the clock. The user level should be Kunde.
- Which notices the restart raises, and what the pump does in its first
  minutes.
- Whether the energy counters 1746 to 1762, the runtimes and the graph's
  history survive.
- How a running `idm-dump --watch` and `idm-web --watch` fail, and whether a
  new session of each reads the software as the guard expects.

The restart an update brings may differ from a power cycle; a power cycle is
the one that can be made on purpose. The controller's own reboot control
stays out of the tools (`CLAUDE.md`).

## How we might solve it

Once, by hand at the machine's mains switch, with the compressor off.

1. Before: a webapi capture with `tools/webprobe.py`, at Fachmann level so
   the PV menu is in it, then back to Kunde.
2. With both watches running, write 1.0 to 74, distinct from the 0 a reset
   would give, and switch the machine off for a few minutes, then on.
3. Keep both watches running, restarted where they fail, until the
   controller answers and has settled. Read 74 at once.
4. After: a webapi capture again, and the difference to step 1.
5. Record it in a dated `doc/`, the software read on each side in
   `doc/software-versions.md`, and what a consumer must do after a restart in
   `doc/research.md`.

Planned as the end of the overnight watch of
`controller-behavior-when-glt-values-stop-unknown`, on the morning of
2026-11-07.

Postponed with that watch, which was not run on 2026-11-06.

The user restarted the controller on 2026-11-06 at about 20:40, with -0.5
written to 74 at 20:26:24 and nothing watching; no webapi capture was taken
before. A read of 74 after it answers the first point for that restart:
on 2026-11-07 at 11:56, 74 read 0.0 and 12763 listed it with an empty
`GLT Value` (`doc/verification-2026-11-07-pv-target.md`, "Before"). The
restart did not keep the last value; whether a surplus written before one
still starts a charge after is open.

## 2026-11-07: `System Neustart`, measured

The user restarted the controller from its display at 21:39, with both
watches running and a Fachmann walk on each side
(`doc/verification-2026-11-07-restart.md`). Answered for that restart:

- 74, 88 and 4108 came back 0.0, 0.0 and -1.0, their `GLT Value`s empty;
  4108 had held 3.0, 74 -0.5. So a surplus written before a restart cannot
  start a charge after it; a consumer must write it again.
- Modbus TCP stayed on. Modbus answered 10 s after the connection closed,
  the web 11 s, with sentinels for another 20 to 30 s; both watches made
  their connection anew by themselves, and each read the software again,
  unchanged.
- The settings stood, the PV menu included; the level fell to Kunde; the
  notices were the same; the log records `T20ERR_USER_SHUTDOWN` and
  `T20ERR_NEUSTART_1`, as on 2026-11-06.
- Unexplained: the heat quantities of 2026-11-06 grew by 1.96, 0.38 and
  0.33 with the compressor off, and the graphs' history was laid out anew.

Open: a power cycle at the mains switch, which may differ in all of this;
the restart an update makes, whose log has no `T20ERR_USER_SHUTDOWN`; the
energy counters 1746 to 1762 across a restart.
