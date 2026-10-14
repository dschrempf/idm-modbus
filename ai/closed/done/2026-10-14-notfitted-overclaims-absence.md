# `NotFitted` claims more than the sentinel says

`Reading`'s `NotFitted` says the hardware is not fitted. The evidence says
less: 1050 and 1052 answer `-1.0` while B33/B34 are fitted and the controller
reads them (`doc/verification-2026-09-20.md`, "1050 and 1052 report sensors
that exist as not fitted"). What the sentinel establishes is that the register
holds no value.

A rename (`NoValue`, `Sentinel`) is a public API change and touches the
Readme, `CLAUDE.md` and the docs that name `NotFitted`. Decide together with
`2026-10-14-float-sentinel-swallows-averaged-outdoor-temperature`, which may
change the type anyway.

The `gltmon` rows add two more: 4108 and 4112, `Leistungsbegrenzung Wärmepumpe`
and `Kaskade`, read -1.0 and decode to `NotFitted`, where -1 more likely means
"no limit".

Fixed on 2026-10-14: `NotFitted` is `NoValue`, with the float sentinel note's
`NoValueOr` beside it. 4108 and 4112 have no range, so they decode to
`NoValueOr`, which leaves "no limit" open.
