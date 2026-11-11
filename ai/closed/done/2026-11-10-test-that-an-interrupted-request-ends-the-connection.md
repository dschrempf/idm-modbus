# Test that an interrupted request ends the connection

A handoff, from the review of `idm-drive` (2026-11-10, its finding 3).

## What is untested

`transact` in `lib/core/IDM/Modbus/TCP/Internal.hs` runs `exchange` under
`onException`: an exception that arrives before the answer was read, a
signal's `throwTo` among them, sets `connectionEnded` to `Just Abandoned`,
disconnects, and goes on (be28714). Every later request on the connection
then fails `Unsent Abandoned`, rather than reading the stale answer as its
own.

The finals of `IDM.Navigator.Drive` rely on it: a final whose write throws
counts the session as lost and goes again on a new one (0c015c7). Their
checks run against the fake controller, above the socket, so nothing checks
`transact` itself. The review's other fixes are all checked.

## The test, as decided

A listener on the loopback interface that accepts and never answers, the
first socket in the test suite. Decided by the user on 2026-11-10: it needs
no heat pump, and it covers a defect the finals depend on.

Everything needed is exported already: `connect`, `readRegisters`,
`disconnect`, `Patience`, `Ending (..)`, `Failure (..)`.

1. Open a listening socket on `127.0.0.1`, port 0, and read the port it
   got. Accept in a thread, and hold the accepted socket without writing.
2. `connect` to it, with a patience long enough that the timeout cannot
   fire first, e.g. 10 s.
3. Start `readRegisters` in a thread. Once the request is on the wire
   (the accepting side has received its 12 bytes), `throwTo` that thread
   an exception of the test's own.
4. Check: the thread ended with that exception, and a second
   `readRegisters` on the same connection returns `Left (Unsent Abandoned)`
   at once, sending nothing (the accepting side receives no more bytes).
5. A control case on the same listener: an answer that never comes, with a
   short patience, still ends `Ended NoAnswer`, not `Abandoned`. This keeps
   `timeout`'s own exception, which `timeout` catches inside `exchange`,
   from being taken for an interruption.

Close both sockets in `finally`, and put a time limit on the whole check, so
that a defect cannot hang `cabal test`.

## What else changes

- `idm-modbus.cabal`: the test suite gains `network`.
- `CLAUDE.md` says the test suite "needs no heat pump: everything is
  decoded from literal byte strings". That stays true of the heat pump; the
  sentence gets a clause for the loopback check.
- The checks are `(name, Bool)` pairs in `checks`, a pure list. This one
  is IO, as `driveChecks` and `scheduleFiles` in `test/Main.hs` are; it
  joins them in `main`.
- No Changelog entry: be28714 has one.

## Outcome

Done on 2026-11-11 (8043d61), as decided: `connectionChecks` in
`test/Main.hs`, two checks against a loopback listener under a 20 s limit,
cases 1 to 4 in one and the control case 5 in the other. With the
`onException` of be28714 removed, the first fails and the second passes.
`CLAUDE.md` says the test suite's connection checks use the loopback.
