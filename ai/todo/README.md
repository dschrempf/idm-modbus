# Order of the open todos

The order the open todos are worked in, and why; what each needs stays in
its own note. The PV control comes first, then the rest.

## 1. PV control

1. `idm-drive-takes-a-new-value-without-ending-the-run`: the run of
   2026-11-11 was steered by hand through a drive per step, ended with
   SIGKILL; the next runs on 74 want the same, so it comes first.
2. `pv-control-of-74-and-88`, in its README's order, the clamp around the
   target first; it can run before the first is done, through a drive per
   step as on 2026-11-11.
3. `idm-drive-reads-the-web-watch-too`: no run waits for it; settle it
   together with the first, which aims at one process and one capture per
   run too.

## 2. The rest

1. `what-ae026-governs-and-whether-it-runs-the-charge-pump`: an overnight
   watch, reading only, which needs a night below 3 °C; the note has the
   run ready to start.
2. `record-the-hot-water-stop-and-circuit-d-of-2026-11-24`: writing only,
   its graphs captured on 2026-11-26.
3. `what-glt-requests-1710-1712-1713-do-unsettled`: write runs, all
   volatile.
4. `eeprom-guard-needs-exact-round-trip`: waits for the first EEPROM
   target.
5. `controller-behavior-when-glt-values-stop-unknown`: a register each time
   one is listed as a target.
