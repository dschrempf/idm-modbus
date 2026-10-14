# `LevelChange` conflates "nothing sent" with "no answer"

`levelResponses = []` (`src/IDM/Navigator/Web/Level.hs`) means both "the
level already was what was asked for, nothing was sent" and "sent, and nothing
arrived within the second `drain` listens". A sum type, e.g.
`AlreadyThere UserLevel | Sent { before, after, responses }`, keeps them
apart; it changes `idm-web`'s report too.

Fixed on 2026-10-14 with a type per function, so each holds only what it can
come to: `Entry` is `AlreadyFachmann | EntryDeclined Int | EntrySent Sent`,
`Exit` is `AlreadyCustomer | NoNotice UserLevel | ExitSent Sent`, and `Sent`
keeps before, after and responses. `leaveFachmann` no longer asks for the
notices at Kunde. `idm-web` prints `user level  X` without an arrow when
nothing was sent, `answer      none` when the request went out and nothing
came back, and dies on `EntryDeclined` and `NoNotice`, naming the level.
