# Order of the open todos

The order the open todos are worked in, and why; what each needs stays in
its own note. The PV control comes first, then the rest.

## 1. PV control

1. `idm-drive-replaces-drivepv`: a dry run of `idm-drive` on the machine,
   then the switch from `drivepv.py`. The clamp run waits for it.
2. `pv-control-of-74-and-88`, in its README's order, the clamp run first.
3. `idm-drive-reads-the-web-watch-too`: no run waits for it, so it comes
   after the clamp run, or alongside it.

## 2. The rest

1. `what-glt-requests-1710-1712-1713-do-unsettled`: write runs, all
   volatile.
2. `eeprom-guard-needs-exact-round-trip`: waits for the first EEPROM
   target.
3. `controller-behavior-when-glt-values-stop-unknown`: a register each time
   one is listed as a target.
