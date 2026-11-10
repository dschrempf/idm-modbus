-- |
-- Module      :  IDM.Navigator.Capture
-- Description :  The lines a capture records of what the controller answered
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- The format of @captures\/navigator-10-watch-*.jsonl@, a line per read, and
-- the fields the other captures share with it.
--
-- The parameter list is in @data\/navigator-10-registers.tsv@ and is not
-- repeated here, so that a correction to the transcription cannot leave a
-- capture saying something else. The value is the number as written, not as
-- the Navigator means it: a capture that already applied the sentinel rule
-- could not be the evidence for it. What names the machine is redacted.
module IDM.Navigator.Capture
  ( -- * A watch
    watchLine,
    watchLineOn,

    -- * Fields
    stamp,
    software,
    readFields,
    statusFields,
    namesMachine,

    -- * JSON
    field,
    quote,
    hex,
    redactedJSON,
  )
where

import qualified Data.ByteString as B
import Data.List (intercalate)
import qualified Data.Text as T
import Data.Time (ZonedTime, defaultTimeLocale, formatTime)
import IDM.Modbus.TCP (Address (..), ExceptionCode, Failure (..), exceptionByte)
import IDM.Navigator.Client (Answer (..), Sample (..), sessionSoftware)
import IDM.Navigator.Register
import IDM.Navigator.Rounds (Asked, AskedOn (..))
import IDM.Navigator.Software (ModbusVersion (..))
import qualified IDM.Navigator.Table as Table
import IDM.Navigator.Web (redacted)
import Text.Printf (printf)

-- | The line of a read: its stamp, the software of the session it was asked
-- on, and what came back.
watchLine :: Asked -> String
watchLine = watchLineOn sessionSoftware

-- | 'watchLine' on any session, given the software it read.
watchLineOn :: (s -> Either Failure ModbusVersion) -> AskedOn s -> String
watchLineOn softwareOf a =
  "{"
    <> intercalate
      ", "
      ( map
          field
          ( ("time", quote (stamp (askedAt a)))
              : ("software", software (softwareOf <$> askedSession a))
              : readFields (askedRegister a) (sampleResult <$> askedSample a)
          )
      )
    <> "}"

-- | The local time a read was asked, to the millisecond, with its offset.
stamp :: ZonedTime -> String
stamp = formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%S%3Q%Ez"

-- | The version a session read, as a capture records it: like a read, with
-- the three numbers where it answered. A read made on no session has none.
software :: Maybe (Either Failure ModbusVersion) -> String
software Nothing = "null"
software (Just version) =
  "{" <> intercalate ", " (map field (statusFields (Just version) <> parts)) <> "}"
  where
    parts = case version of
      Right v -> [("major", show (modbusMajor v)), ("minor", show (modbusMinor v)), ("patch", show (modbusPatch v))]
      Left _ -> []

-- | A register and what its read returned, 'Nothing' where it was not asked.
readFields :: Register -> Maybe (Either Failure Answer) -> [(String, String)]
readFields reg result =
  [("address", show addr)]
    <> statusFields result
    <> [ ("raw", maybe "null" (hidden . quote . hex . answerRaw) answer),
         ("value", maybe "null" (hidden . number . answerWritten) answer)
       ]
  where
    Address addr = registerAddress reg
    hidden = if namesMachine reg then const redactedJSON else id
    answer = either (const Nothing) Just =<< result

-- | Why an address holds no value: the machine refused it, the status
-- @exception@, or the read itself went wrong, the status @error@, which says
-- nothing about the address. An unfitted option answers 2,
-- @IllegalDataAddress@, and the capture is where that is shown.
statusFields :: Maybe (Either Failure a) -> [(String, String)]
statusFields result =
  [ ("status", quote status),
    ("exception", maybe "null" (show . exceptionByte) refusal)
  ]
  where
    status = case result of
      Just (Right _) -> "ok"
      Just (Left (DeviceException _)) -> "exception"
      _ -> "error"
    refusal :: Maybe ExceptionCode
    refusal = case result of
      Just (Left (DeviceException e)) -> Just e
      _ -> Nothing

-- | Whether a read of the register takes in the myiDM identifier.
namesMachine :: Register -> Bool
namesMachine reg = Table.readsMyIdm (registerAddress reg) (registerWidth (registerDatatype reg))

-- | The marker that stands for what was read, where it names the machine.
redactedJSON :: String
redactedJSON = quote (T.unpack redacted)

field :: (String, String) -> String
field (key, value) = quote key <> ": " <> value

quote :: String -> String
quote t = "\"" <> t <> "\""

hex :: B.ByteString -> String
hex = concatMap (printf "%02x") . B.unpack

-- 'Code', 'Flag' and 'DriveSignal' are what 'decode' makes of a word;
-- 'asWritten' applies no convention, so the capture only ever sees the first
-- two.
number :: Value -> String
number v = case v of
  Real x -> show x
  Count n -> show n
  Code n -> show n
  Flag b -> if b then "true" else "false"
  DriveSignal NotDriven -> "-1"
  DriveSignal (Driven n) -> show n
