# Beyond this update

What would have made this update cheaper, and makes the next one so.
Recording the version in every capture is now part of `version-guard.md`.

- **The consumers.** `~/nix/config` knows only the pump's address, from a
  hosts entry and the bridge port the pump hangs off. It runs nothing
  against the pump, so it has nothing to change. `idm-manager` exists only as
  notes so far. On 2026-11-05 its notes gained three things: it reads the
  version through the guard, a refusal is an outcome it handles, and it
  records the version with its inputs. Once the guard lands, check those
  notes against it.
- **A newer parameter list.** 812170 revision 12 is public: 40 pages, built
  2025-09-09. It documents software 20.23-515, between revision 10's
  20.21-101 and this machine's 20.24 builds. A LoxWiki comment of 2026-10-09
  attaches it as `Montageanleitung_Modbus_TCP_Navigator_2_0.2025.pdf`, md5
  `21ac38ed0982d565f96550c249d6a3fa`, on the page "IDM-IPump mit
  Loxone-Modbus-TCP (Navigator 2.0)". It lacks the new `N2_GLTMON`
  addresses, and its 4112 is still the `FLOAT`
  `Leistungsbegrenzung Kaskade`. The table moves to it
  (`manual-rev-12.md`). The mirror `doc/research.md` names,
  `api.library.loxone.com`, did not resolve on 2026-11-05. The Loxone
  library pages answer 403 behind Cloudflare. The forum copies on LoxWiki and
  photovoltaikforum are revision 7, and iDM's own media library still lacks
  812170. The partner portal is out of reach without partner access. What
  remains is to ask iDM support by mail for a revision covering 20.24-2608.
- **Unannounced updates.** The owner thinks the update was either automatic
  or a manual one done remotely. The Fachmann level dropped several times
  that afternoon, which would fit a remote session, but the log records
  neither kind. Neither can easily be switched off, so the guard checks in
  every session, for good.
