# The unit of the PV surplus at 74 is unsettled

## The question

74, `Aktueller PV-Überschuss` (`FLOAT`, `RW/RO`, volatile), is printed in kW
by 812170 and 812184 rev. 13. `N2_GLTMON` prints it as `Überschuss (kW)`.
Community integrations (the evcc discussions) write watts (`doc/research.md`,
"The unit of address 74"). Every source that states a unit says kW, so the
table's kW stands. But nothing has
shown which unit the controller acts on, and a consumer that writes the
surplus will act on the answer.

## Why it can't be read off

On this machine 74 reads 0.0, and the PV signal setting `SSYSPVSIGNAL`
(setting 5335 / 13223, `N2_PV_SIGNAL`) is `N2_NONE`
(`captures/navigator-2.0-webapi-20.24-1574-2026-10-01-1158.json`). Without a PV source
configured, the controller has no reason to look at 74. Looking at a stored
number shows only that it is stored, not how it is scaled.

## How we might solve it

74 is the one target of the write interface, `PvSurplus`, and this is the
test its activation goes with:

1. Set `N2_PV_SIGNAL` to `N2_GLTSF` (key 5), the building management option.
   This is an EEPROM setting, so it costs one cycle. A consumer that feeds
   the surplus needs it set anyway.
2. Set the PV menu (812184, "Parameter Photovoltaik") for what the house
   wants, a store charge rather than hot water: `PV001` Wärmespeicher laden
   "Ja", `PV006` Wärmespeicher Maximaltemperatur 35 °C if its range allows,
   `PV002` Trinkwarmwasserbereitung "Nein", `PV013` Heizgrenze überspringen
   as wanted outside the heating season. The menu is not in the 2026-10-01
   capture, probably hidden while `PV008` is `N2_NONE`; capture it once
   shown.
3. `idm-write HOST 74 3.0`, repeated every minute or so. Read as kW, that is
   more than the machine draws (0.67 kW at the floor,
   `doc/verification-2026-11-05-floor.md`), and the store charge should
   start once `PV011`'s average (2 min) exceeds the forecast at 4122: watch
   1090, B38 at 1008 and the web backend's PV status. Read as W, it is
   nothing, and the PV function stays idle. 74 is volatile, so no EEPROM
   cycle is spent.
4. `idm-write HOST 74 0`, and record the outcome in a dated `doc/`.

Once settled, the outcome belongs to the Haddock of `PvSurplus` (via the
targets file and `tools/transcribe.py`) as well as to `doc/research.md`.
