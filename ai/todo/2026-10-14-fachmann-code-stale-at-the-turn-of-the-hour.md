# The Fachmann code is stale at the turn of the hour

`enterFachmann` (`src/IDM/Navigator/Web/Level.hs`) spells the code from the
clock of the `askStatus` it starts with, and sends it at least the pace
interval later, 0.5 s by default. A status read in the hour's last second
sends the previous hour's code; the level stays, and `idm-web
--enter-fachmann` dies with "the level did not change", which does not say
why.

Fix: when the clock read is within a few seconds of the hour, wait for it to
turn and read the status again. A retry after a refusal is the other way, but
it sends a second code and the controller's reaction to a wrong one is
unknown.
