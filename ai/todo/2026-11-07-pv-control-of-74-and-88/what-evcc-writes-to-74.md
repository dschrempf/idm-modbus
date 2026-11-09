# What evcc writes to 74

Read on 2026-11-08 from idm-waermepumpen (evcc-io/evcc#19002, comment of
2026-11-08), the Lambda solution it points to,
lambda-zewotherm-in-evcc-v2-mit-ueberschuss-steuerung (evcc-io/evcc#35894),
and the Lambda thread behind it,
lambda-pv-ueberschuss-werte-zu-hoch (evcc-io/evcc#20179). None
of them measures an iDM; they matter because evcc is what most iDM owners
feed 74 from.

## Stock evcc: the draw plus the surplus

evcc's iDM template, `templates/definition/charger/idm.yaml`, writes its
setpoint to 74 as `float32s` with function code 16 and scale 0.001, so in kW,
and reads the draw from 4122. Since
loadpoint-limit-released-power-to-available-excess
(evcc-io/evcc#20286, merged 2025-04-01) a heat pump's setpoint is its
measured draw plus the surplus. The controller adds its own draw back to 74,
so stock evcc counts the draw twice: while the pump runs and anything is
exported, 74 sits above the export, the case in which a constant surplus
drove the speed to the top here. iDM owners in evcc-io/evcc#20179 and
idm-falsche-berechnung-pv-ueberschuss (evcc-io/evcc#19677) report the same; one
took the pump out of evcc for it.

## The Lambda workaround: the export, clamped at 0

The YAML of evcc-io/evcc#35894 writes `max(0, setpoint − draw)`, that is the
grid meter's export less evcc's `residualPower`, renewed every 60 s by a
watchdog with a 2-minute timeout. Its author holds that an iDM behaves the
same and the YAML carries over with the registers changed; untested on an
iDM.

On this machine that is the meter-style run of the README, with
two differences:

- **Renewed every 60 s.** The Lambda wants a value within 5 minutes and
  smooths over 10 to 15 itself; here 74 is held for at least five hours
  (`SSYSPV030`) and smoothed over `PV011`.
- **Never negative.** Here a value below 0 ends a run. Clamped, a run ends
  at `PV006`, or at the minimum runtime where 0 ends it, as on the evening
  of 2026-11-07 but not on 2026-11-06. That run should feed the export
  unclamped, and note what the same run would do clamped.

## Reported

Answered in evcc-io/evcc#19002 on 2026-11-08: the double count, not to
clamp at 0, and 4108 as a cap set before the start. Once the meter-style run is done,
its outcome goes there too.
