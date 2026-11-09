# Re-check control behavior on 20.24-2608

The update of 2026-11-05 left the registers and the settings tree as they
were, but for what `doc/software-versions.md` lists. What the documents
measured of the machine's behavior was measured on 20.24-1574, and an update
may change control behavior without changing a register. Re-check each when
a heating run is watched anyway, and record the outcome in a new dated
document that `doc/software-versions.md` points to.

- `doc/verification-2026-10-16-draw.md`: graph channels 112 and 365, both
  `T20x_QACT` before, are now `N2_THERMAL_PERFORMANCE_POLY` and
  `…_FLOWSENSOR`. Its 4112, which stayed at -1.0, is gone; 4113 and 4114
  are locks (`power-limit-4108-semantics-unknown`).
- `doc/verification-2026-10-16-charge-pump.md`: 1074 is M73's signal, now
  from the manual too, and 1104 does not follow it
  (`charge-pump-status-1104-reads-not-driven-while-pumping`). It is prose
  in `doc/research.md`'s open questions and in the haddock of `Drive`
  (`decide-how-a-measured-fact-enters-the-table`); if it holds here too,
  weigh again a `Presence` constructor for a register that answers but does
  not follow its quantity, which takes 1104 out of `present`.
- `doc/verification-2026-11-05-floor.md`: the floor of 24 rps at 0.67 kW.
- `doc/verification-2026-10-01-charge.md`: a hot water charge.
- `doc/verification-2026-09-20.md`: the display against the registers.

Re-checked by reads on 2026-11-05 already: every address, the settings
tree's ids and identifiers, the protocol, the Fachmann code, and the labels
of `systemMode` (`adapt-to-software-20-24-2608`, `rechecks.md`). Settled
from the captures on 2026-11-09: `FW045` and `FW046` went with `FW044` Off,
on 20.24-1574, and `N2_PING` never went (`doc/software-versions.md`).

## Next: the heating run expected on 2026-11-09 at 15:00

Read only, at Kunde level; the Fachmann part is optional. Start about 14:45,
so the rest before the start is in the captures, and name each capture by
the minute it starts.

1. Modbus, every 10 s:

       cabal run idm-dump -- HOST --watch 10 74 4108 1008 1090 1091 1100 1004 1098 1072 1074 1104 4122 4126 1746 1748 1750 1754 > captures/navigator-10-watch-20.24-2608-2026-11-09-HHMM.jsonl

   1090, 1091 and 1100 are the mode, the request and the compressor; 1072,
   1074, 1104 and 4126 the charge pump and the heat; 74 and 4108 what the
   noon run left standing, -0.5 and -1.0 at 12:56; 1746 to 1754 the
   counters of `page-heat-exceeds-waermemenge-registers-by-1-19`.

2. The web, every 10 s:

       IDM_PIN=... cabal run idm-web -- HOST --watch 10 --reason 4782 10263 > captures/navigator-10-webwatch-20.24-2608-2026-11-09-HHMM.jsonl

   The request reason; 4782 `N2_ANALOGUE_OUTPUTS`, M73 against 1074; 10263
   `N2_PV_POWER`, the forecast draw. Both pages answer at Kunde; 6245
   `N2_MODULATION_OVERVIEW` does not (`idm-web --show`, 2026-11-09 13:33).

3. Optional, at Fachmann: `idm-web HOST --enter-fachmann` before the watch,
   logged to `captures/navigator-10-level-20.24-2608-2026-11-09-HHMM.log`,
   and 6245 added to the watch. It gives the speed and motor power for the
   draw re-check, and, not entered again, the level's duration under a
   10 s watch, step 1 of `fachmann-level-falls-back-before-sixty-minutes`:
   the first 6245 refused dates the fall-back.

4. At the display, at the start: the request reason it shows, if it shows
   one, with the time. `watch-the-request-reason-pv-in-idm-web` never
   compared the two.

While it runs: `tools/runtable.py WATCH --web WEBWATCH --last`.

Expected: 1090 `Heizbetrieb` and `info` 513, bit 1 and `RD_REQ_HK_C`, as
on 2026-11-05 at 16:24; circuit C is the only one with `activeMode` 1. A
hot water charge instead reads mode 4, tests that table of `reasonBits`,
and re-checks `doc/verification-2026-10-01-charge.md`.

Stop both watches 10 to 15 minutes after 1100 falls to 0, then:

- `IDM_PIN=... tools/webprobe.py HOST > captures/navigator-10-webapi-20.24-2608-2026-11-09-HHMM.json`:
  graph channels 112 and 365 over the run against 4126, and the statistics
  page's day.
- The counters alone, for days, one Modbus client at a time:
  `cabal run idm-dump -- HOST --watch 600 1746 1748 1750 1754 1100 > captures/navigator-10-watch-20.24-2608-2026-11-09-HHMM.jsonl`.

What it re-checks: `doc/verification-2026-10-16-charge-pump.md`, 1074
following M73 and 1104 at `ffff`; `doc/verification-2026-10-16-draw.md`,
4122 against 6245's motor power, at Fachmann only; and the request reason
outside a PV run, against 1090 and 1091. Not the floor, which needs
settings changed, nor `doc/verification-2026-09-20.md` beyond the reason.
