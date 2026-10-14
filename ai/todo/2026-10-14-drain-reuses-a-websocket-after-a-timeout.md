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
