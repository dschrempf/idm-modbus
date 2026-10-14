# `LevelChange` conflates "nothing sent" with "no answer"

`levelResponses = []` (`src/IDM/Navigator/Web/Level.hs`) means both "the
level already was what was asked for, nothing was sent" and "sent, and nothing
arrived within the second `drain` listens". A sum type, e.g.
`AlreadyThere UserLevel | Sent { before, after, responses }`, keeps them
apart; it changes `idm-web`'s report too.
