# The house's address remains in git history

On 2026-10-14 the heat pump's LAN address was replaced by `HOST` in the nine
tracked places that named it (Readme, four docs, `tools/webprobe.py`). The
repository is public and the address stays in the history. Rewriting it is a
force push; a private LAN address may not be worth one.

Dropped on 2026-10-15: no rewrite. The address is a private LAN address, out
of reach from outside the house, and a rewrite would change every hash and
break existing clones without recalling the copies already fetched.
