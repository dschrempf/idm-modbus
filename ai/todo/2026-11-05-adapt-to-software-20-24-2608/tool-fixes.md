# Tool fixes found on 2026-11-05

Done: a refused setting is `Refused`, and `idm-web --show` names the level
beside it; `redact` takes the value of 500 off `N2_GLTMON`, and the webapi
captures of 16:36 and 18:59 are redacted in place. That of 16:24 never held
the identifier: the page was refused there.

- **The level does not hold sixty minutes.** On 20.24-2608 it fell back to
  Kunde 9 min 48 s and 7.5 to 8 min after entry
  (`captures/navigator-2.0-level-20.24-2608-2026-11-05-1636.log`). `CLAUDE.md`, the
  header of `IDM.Navigator.Web.Level` and the help of `idm-web` say sixty
  minutes. A `--watch` that relies on the level needs renewing it sooner.
  No code assumes the hour; only those three claims do. Correct them
  once `rechecks.md` has found what ends the level. That afternoon may have
  had a remote session, which would end the level too.
