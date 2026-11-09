# Order of the open todos

The order the open todos are worked in, and why; what each needs stays in
its own note. The PV control comes first, then the rest.

## 1. PV control

`pv-control-of-74-and-88`, in its README's order: 4108 at 1.0 from before
the start, held to `PV006`; the meter-style run with `PV011` at 0.5 min;
the overnight test of 74; a PV hot water charge.

Each run on 74 or 88 watches the request reason too, with
`idm-web --watch SECONDS --reason` (`watch-the-request-reason-pv-in-idm-web`,
done).

## 2. The rest

1. `what-glt-requests-1710-1712-1713-do-unsettled`: write runs, all
   volatile.
2. `eeprom-guard-needs-exact-round-trip`: waits for the first EEPROM
   target.
3. `controller-behavior-when-glt-values-stop-unknown`: a register each time
   one is listed as a target.
