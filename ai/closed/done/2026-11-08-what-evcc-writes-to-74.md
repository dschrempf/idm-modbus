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
iDM. Here a value below 0 ends a run; clamped at 0, a run ends at `PV006`
or at the minimum runtime.

## Outcome

Reported in evcc-io/evcc#19002: the double count, not to clamp at 0, 4108
as a cap set before the start, then the swing with `PV011` at 0.1 min. Closed on
2026-11-11; the clamp run is `pv-control-of-74-and-88`'s.
