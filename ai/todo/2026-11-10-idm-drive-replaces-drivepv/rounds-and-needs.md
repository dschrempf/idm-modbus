# Rounds and needs: one read for every part of a program

## The idea (D6)

A program that drives the controller has parts that read: a watch that
records registers, a driver that decides from 1100 and 4122, and later a
manager that records every input. Each part names its **need**, the
registers it reads. A **round** reads the union of the needs once, in one
session, and hands each part the samples it named. No register is read
twice in a round, no part knows what the others read, and the controller
has one client however many parts there are.

## Library: `IDM.Navigator.Rounds`

What `watch` in `app/Main.hs` does today, made general. A sketch, to be
settled in session 1:

```haskell
-- | A part of a program: the registers it reads each round, and what it
-- does with them. Abstract; see "Periods".
data Need

need :: [Register] -> (Round -> IO ()) -> Need

data Round = Round
  { roundStarted :: ZonedTime,
    -- | the session the round was read on; Nothing if none could be opened
    roundSession :: Maybe Session,
    -- | every register some need named, read once
    roundSamples :: Map Address (Outcome Sample)
  }

rounds :: IO Session -> Period -> [Need] -> IO a
```

- The union is read in the order of first mention, so `idm-dump --watch`
  reads in the order it is given, as now.
- A lost connection ends the session. The rest of the round's reads become
  `Unanswered` outcomes, and the next round opens a new session, which
  reads the software again. This is today's `watch`.
- The pacing is today's: `pollIntervalMicroseconds` between requests, and a
  round that overruns starts the next at once, without catching up.
- One period for all needs, to begin with: see "Periods".

The watch-line format, `watchLine` and its helpers, moves out of
`app/Main.hs` into the library, as `IDM.Navigator.Capture`. The drive
writes the same lines, and a recorder in idm-manager will want them too.
`idm-dump --watch` becomes `rounds` with a single need that prints the
lines, and its output does not change: session 1 checks it against
literal samples in `test/Main.hs`.

## Periods

A **round** is one pass over every register some need names, each read
once. The **period** is the time from the start of one round to the start
of the next: the 10 of `idm-dump --watch 10`, the `round` of a schedule.
For now every need shares the one period, and a phase's `every` writes at
the first round at or after it is due, so it rounds up to a whole number of
periods.

Kept open for a period per need, a recorder every 60 s beside a driver
every 10 s, say:

- **`Need` is abstract.** Consumers build it with
  `need :: [Register] -> (Round -> IO ()) -> Need`. A pace added later is a
  second constructor function, and a consumer that does not use it does
  not change.
- **The loop is the only place that decides which registers a round
  reads.** It reads the union of the needs that are due in that round, and
  `rounds` keeps the timing to itself, in one function.
- **A need checks each register in the round.** It looks up every one it
  named and handles an absent one, as the step already does for a 4122
  that did not answer. A round that skips a need's registers is then not a
  new case.
- **The capture records each read with its own time,** not the round's,
  so a mixed pace needs no new line format.

## Library: `IDM.Navigator.Drive`

The part of a driver that every driver shares, whatever decides the values:

```haskell
-- | A write the loop may repeat: free targets only, so no regulating
-- through an EEPROM register.
data Command = Command (Target 'Free) Value

data Drive = Drive
  { driveRegisters :: [Register],
    -- | what to write after this round; Left ends the drive
    driveStep :: Round -> IO (Either Ending [Command]),
    -- | written in order on every exit
    driveFinal :: [Command]
  }

drive :: IO Session -> Period -> [Need] -> Drive -> IO Ending
```

- **Restricted to free targets.** `Command` takes only a `Target 'Free`,
  so the types keep an EEPROM register out of a loop that renews its
  values.
- **Writes need a writable session.** A command goes out through `write`,
  only on a session for which `writable` gives a `Writable`. A session on
  other software is logged as a refusal and nothing is sent. That happens
  after an update, which restarts the controller and resets 74 to 0 and
  4108 to -1 (`doc/verification-2026-11-07-restart.md`).
- **The final values go out on every exit:** the step's `Left`, a compressor
  stop the step reports, SIGINT, SIGTERM, or an exception. They are written
  with asynchronous exceptions masked, and further signals are ignored, as
  `drivepv.py` does. SIGTERM needs a handler from `unix`, which throws to
  the main thread; SIGINT already arrives as `UserInterrupt`. If the session
  is lost, the finals reopen it, up to three times, 10 s apart, and every
  failure is logged.
- **No defaults for the finals.** The schedule names all three, so a log
  states them (`schedule-file.md`).

The step function is where a strategy goes. In this package it is the
schedule's, and in idm-manager it is the plan's. `drive` holds no
strategy, so it stays interface under the package's rule in `CLAUDE.md`.

## Not in this design

The web watch, `idm-web --watch`, stays a process of its own. It is a
second channel, with its own session and the Fachmann level. A need on it
would be the same idea over `IDM.Navigator.Web.Session`. That can come
later, once a run needs both channels lined up more closely than
`runtable.py` lines them up by time.
