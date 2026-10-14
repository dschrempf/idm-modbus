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

Fixed on 2026-10-14. The patience is an argument of `connect` and
`withConnection`, `Patience`, kept in the `Connection`; `Poll` paces only. A
read that leaves the stream out of step or gone — no answer in time, a
transaction id not its own, a malformed frame, the device closing, a socket
error — closes the socket inside the library, and every later read fails
unsent. `Failure` tells the two apart, `Ended` and `Unsent`, each with an
`Ending`; a mismatched id is the `Ending` `UnexpectedTransaction`, not a
discard and read on, as session 1 decided for the websocket. `readRegisters`
no longer throws for the socket. `idm-dump --watch` drops its own timeouts,
and `probe` skips the pause after an unsent read. The socket path was checked
against a loopback server, not against the machine.
