# `enterFachmann` sends the code at any level but Fachmann

`enterFachmann` sends the code whenever the level is not `Fachmann`,
including an `OtherLevel` above it (commissioning answers to level 4). What
the controller does then is unknown. Refuse unless the level is `Customer`,
or keep sending and report the before/after as now?

Decided on 2026-10-14: refuse. `enterFachmann` sends the code from `Customer`
only and answers `EntryDeclined n` at `OtherLevel n`, sending nothing.
Leaving is unchanged: it acknowledges the notice at any code level, as the web
interface does.
