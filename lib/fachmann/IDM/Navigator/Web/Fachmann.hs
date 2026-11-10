{-# LANGUAGE DeriveFunctor #-}

-- |
-- Module      :  IDM.Navigator.Web.Fachmann
-- Description :  When a web watch enters, renews and gives up the Fachmann level
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- The decisions of @idm-web --watch --fachmann@, without its IO, so that the
-- test suite reaches them. The watch reads the level first in every round,
-- asks 'decide', acts through "IDM.Navigator.Web.Level", whose two writes
-- this module only schedules, and counts a try with 'afterTry'.
--
-- The controller ends the level sixty minutes from the entry, however often
-- it was read meanwhile (@doc/verification/2026-11-09-heating-run-as-on-1574.md@),
-- so the watch leaves it before then and enters again.
module IDM.Navigator.Web.Fachmann
  ( Writability (..),
    Tries (..),
    Since (..),
    Holding (..),
    Decision (..),
    decide,
    Attempt (..),
    Untaken (..),
    attempt,
    afterTry,
    renewAfterSeconds,
    gapSeconds,
    maxTries,
  )
where

import IDM.Navigator.Web (UserLevel (..))
import IDM.Navigator.Web.Level (Entry (..), Sent (..))
import IDM.Navigator.Web.Session (Failure)

-- | Whether the round's session gave a
-- 'IDM.Navigator.Web.Session.Writable': whether it is on the software the
-- table describes.
data Writability = CanWrite | CannotWrite
  deriving (Show, Eq)

-- | Tries in a row that did not take. An entry that takes resets them.
newtype Tries = Tries Int
  deriving (Show, Eq, Ord)

-- | What the watch last did about the level, and when.
data Since t
  = -- | nothing yet, or the level fell back: an entry is due
    Unentered
  | -- | an entry took
    Entered t
  | -- | the watch left the level, to enter it again after 'gapSeconds'
    Paused t
  | -- | a try did not take
    Tried t
  | -- | the session gave no 'IDM.Navigator.Web.Session.Writable', and the
    -- watch said so
    Barred
  deriving (Show, Eq, Functor)

-- | Where the watch stands with the level. The watch keeps instants;
-- 'decide' is given the seconds since them.
data Holding t = Holding
  { holdingTries :: Tries,
    holdingSince :: Since t
  }
  deriving (Show, Eq, Functor)

-- | What the watch does in a round, after reading the level.
data Decision
  = -- | send nothing
    Hold
  | -- | try an entry
    Try
  | -- | leave the level, to enter it again 'gapSeconds' later. Also where
    -- the level is Fachmann and the watch did not enter it, so that it knows
    -- when the sixty minutes began.
    Renew
  | -- | the level is not Fachmann where an entry took; the next round tries
    FellBack
  | -- | 'maxTries' tries in a row did not take; try no more
    GiveUp
  | -- | the session gives no 'IDM.Navigator.Web.Session.Writable'; try
    -- nothing
    Unwritable
  deriving (Show, Eq)

-- | The decision for a round. From 'maxTries' tries on, it is 'GiveUp'
-- whatever else holds, so a watch that has given up tries nothing again.
decide ::
  Writability ->
  -- | the level the round read, if it did
  Maybe UserLevel ->
  -- | with the seconds since what the watch did last
  Holding Double ->
  Decision
decide writability level (Holding tries since)
  | tries >= maxTries = GiveUp
  | writability == CannotWrite = if since == Barred then Hold else Unwritable
  | otherwise = case (level, since) of
      (Nothing, _) -> Hold
      (Just Fachmann, Entered t)
        | t >= renewAfterSeconds -> Renew
        | otherwise -> Hold
      -- not the watch's entry, or one that took late: when the sixty
      -- minutes began is not known
      (Just Fachmann, _) -> Renew
      (Just _, Entered _) -> FellBack
      (Just _, Paused t) -> after t
      (Just _, Tried t) -> after t
      (Just _, Unentered) -> Try
      (Just _, Barred) -> Try
  where
    after t = if t >= gapSeconds then Try else Hold

-- | What a try came to.
data Attempt
  = -- | the level is Fachmann now
    Took
  | Untaken Untaken
  | -- | Fachmann already, though the round read another level; nothing was
    -- sent, and the next round renews
    Preempted
  deriving (Show, Eq)

-- | Why a try did not take.
data Untaken
  = -- | the entry answered, and the controller reported this level after it
    AnsweredAt UserLevel
  | -- | a level neither Kunde nor Fachmann; nothing was sent
    Declined Int
  | FailedWith Failure
  deriving (Show, Eq)

attempt :: Either Failure Entry -> Attempt
attempt r = case r of
  Right (EntrySent sent)
    | sentAfter sent == Fachmann -> Took
    | otherwise -> Untaken (AnsweredAt (sentAfter sent))
  Right (EntryDeclined n) -> Untaken (Declined n)
  Right AlreadyFachmann -> Preempted
  Left e -> Untaken (FailedWith e)

-- | Where the watch stands after a try begun at the instant.
afterTry :: t -> Tries -> Attempt -> Holding t
afterTry t tries@(Tries n) a = case a of
  Took -> Holding (Tries 0) (Entered t)
  Untaken _ -> Holding (Tries (n + 1)) (Tried t)
  Preempted -> Holding tries Unentered

-- | Seconds from an entry to its renewal, five minutes short of the sixty
-- the controller grants (@doc/verification/2026-11-09-heating-run-as-on-1574.md@),
-- room for a round's period, the pause of 'gapSeconds' and the entry's own
-- wait for the hour to turn.
renewAfterSeconds :: Double
renewAfterSeconds = 55 * 60

-- | Seconds from a leave to the entry after it, and from a try that did not
-- take to the next. An entry sent seconds after a leave answered success and
-- left the level at Kunde; sent again 20 s later it took
-- (@captures/navigator-10-level-20.24-2608-2026-11-10-2056.log@). 30 s
-- leave a margin.
gapSeconds :: Double
gapSeconds = 30

-- | Tries in a row before the watch gives up. Repeated wrong entries block
-- the code input for a while, @N2_USERLEVELINPUTBLOCKED@, as
-- Xerolux/idm-heatpump-hass reports, untested here; an entry that did not
-- take may count as one. On 2026-11-10 the second try took
-- (@captures/navigator-10-level-20.24-2608-2026-11-10-2056.log@), so three
-- leave one spare.
maxTries :: Tries
maxTries = Tries 3
