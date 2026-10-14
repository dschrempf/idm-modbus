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
