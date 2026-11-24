# Order of the open todos

The order the open todos are worked in, and why; what each needs stays in
its own note. The PV control comes first, then the rest;
`record-the-defrosts-and-circuit-d-of-2026-11-24-before-the-graphs-age-out`
has to be done before about 2026-12-02, whatever comes first.

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

1. `record-the-defrosts-and-circuit-d-of-2026-11-24-before-the-graphs-age-out`:
   its evidence lives on the controller until about 2026-12-02.
2. `what-ae026-governs-and-whether-it-runs-the-charge-pump`: an overnight
   watch, reading only, which needs a night below 3 °C.
3. `what-glt-requests-1710-1712-1713-do-unsettled`: write runs, all
   volatile.
4. `eeprom-guard-needs-exact-round-trip`: waits for the first EEPROM
   target.
5. `controller-behavior-when-glt-values-stop-unknown`: a register each time
   one is listed as a target.
