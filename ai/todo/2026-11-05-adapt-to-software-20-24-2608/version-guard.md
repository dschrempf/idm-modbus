# Check the software version before acting

Every command that acts on the machine first reads the controller's software
version. It goes ahead only if that is the version the table describes.
Otherwise it stops and names both versions. An update came unannounced on
2026-11-05, and a write planned against one register layout can land on
another: 4112 was a `FLOAT` across 4112 and 4113, and 4113 is now
`Sperre Booster 1`.

## Facts to build on

- Over Modbus, since 20.24-2608: 522 major (24), 524 minor (2608), 526 patch
  (0), each one register. 1574 did not list them, and whether it answered
  there is unknown. A 1574 refusing them would also fail the check, which is
  right.
- Over the web: `N2_SYSTEM_INFO`, setting 4754, at Kunde level, prints
  `Software Version`. `N2_SERVICE_INFO`, 4838, needs Fachmann.
- `idm-dump` and `idm-write` speak Modbus, `idm-web` and `tools/webprobe.py`
  the web protocol. Modbus may be switched off while the web works.

## Choices to raise before building

1. **Where the expected version is stated.** State it once. The table
   describes one software, so it belongs with the table: a field the
   transcription writes, see `table-rebuild.md`. The guard and the docs
   derive it from there.
2. **What is compared.** Major, minor and patch, or the whole string with
   the build hash? The hash is only on the web page; 528 reads 0.
3. **Which commands, and reads too?**
   - Writes must refuse: `idm-write`, `idm-web --enter-fachmann` and
     `--leave-fachmann`.
   - Reads that make captures: `idm-dump --json`, `--watch`, `--widths`,
     `idm-web --watch`, `tools/webprobe.py`. Re-checking a new version needs
     exactly these reads, so a plain refusal blocks the re-check. Options are
     an override flag (`--any-software`), or going ahead with the version
     written into the capture (`beyond-this-update.md`).
4. **In the library or the executables.** In the library, as a type: a
   check returns a witness of the version, and `write` asks for it. A
   consumer then cannot write without having checked. In the executables
   only, consumers stay unguarded.
5. **How often.** Once per connection, or before each write. An update
   restarts the controller and ends the connection, so once per connection
   may be enough; confirm by watching a restart.
6. **The web check from Python.** `webprobe.py` has its own session, so
   either it checks 4754 itself, or a shared expected version is read from
   the table data.

Tell the consumers when it lands: a refusal is a new outcome for
`~/nix/config` and `idm-manager`.
