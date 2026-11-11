# The clamp run, with `PV011` at 0.1 min

Step 1 of `README.md`, and the checks every run on 74 or 88 needs. Whether
88 weighs in a start, a stop or a settling loop is open in
`doc/pv-control.md`, "The PV target at 88", and not worth a run of its own.

## Before each run

- The pump idle, B38 at 31 °C or below: a start needs B38 below `PV006`
  less 13300, 36 °C, and the run ends at `PV006`, 40 °C.
- At least 30 minutes since the last PV stop.
- 88 reads 0.0.

At the end the driver writes its finals, 88 to 0 among them. Check in the
watch that 88 reads 0.0 and stop the watches; stopping the web watch
leaves the Fachmann level. Never end with 88 away from 0. End a schedule
on the stop, `until = "stop"`, rather than a time, so the final -0.5 does
not end a run the controller would hold.

## Next: the clamp

74 written as the export clamped to ±0.1 kW, every 10 s: beyond the band
the controller sees only the sign, and the integral moves the speed at a
fixed, slow rate. Smoothing the export instead would add lag, which is what
the mean of 2.0 min did. A clamp is a choice a consumer would make; written
as a fixed schedule it stays a measurement.

The schedule, `schedules/pv-clamp-0-1.toml`: the PV held longer than on
2026-11-10, 2.0 to 12 minutes after the start, past the stop at 8 and the
minimum runtime at 10, then 1.5, 1.2 and 1.0, the last until the stop.

    IDM_PIN=... cabal run idm-web -- HOST --watch 10 --reason --fachmann 4768 5888 6245 10263 12763 10389 > webwatch.jsonl
    cabal run idm-drive -- HOST schedules/pv-clamp-0-1.toml > drive.jsonl
    IDM_PIN=... tools/webprobe.py HOST > webapi.json

What to read: the swing's amplitude and period against 2026-11-10, the mean
at 8 minutes and whether the run passes it, and the PV below which the run
ends. If the swing stays, lower gains are next (`README.md`, step 2).
