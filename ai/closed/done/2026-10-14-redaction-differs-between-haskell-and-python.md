# Redaction differs between Haskell and Python

`IDM.Navigator.Web.redact` claims to strip "as `tools/webprobe.py` does", but:

- Haskell deletes `remoteSessionId` at every depth, Python at the top only;
- Python runs its identifier patterns over the raw JSON text, keys included,
  Haskell over string values only;
- both match a MAC in uppercase hex only.

None of it leaked in the 16 captures checked on 2026-10-14. Pick one
behavior and make the other match.

Fixed on 2026-10-14 by taking the stricter rule of each: both drop
`remoteSessionId` at any depth, match keys and values after decoding the JSON
(Python matched raw text, which a `@` escape could evade), and take hex
in either case, a MAC joined by `:` or `-`. Re-redacting every capture under
the new rules changed nothing.
