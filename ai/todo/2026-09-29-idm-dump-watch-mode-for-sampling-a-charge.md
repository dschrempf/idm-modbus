# idm-dump watch mode for sampling a charge

Next task, decided 2026-09-29: `idm-dump` learns to read a chosen set of
addresses in a loop and record each round with its time, instead of a
throwaway script. First use: the legionella ceiling
(`2026-09-24-legionella-charge-stops-short-of-its-target.md`) needs B45 (1066),
B41 (1012), B48 (1014), `Status Verdichter 1` (1100) and the powers 1790, 4122,
4126 every ~10 s through a charge to ≥ 60 °C. The web graph cannot stand in:
its sensor history is thinned to ~50 min. It also serves the Wärmemenge
question, integrating 1790 against the rise of 1754 over a charge.

At the client's 150 ms pacing, seven registers take about a second a round, so
the pacing, not the protocol, bounds the rate.

To raise with Dominik before code:

- CLI shape: a `--watch` mode next to `Report` and `Capture`, how addresses
  are named (numbers, or names from the table), the interval, and how a run
  ends.
- Output: a time series format for `captures/`, e.g. JSON lines with one
  object per round, keeping the capture rule — raw bytes and the uninterpreted
  number only, no transcribed data — so a table correction cannot contradict
  it. Name pattern for `captures/README.md`.
- Time: wall clock per round or per read, and in which zone; the webapi graph
  already showed what an unstated epoch costs.
- A failed read mid-run: recorded and continued, or the run ends.
