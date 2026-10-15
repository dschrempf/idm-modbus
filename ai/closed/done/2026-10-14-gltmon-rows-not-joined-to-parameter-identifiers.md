# `gltmon` rows not joined to parameter identifiers

The 19 rows from `N2_GLTMON` have no `parameter`. 1534 is probably `HSA04`
(`N2_HC_MAX_FLOW_TEMP` in the settings tree), but the page carries no
identifier and the tree no address, and A, C and D all sit at 45, so neither
name nor value can tell the circuits apart (`doc/verification-2026-10-14-gltmon.md`).

Settling it means moving one circuit's setting and reading both sides, which is
a write: Dominik's call. The minimum flow temperature, 1520 to 1526, is the
same question, and its circuits differ already (22, 22, 25). The settings tree
holds the minimum too, so a webapi walk may join that one without writing.
Where the identifier comes from is a design question as well: `transcribe.py`
would need a rule for the join, or a hand-written mapping, which `CLAUDE.md`
rules out for the TSVs.

Done on 2026-10-15. Dominik moved `HSA04`, `HSC04` and `HSA05` at the
controller while both sides were watched, then set all maxima to 40 and all
minima to 22: 1520 to 1540 are `HSA05`, `HSC05`, `HSD05`, `HSA04`, `HSC04`,
`HSD04`, `HSC05` by elimination
(`doc/verification-2026-10-15-flow-temperature.md`). The join lives in a
hand-written input, `data/navigator-2.0-gltmon-parameters.tsv`, which
`transcribe.py` reads, refusing an address that is not a `gltmon` row or an
identifier another row carries, and, given a webapi capture, a join whose tree
value differs from the page's value in that capture.
