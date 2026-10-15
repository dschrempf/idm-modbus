# Charge pump signal 1074 unchecked at rest

1074, `Ladepumpe Wärmesenke Steuersignal`, read 93 to 97 while the machine
heated on 2026-10-15, and `ffff` at rest on 2026-10-14; 1104, `Status
Ladepumpe (M73)`, read `ffff` in both (`doc/verification-2026-10-15-heat-sink.md`).
The table reads 1074 as `one-register`, so `ffff` is 65535. If the
`Analogausgänge` page prints M73's signal as -1 % beside a read of 1074 at
`ffff`, 1074 is the signed pump signal of 1104 to 1109 and could decode to
`Drive`; that needs a datatype the page does not state, so it is a decision on
how a `gltmon` row may gain one.
