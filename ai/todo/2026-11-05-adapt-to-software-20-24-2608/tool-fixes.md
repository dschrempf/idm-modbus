# Tool fixes found on 2026-11-05

- **`idm-web --show` reports a refused item as `NoAnswer`.** The controller
  answers `setting item [N] is not accessible!` when the level is too low.
  Seen for 4838 and 4831 at Kunde level, and after the level fell back. Parse
  it into a constructor of its own, and print the level.
- **The myiDM ID escapes redaction.** `N2_GLTMON` now prints it as the value
  of 500, and `redact` in `tools/webprobe.py` and `IDM.Navigator.Web` does
  not match it there. It is also in the widths capture, as the raw bytes of
  500. Fix `redact`, then redact
  `captures/navigator-2.0-webapi-2026-11-05-1624.json`, `…-1636.json` and
  `…-widths-2026-11-05-1639.json` in place. Git ignores them, but
  `captures/README.md` promises the redaction. Then decide 500 for the scan
  (`table-rebuild.md`).
- **The level does not hold sixty minutes.** On 20.24-2608 it fell back to
  Kunde 9 min 48 s and 7.5 to 8 min after entry
  (`captures/navigator-2.0-level-2026-11-05-1636.log`). `CLAUDE.md`, the
  header of `IDM.Navigator.Web.Level` and the help of `idm-web` say sixty
  minutes. A `--watch` that relies on the level needs renewing it sooner;
  check whether anything in the code assumes the hour. Correct the claims
  once `rechecks.md` has found what ends the level.
