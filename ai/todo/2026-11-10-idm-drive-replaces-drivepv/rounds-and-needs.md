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
settled in session 1; the names are pinned, since sessions 2 to 4 build
against them.

```haskell
-- | One read of a round: what was asked, when, on which session, and what
-- came back.
data Asked = Asked
  { askedRegister :: Register,
    -- | the local time the read was asked: the stamp of its capture line
    askedAt :: ZonedTime,
    -- | the same moment on the monotonic clock, for durations
    askedMonotonic :: Double,
    -- | the session it was asked on; Nothing where none was open
    askedSession :: Maybe Session,
    -- | Nothing where no session was open, so nothing was sent
    askedSample :: Maybe Sample
  }

data Round = Round
  { -- | every register some need named, each once, in the order of first
    -- mention
    roundReads :: [Asked],
    -- | the session still open at the round's end; Nothing if it was lost
    -- or none could be opened
    roundSession :: Maybe Session
  }

-- | The sample of an address, where the round asked it and got an answer
-- or a failure.
roundSample :: Round -> Address -> Maybe Sample

-- | What a round reports as it goes, so that a capture can print each read
-- when it is made, and a session's opening and loss are in the stream.
data RoundEvent
  = ReadDone Asked
  | Opened Session
  | NotOpened Text
  | Lost Ending -- IDM.Modbus.TCP's

-- | A part of a program: the registers it reads each round, and what it
-- does with them. Abstract; see "Periods".
data Need

need :: [Register] -> (Round -> IO ()) -> Need

-- | One round: open a session where none is, read every register given,
-- report each read as it is made.
readRound :: Requests m -> (RoundEvent -> m ()) -> Maybe Session -> [Register] -> m Round

-- | Round after round, every period, until an exception.
rounds :: IO Session -> (RoundEvent -> IO ()) -> Period -> [Need] -> IO a
```

- **Rounds are reads only.** A write is not part of a round: the drive
  reports it as an event of its own, with its own time (`event-log.md`).
- **One primitive, two loops.** `readRound` takes the session in and
  hands it back, so the loop that calls it owns it. `rounds` is one loop
  over it, `drive` another, and `drive` holds the session it needs for its
  writes and its finals.
- **Tested without a machine.** `readRound` is generic over the requests,
  as `writeWith` is over `Requests m`: opening a session, reading a
  register, closing, pausing, both clocks. `checks` run it against a fake
  controller in `State`: a loss in mid-round makes the rest of the round
  `Nothing` with no session, the next round opens a new one and reports
  it, and a failed opening asks nothing. The type of these requests, and
  how a fake session stands in for `Session`, are session 1's to settle.
- The union is read in the order of first mention, so `idm-dump --watch`
  reads in the order it is given, as now.
- A lost connection ends the session. The rest of the round's reads are
  not asked, and the next round opens a new session, which reads the
  software again. This is today's `watch`.
- The pacing is today's: `pollIntervalMicroseconds` between requests, and a
  round that overruns starts the next at once, without catching up.
- One period for all needs, to begin with: see "Periods".
- **Nothing is printed by the library.** What `watch` writes to stderr
  today, a software mismatch, a failed opening, a loss, is a `RoundEvent`,
  and the executable prints it.

The watch-line format, `watchLine` and its helpers, moves out of
`app/Main.hs` into the library, as `IDM.Navigator.Capture`, over an
`Asked`. The app's `Outcome` (`Returned`, `Unanswered`) goes with it into
`Asked`, so the library has one `Outcome`, the write's. The drive writes
the same lines, and a recorder in idm-manager will want them too.
`idm-dump --watch` becomes `rounds` with a single need that prints nothing
itself: its lines come from `ReadDone`, each printed when the read is
made, as now, so a process killed in mid-round loses no line it read. Its
output does not change: session 1 checks it against literal samples in
`test/Main.hs`.

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
  named with `roundSample` and handles an absent one, as the step already
  does for a 4122 that did not answer. A round that skips a need's
  registers is then not a new case.
- **Each read carries its own time,** `askedAt`, not the round's, so a
  mixed pace needs no new line format.

## Library: `IDM.Navigator.Drive`

The part of a driver that every driver shares, whatever decides the values:

```haskell
-- | A write the loop may repeat: free targets only, so no regulating
-- through an EEPROM register.
data Command = Command (Target 'Free) Value

data Drive r = Drive
  { driveRegisters :: [Register],
    -- | what to write after this round; Left ends the drive, for the
    -- step's own reason
    driveStep :: Round -> IO (Either r [Command]),
    -- | written in order on every exit
    driveFinal :: [Command]
  }

-- | How a drive ended: its step's reason, or an exception, a signal's
-- among them.
data Finish r = Finished r | Interrupted SomeException

data DriveEvent
  = RoundEvent RoundEvent
  | Wrote Command (Outcome 'Free)
  | -- | a command not sent: no session, or one on other software
    Skipped Command SkipReason
  | -- | the finals begin; their writes follow as 'Wrote'
    Finals

drive :: IO Session -> (DriveEvent -> IO ()) -> Period -> [Need] -> Drive r -> IO (Finish r)
```

- **The step's reason is the step's.** `drive` does not know a schedule or
  a compressor stop; `r` is `idm-drive`'s `schedule` or `stop`, and
  idm-manager's own. This also keeps `Ending`, the name `IDM.Modbus.TCP`
  gives a lost connection, for that alone.
- **Restricted to free targets.** `Command` takes only a `Target 'Free`,
  so the types keep an EEPROM register out of a loop that renews its
  values.
- **Writes need a writable session.** A command goes out through `write`,
  only on the round's `roundSession`, and only where `writable` gives a
  `Writable`. Otherwise it is `Skipped` and nothing is sent. Other
  software happens after an update, which restarts the controller and
  resets 74 to 0 and 4108 to -1 (`doc/verification/2026-11-07-restart.md`).
- **The final values go out on every exit:** the step's `Left` or any
  exception, a signal's included. They run in `finally`, under the
  ordinary, interruptible mask, not `uninterruptibleMask`: every request
  waits under `timeout` (`core/IDM/Modbus/TCP/Internal.hs`), which works
  only by an asynchronous exception, so an uninterruptible mask would let
  a controller that stops answering hang the finals for good. If the
  session is lost, the finals reopen it, up to three times, 10 s apart,
  and every failure is an event.
- **Signals are the executable's, not the library's.** The library installs
  no handler and needs no `unix`, so it stays portable, and a consumer
  under systemd installs its own. `idm-drive` installs, with `unix`, a
  handler for SIGINT and one for SIGTERM, replacing GHC's default for
  SIGINT. The first of either sets both to `Ignore` and throws to the main
  thread. The `Finals` event sets both to `Ignore` too, for an exit that no
  signal began. A signal during the finals is then ignored, while the
  finals' own timeouts still work. Only an `Ignore` does this: under the ordinary
  mask a second `UserInterrupt` would arrive at the first socket wait.
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
