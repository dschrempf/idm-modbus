{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}

-- |
-- Module      :  IDM.Navigator.Schedule.Log
-- Description :  The lines idm-drive writes: its reads as a watch writes them, and its events
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- What @idm-drive@ prints, as pure functions, so that the test suite checks
-- the lines @tools\/runtable.py@ reads. A read is the line of
-- 'IDM.Navigator.Capture.watchLine'; every other line is an 'Entry', stamped
-- by 'eventLine'. The executable keeps the clocks, the printing and the
-- signals.
module IDM.Navigator.Schedule.Log
  ( -- * Event lines
    Entry (..),
    eventLine,
    beginEntry,
    driveEntry,
    stepEntry,
    signalEntry,
    endEntry,
    Interruption (..),

    -- * Fields
    phaseKeys,
    address,
    value,

    -- * JSON
    object,
    string,
    number,
  )
where

import Control.Exception (Exception, SomeException (..), displayException, fromException)
import Data.Char (isAscii, isControl, ord)
import Data.List (intercalate)
import qualified Data.Text as T
import Data.Time (ZonedTime)
import Foreign.C.Types (CInt)
import IDM.Modbus.TCP (Address (..), Failure (..))
import IDM.Navigator.Capture (endingText, field, hex, quote, software, stamp, watchLineOn)
import IDM.Navigator.Drive (Command (..), DriveEventOn (..), Finish (..), SkipReason (..))
import IDM.Navigator.Register (Cost (..), Drive (..), Register (..), Value (..))
import IDM.Navigator.Rounds (RoundEventOn (..))
import IDM.Navigator.Schedule (Bounds (..), End (..), Phase (..), Seconds (..), Surplus (..))
import IDM.Navigator.Schedule.Step (Computation (..), Done (..), Event (..))
import IDM.Navigator.Software (ModbusVersion)
import IDM.Navigator.Target (Target, targetRegister)
import IDM.Navigator.Write (Confirmation (..), Outcome (..))
import Numeric (showHex)
import System.Posix.Types (ProcessID)

-- | An event: its name and its fields, each a JSON value.
data Entry = Entry
  { entryName :: String,
    entryFields :: [(String, String)]
  }
  deriving (Show, Eq)

-- | The line of an event at the time given.
eventLine :: ZonedTime -> Entry -> String
eventLine t (Entry name fields) = object (("time", quote (stamp t)) : ("event", quote name) : fields)

-- | The first line: the process to send SIGTERM to, the schedule's path, and
-- its file as read.
beginEntry :: ProcessID -> FilePath -> T.Text -> Entry
beginEntry pid path text =
  Entry "begin" [("pid", show pid), ("schedule", string path), ("text", string (T.unpack text))]

-- | What a drive event comes to: a read's line, as a watch writes it, or an
-- event.
driveEntry ::
  -- | the software a session read
  (s -> Either Failure ModbusVersion) ->
  -- | whether a session runs the software the table describes
  (s -> Bool) ->
  DriveEventOn s ->
  Either String Entry
driveEntry softwareOf writableOn e = case e of
  RoundEvent (ReadDone a) -> Left (watchLineOn softwareOf a)
  RoundEvent (Opened s) ->
    Right
      ( Entry
          "session"
          [ ("software", software (Just (softwareOf s))),
            ("writable", if writableOn s then "true" else "false")
          ]
      )
  RoundEvent (NotOpened why) -> Right (Entry "unopened" [("why", string (T.unpack why))])
  RoundEvent (Dropped why) -> Right (Entry "lost" [("why", string (endingText why))])
  Wrote (Command t v) o ->
    Right (Entry "write" ([("address", address t), ("value", value v)] <> outcomeFields o))
  Skipped (Command t _) why ->
    Right (Entry "skip" [("address", address t), ("why", quote (skipText why))])
  Finals -> Right (Entry "final" [])
  where
    skipText why = case why of
      NoSession -> "no-session"
      SoftwareDiffers -> "not-writable"

-- | What the step did. The executable stamps @start@ and @stop@ with the
-- time 1100 was asked, and the rest with the time they are written.
stepEntry :: Event -> Entry
stepEntry e = case e of
  BeganPhase i p -> Entry "phase" [("index", show i), ("phase", object (phaseKeys p))]
  CompressorStarted -> Entry "start" []
  CompressorStopped -> Entry "stop" []
  Exported c ->
    Entry
      "export"
      [ ("pv", number (computationPv c)),
        ("draw", number (computationDraw c)),
        ("export", number (computationExport c)),
        ("written", number (computationWritten c))
      ]
  NoDraw t -> Entry "skip" [("address", address t), ("why", quote "no-draw")]

-- | A signal, by its name.
signalEntry :: String -> Entry
signalEntry name = Entry "signal" [("name", quote name)]

-- | The signal that interrupted a drive: what the executable's handler
-- throws to it.
newtype Interruption = Interruption CInt
  deriving (Show)

instance Exception Interruption

-- | The last line: why the drive ended.
endEntry :: Finish Done -> Entry
endEntry f = Entry "end" $ case f of
  Finished ScheduleDone -> [("why", quote "schedule"), ("detail", "null")]
  Finished Stopped -> [("why", quote "stop"), ("detail", "null")]
  Interrupted e
    | signalled e -> [("why", quote "signal"), ("detail", "null")]
    | otherwise -> [("why", quote "error"), ("detail", string (inner e))]
  where
    -- the exception's own text, without the context GHC 9.10 appends
    inner (SomeException x) = displayException x
    signalled :: SomeException -> Bool
    signalled e = case fromException e of
      Just (Interruption _) -> True
      Nothing -> False

-- | The @outcome@ and @detail@ of a write.
outcomeFields :: Outcome 'Free -> [(String, String)]
outcomeFields o = case o of
  Sent Confirmed -> plain "confirmed"
  Sent (DidNotStick bytes) -> detailed "did-not-stick" (hex bytes)
  Sent Unconfirmed -> plain "unconfirmed"
  Sent (ReadBackFailed f) -> detailed "read-back-failed" (show f)
  Refused r -> detailed "refused" (show r)
  Failed f -> detailed "failed" (show f <> sent f)
  where
    plain name = [("outcome", quote name), ("detail", "null")]
    detailed name d = [("outcome", quote name), ("detail", string d)]
    sent (Unsent _) = "; nothing was sent"
    sent _ = "; the request went out and may have taken effect"

-- | A phase's keys, as the file names them, and their values, each written
-- as TOML and JSON both write it.
phaseKeys :: Phase -> [(String, String)]
phaseKeys p =
  surplus
    <> [("every", show n) | Just (Seconds n) <- [phaseEvery p]]
    <> [("target", number x) | Just x <- [phaseTarget p]]
    <> [("limit", number x) | Just x <- [phaseLimit p]]
    <> [end]
  where
    surplus = case phaseSurplus p of
      Constant x -> [("surplus", number x)]
      Export pv (Bounds lo hi) ->
        ("pv", number pv) : [("min", number x) | Just x <- [lo]] <> [("max", number x) | Just x <- [hi]]
    end = case phaseEnd p of
      AtStart -> ("until", quote "start")
      AtStop -> ("until", quote "stop")
      AfterStart (Seconds n) -> ("after-start", show n)
      For (Seconds n) -> ("for", show n)

object :: [(String, String)] -> String
object fields = "{" <> intercalate ", " (map field fields) <> "}"

-- | A target's address, as a JSON number.
address :: Target 'Free -> String
address t = let Address a = registerAddress (targetRegister t) in show a

value :: Value -> String
value v = case v of
  Real x -> number x
  Count n -> show n
  Code n -> show n
  Flag b -> if b then "true" else "false"
  DriveSignal NotDriven -> "-1"
  DriveSignal (Driven n) -> show n

-- | A number as JSON writes it; JSON has none for NaN or an infinity.
number :: Double -> String
number x
  | isNaN x || isInfinite x = "null"
  | otherwise = show x

-- | A JSON string, in ASCII.
string :: String -> String
string s = "\"" <> concatMap escape s <> "\""
  where
    escape c = case c of
      '"' -> "\\\""
      '\\' -> "\\\\"
      '\n' -> "\\n"
      '\r' -> "\\r"
      '\t' -> "\\t"
      _
        | isAscii c && not (isControl c) -> [c]
        | ord c < 0x10000 -> unit (ord c)
        | otherwise -> let n = ord c - 0x10000 in unit (0xd800 + n `div` 0x400) <> unit (0xdc00 + n `mod` 0x400)
    unit n = "\\u" <> pad (showHex n "")
    pad h = replicate (4 - length h) '0' <> h
