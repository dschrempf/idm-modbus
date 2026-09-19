-- |
-- Module      :  IDM.Navigator.Client
-- Description :  Reading registers off a Navigator 2.0
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- Read support only. Writing is a separate problem: a third of the writable
-- registers wear out an EEPROM, and that deserves its own interface rather than
-- an extra argument here. See the changelog.
module IDM.Navigator.Client
  ( Poll (..),
    defaultPoll,
    Answer (..),
    Sample (..),
    readOne,
    readMany,
    probe,
  )
where

import Control.Concurrent (threadDelay)
import qualified Data.ByteString as B
import Data.Text (Text)
import IDM.Modbus.TCP
import IDM.Navigator.Register
import IDM.Navigator.Table (enumLabel)

-- | How to pace a sweep.
--
-- The Navigator answers one request at a time and is reported to stall when
-- several clients poll it hard, so a pause between requests is the default
-- rather than an optimisation to be discovered later.
data Poll = Poll
  { pollFunctionCode :: FunctionCode,
    -- | pause between requests
    pollIntervalMicroseconds :: Int
  }
  deriving (Show, Eq)

defaultPoll :: Poll
defaultPoll =
  Poll
    { pollFunctionCode = ReadHoldingRegisters,
      pollIntervalMicroseconds = 150000
    }

-- | A register that answered, at both levels: the number the machine sent, and
-- that number read the Navigator's way. A capture keeps the first, a reader
-- wants the second.
data Answer = Answer
  { -- | the bytes, in wire order
    answerRaw :: B.ByteString,
    answerWritten :: Value,
    answerReading :: Reading Value
  }

-- | One register and what it said.
data Sample = Sample
  { sampleRegister :: Register,
    sampleResult :: Either Failure Answer,
    -- | the enumeration label, where the manual gives one
    sampleLabel :: Maybe Text
  }

readOne :: Connection -> Poll -> Register -> IO Sample
readOne conn poll reg = do
  raw <- readRegisters conn (pollFunctionCode poll) addr (registerWidth (registerDatatype reg))
  let result = case raw of
        Left e -> Left e
        Right bytes -> case (asWritten reg bytes, decode reg bytes) of
          (Just written, Just v) -> Right (Answer bytes written v)
          _ -> Left (ShortResponse (B.length bytes))
  pure
    Sample
      { sampleRegister = reg,
        sampleResult = result,
        sampleLabel = case result of
          Right (Answer _ _ (Measured (Count n))) -> enumLabel addr n
          _ -> Nothing
      }
  where
    addr = registerAddress reg

-- | Read registers one after another, pausing in between.
--
-- Registers that cannot be read at all are skipped rather than reported as
-- failures: asking a write-only address for its value is a mistake in the
-- caller, not a fault of the machine.
readMany :: Connection -> Poll -> [Register] -> IO [Sample]
readMany conn poll = probe conn poll . filter (isReadable . registerAccess)

-- | Read every register given, whatever its access right.
--
-- This is what a capture does. An address the parameter list marks write-only
-- answers all the same, and recording that is the point of the capture; see
-- @doc\/verification-2026-09-19.md@.
probe :: Connection -> Poll -> [Register] -> IO [Sample]
probe conn poll = go
  where
    go [] = pure []
    go (r : rs) = do
      s <- readOne conn poll r
      threadDelay (pollIntervalMicroseconds poll)
      (s :) <$> go rs
