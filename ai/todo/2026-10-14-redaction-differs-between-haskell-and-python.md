# Redaction differs between Haskell and Python

`IDM.Navigator.Web.redact` claims to strip "as `tools/webprobe.py` does", but:

- Haskell deletes `remoteSessionId` at every depth, Python at the top only;
- Python runs its identifier patterns over the raw JSON text, keys included,
  Haskell over string values only;
- both match a MAC in uppercase hex only.

None of it leaked in the 16 captures checked on 2026-10-14. Pick one
behavior and make the other match.
