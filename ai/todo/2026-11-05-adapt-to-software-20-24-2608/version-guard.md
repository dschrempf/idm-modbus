# Check the software version before acting

Every session with the machine first reads the controller's software
version. A write goes ahead only if that is the version the table describes;
otherwise it stops and names both versions. A read goes ahead on any version,
and carries the one it was made on. An update came unannounced on
2026-11-05, and a write planned against one register layout can land on
another: 4112 was a `FLOAT` across 4112 and 4113, and 4113 is now
`Sperre Booster 1`. Updates cannot easily be switched off here (`README.md`),
so the check stays for good.

## Facts to build on

- Over Modbus, since 20.24-2608: 522 major (24), 524 minor (2608), 526 patch
  (0), each one register. 1574 did not list them, and whether it answered
  there is unknown. A 1574 refusing them would also fail the check, which is
  right.
- Over the web: `N2_SYSTEM_INFO`, setting 4754, at Kunde level, prints
  `Software Version`. `N2_SERVICE_INFO`, 4838, needs Fachmann.
- `idm-dump` and `idm-write` speak Modbus, `idm-web` and `tools/webprobe.py`
  the web protocol. Modbus may be switched off while the web works.
- Captures are named by the shell redirect that writes them, not by the tool.

## Decided

- **Once per session.** The version is read when a connection is made, and
  again on every reconnect, since an update restarts the controller. It is
  not read before each request.
- **Writes refuse on any other version, with no override:** `idm-write`,
  `idm-web --enter-fachmann` and `--leave-fachmann`, and `write` in the
  library.
- **Reads work on any version, and say which.** A read is harmless to the
  machine, and re-checking a new software needs exactly these reads, so they
  need no override flag. A read decoded with a table for another software
  can still mislead: on 2608 the table reads 4112 as a `FLOAT` over 4112 and
  4113. So the session's version goes with every result: a field in every
  capture, part of what the library returns, and a warning naming both
  versions on the terminal when they differ.
- **Every capture records the software it was read on**, as a field the tool
  writes.
- **The existing captures are labeled in their name:** 20.24-2608 for the
  eleven of 2026-11-05 from 16:17 on (the scan of 1617 and its stderr, the
  shows of 1619 and 1634, the webapi captures of 1620, 1624 and 1636, the
  level logs of 1624 and 1636, the widths of 1639 and the webui of 1641), and
  20.24-1574 for every one before 16:09, as the log supports (`README.md`).
  They are verbatim and cannot take a field. Update the citations in `doc/`
  and the naming scheme in `captures/README.md` with them.

## Decided in the second round, and built

Built on 2026-11-05; `Changelog.md` and `CLAUDE.md` describe it.

1. **Stated by hand, checked.** `data/navigator-2.0-software.tsv`, series,
   major, minor, patch, like `navigator-2.0-gltmon-parameters.tsv`: the
   transcription reads it and refuses a capture read on another software,
   and `IDM.Navigator.Table.navigator20Software` splices it. It reads 20,
   24, 1574, `unknown`: no capture of 1574 holds a patch. The rebuild
   (`table-rebuild.md`) sets it to 2608 and patch 0, and the script then
   refuses any capture of 1574 that records its software.
2. **Each channel compares what it reads.** Modbus: major, minor and patch
   (526 reads 0, and the owner wants it used). Web: series, major and minor;
   the string has no patch, and the build hash is not compared. An unknown
   patch confirms nothing, so on the current file every Modbus write
   refuses.
3. **A witness in the library.** `Client.Session` and `Web.Session` read the
   version when they open; `writable` gives a `Writable`, which `write`,
   `enterFachmann` and `leaveFachmann` take. A refusal is a `Mismatch`.
4. **Captures wrap their entries.** `{"software": …, "entries": […]}` for a
   scan, widths and webapi capture, a `software` field on each watch line,
   a first `software` line in what `idm-web` prints. `webprobe.py` reads
   4754 itself, and reads the data file to warn.

The existing captures are renamed `navigator-2.0-KIND-SOFTWARE-DATE-TIME`,
and the citations in `doc/` and in `todo` with them; `closed` keeps the old
names.

## Open

- Try it on the machine: a read should warn (2608 against 1574), and
  `idm-write HOST 74 …` refuse before it sends anything.
- `IDM.Modbus.TCP`, which the library re-exports, still exports `connect`
  and `writeRegisters`, so a consumer can write any address without a
  target or the guard. `CLAUDE.md` says a consumer reaches a register only
  through a target, which that export contradicts.
- Tell the consumers: a refused write, and a read on another software, are
  new outcomes for `idm-manager`, and its notes on reading the version
  (`beyond-this-update.md`) are to be checked against the API above.
  `~/nix/config` runs nothing against the pump yet.
