# The patience timeout duplicates `collect`'s deadline

`paced` runs `exchange` and `drain` under `guarded`, whose `timeout` is the
pace's patience (`src/IDM/Navigator/Web/Connection.hs`). Since the reader
thread, `collect` keeps a deadline of its own, the same patience counted from
slightly earlier, so the outer timeout fires only while `send` blocks, or in
the microseconds after the inner one. Firing after `atomically next` has
taken a message from the queue, it drops that message from the request's
list, and so from a capture.

Fix: put the timeout around `send` alone, where it is the only guard, and
let `collect` own the wait. `open` keeps `guarded` as it is.

Fixed on 2026-10-14 as proposed. `send` runs under the patience timeout and
answers `Lost "a send was cut"`; `paced` only turns exceptions into `Lost`
(`caught`), and `open` keeps `guarded`. `send` no longer records its own loss:
`paced` records the reason the request failed with, so every later request
fails with that same reason.
