# The `detail` fence differs between webprobe and the library

`tools/webprobe.py` asks `detail` only of the item types in `VALUE_ITEMS`,
and `CLAUDE.md` justifies that by the controls in the Fachmann tree. The
library's `SettingDetail` says `detail` is a read for every item type, and
`idm-web --show/--watch` send it for any id.

Evidence for the library's view: the 09-20 captures asked `detail` of
`13351 N2_PING`, type `execute`, before the fence existed, and got its detail
back.

One position should go: drop the rationale from `CLAUDE.md` and widen
`VALUE_ITEMS`, or move the fence into the library, which would need the item
type before the id is asked.

Settled on 2026-10-14: the fence stays in `webprobe.py`, and neither side now
claims more than the evidence. `SettingDetail` no longer calls `detail` a read
"for every item type"; it says only `N2_PING` among the controls has been
asked. `CLAUDE.md` and the script give the fence's reason as a control's
`detail` being untested, not known to act. `idm-web` stays unfenced: its
caller names the id. Moving the fence into the library was rejected: `--show`
would need the item's parent menu to learn its type.
