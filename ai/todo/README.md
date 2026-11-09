# Order of the open todos

The order the open todos are worked in, and why; what each needs stays in
its own note. The PV control comes first, then the rest.

## 1. PV control

`pv-control-of-74-and-88`, in its README's order: 4108 at 1.2, 1.0 and 0.8,
one run each; the meter-style run with `PV011` at 0.5 min; the overnight
test of 74; a PV hot water charge.

`watch-the-request-reason-pv-in-idm-web` goes along with them: step 1, a
capture, during the next of these runs; steps 2 and 3 after its design
questions, before the runs that need the reason.

## 2. The rest

1. `what-glt-requests-1710-1712-1713-do-unsettled`: write runs, all
   volatile.
2. `fachmann-level-duration-and-renewal`: measurements at rest, then the
   renewal in `IDM.Navigator.Web.Level`.
3. `page-heat-exceeds-waermemenge-registers-by-1-19`: a watch over several
   days, on days without a run.
4. `recheck-control-behavior-on-20-24-2608`: during any run watched anyway.
5. `eeprom-guard-needs-exact-round-trip`: waits for the first EEPROM
   target.
6. `controller-behavior-when-glt-values-stop-unknown`: a register each time
   one is listed as a target.
