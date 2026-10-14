# Modbus client has no timeout and does not match answers to requests

- `withConnection`/`readRegisters` (`src/IDM/Modbus/TCP.hs`) never time out.
  `idm-dump HOST` and `--json` hang for good on a stalled Navigator; only
  `--watch` wraps its reads in `timeout`.
- `readRegisters` ignores the transaction id of the answer. A caller that
  times a read out and keeps the connection reads the late answer as the
  answer to its next request. `idm-dump --watch` disconnects and so is safe;
  the exported API invites the mistake, and `~/nix/config` is about to be such
  a caller.

Design questions: where the patience lives (an argument of `connect`, a field
of `Poll`), whether a timed-out connection is closed inside the library, and
whether a mismatched transaction id is a new `Failure` constructor or a
discard-and-read-on.
