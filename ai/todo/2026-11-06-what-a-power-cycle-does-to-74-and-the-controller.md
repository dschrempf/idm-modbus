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
