# `drain` reuses a websocket session after a timeout

`IDM.Navigator.Web.Connection` documents that a session is not to be used
again after a timeout, because a frame may have been cut in half. `drain`
always ends by timing out `WS.receiveData`, and `Level.change` then sends
`askStatus` on the same session. A frame arriving at the deadline can
desynchronize the stream.

`tools/webprobe.py` had the same defect and was fixed on 2026-10-14 by
consuming a frame from its buffer only once it is whole. The Haskell side
needs a design choice: a reader thread feeding a queue, so no timeout ever
interrupts `receiveData`; or a fresh session after each `drain`.

Fixed on 2026-10-14 with a reader thread. websockets 0.13's `Stream.parse`
writes the bytes left over back to its buffer only once a frame is whole, so a
timeout mid-frame lost the chunks it had read. `open` now starts a thread that
receives into a `TQueue`, `collect` waits on the queue, and only `Lost` ends a
session; a send cut by the timeout counts as lost. A fake controller that sends
an answer in two halves 1.5 s apart, around a patience of 1 s, gave `NoAnswer`
and then `Lost "ParseException …"` on the old code, and `NoAnswer` and then the
late answer followed by the next one on the new.

Keeping a session after `NoAnswer` showed a second defect: `answerIn` matched
on the key alone, so the late answer to one setting was taken for the next
setting's, and every later line of a watch was off by one. A setting's answer
must now name its `id`; every one in the captures does, `redirectId` or not.
A `graphDetail` names nothing and stays ambiguous. With that, `idm-web --watch`
closes its session after `Lost` only, and the fake controller showed the late
answer to setting 1 in the line of setting 2, before 2's own, and setting 3
clean. The `not connected` after 5888 in
`doc/verification-2026-10-01-charge.md` would now be an answer.
