# Tool fixes found on 2026-11-05

- **`idm-web --show` reports a refused item as `NoAnswer`.** The controller
  answers `setting item [N] is not accessible!` when the level is too low.
  Seen for 4838 and 4831 at Kunde level, and after the level fell back. Parse
  it into a constructor of its own, and print the level.
- **The myiDM ID escapes redaction.** `N2_GLTMON` now prints it as the value
  of 500, and `redact` in `tools/webprobe.py` and `IDM.Navigator.Web` does
  not match it there. The widths capture holds it as the raw bytes of 500,
  and once 500 is a row, so will every scan. The owner is fine with it on
  the laptop, but it must not reach GitHub. On 2026-11-05 no tracked file
  and no commit held it. Git ignores `captures/`, so a leak would come
  through a value of 500 quoted in `doc/`, `test/` or `Changelog.md`.
  `CLAUDE.md`, not `captures/README.md`, says a webapi capture is verbatim
  but for the code and the strings that name the machine. Decided: keep
  that promise. Fix `redact`, and redact
  `captures/navigator-2.0-webapi-20.24-2608-2026-11-05-1624.json`, `…-1636.json`
  and `…-1859.json` in place. Scans and widths stay raw: they record bytes as measured, and
  redacting them would lose the measurement.
- **The level does not hold sixty minutes.** On 20.24-2608 it fell back to
  Kunde 9 min 48 s and 7.5 to 8 min after entry
  (`captures/navigator-2.0-level-20.24-2608-2026-11-05-1636.log`). `CLAUDE.md`, the
  header of `IDM.Navigator.Web.Level` and the help of `idm-web` say sixty
  minutes. A `--watch` that relies on the level needs renewing it sooner;
  check whether anything in the code assumes the hour. Correct the claims
  once `rechecks.md` has found what ends the level. That afternoon may have
  had a remote session, which would end the level too.
