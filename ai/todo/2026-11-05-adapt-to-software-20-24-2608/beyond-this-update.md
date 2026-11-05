# Beyond this update

What would have made this update cheaper, and makes the next one so.

- **Every capture names the software it was taken on.** Scans, watches,
  widths and webapi captures carry no version today. Matching them to
  `doc/software-versions.md` by date works only because the update left a
  restart in the log. With the guard reading the version anyway, writing
  it into the capture is one field.
- **The consumers.** `~/nix/config` and `idm-manager` run against the same
  machine. The guard changes what the executables do, so tell them, and
  `idm-manager`'s own assumptions about the machine may have changed with
  the update.
- **A newer parameter list.** 812170 revision 10 documents software
  20.21-101. Ask iDM support whether a revision covers 20.24-2608 and the
  new `N2_GLTMON` addresses; `doc/research.md` already lists the question.
- **Unannounced updates.** Find out whether the update came through myiDM
  and whether automatic updates can be switched off or announced. Until
  then the guard is the only warning.
