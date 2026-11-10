-- |
-- Module      :  IDM.Navigator.Client
-- Description :  Reading registers off a Navigator 10
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- Reading only. Writing some registers wears out an EEPROM
-- ('registerPersistence'), and has its interface in "IDM.Navigator.Write".
--
-- A read goes through a 'Session', which reads the controller's software
-- when it opens, so that what was read can be said to have been read on it.
-- A write needs a 'Writable', which only a session on the software the table
-- describes gives.
module IDM.Navigator.Client
  ( Poll (..),
    defaultPoll,
    Session,
    sessionConnection,
    sessionPoll,
    sessionSoftware,
    open,
    close,
    withSession,
    Writable,
    writableSession,
    writable,
    Answer (..),
    Sample (..),
    sampleOf,
    readOne,
    readMany,
    probe,
  )
where

import Control.Concurrent (threadDelay)
import Control.Exception (bracket)
import qualified Data.ByteString as B
import Data.Text (Text)
import IDM.Modbus.TCP.Internal
import IDM.Navigator.Register
import IDM.Navigator.Software (Mismatch, ModbusVersion (..), checked, modbusAgreement)
import IDM.Navigator.Table (enumLabel, navigator10Software)

-- | How to pace a sweep.
--
-- The Navigator answers one request at a time and is reported to stall when
-- several clients poll it hard, so a pause between requests is the default
-- rather than an optimization to be discovered later.
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

-- | A connection, and the software the controller ran when it was made.
--
-- An update restarts the controller, which ends the connection, and every
-- later request on it fails unsent; so the version holds for as long as the
-- session can ask anything. A new connection is a new session, read anew.
data Session = Session
  { sessionConnection :: Connection,
    sessionPoll :: Poll,
    -- | why the version could not be read: 20.24-1574 lists none of its
    -- registers
    sessionSoftware :: Either Failure ModbusVersion
  }

-- | Connect and read the version, or throw what 'connect' throws. A version
-- that cannot be read leaves the session open for reads.
open :: Patience -> Poll -> Host -> Port -> UnitId -> IO Session
open patience poll host port unit = do
  conn <- connect patience host port unit
  Session conn poll <$> readSoftware conn poll

close :: Session -> IO ()
close = disconnect . sessionConnection

withSession :: Patience -> Poll -> Host -> Port -> UnitId -> (Session -> IO a) -> IO a
withSession patience poll host port unit = bracket (open patience poll host port unit) close

-- | Major, minor and patch, at 522, 524 and 526, each a register of its own:
-- asked for two, each refuses.
readSoftware :: Connection -> Poll -> IO (Either Failure ModbusVersion)
readSoftware conn poll = do
  major <- part 522
  minor <- part 524
  patch <- part 526
  pure (ModbusVersion <$> major <*> minor <*> patch)
  where
    part a = do
      r <- readRegisters conn (pollFunctionCode poll) (Address a) singleRegister
      case r of
        Left (Unsent _) -> pure ()
        _ -> threadDelay (pollIntervalMicroseconds poll)
      pure (r >>= word)
    word bytes = case B.unpack bytes of
      [hi, lo] -> Right (fromIntegral hi * 256 + fromIntegral lo)
      _ -> Left (ShortResponse (B.length bytes))

-- | A session on the software the table describes; see 'writable'.
newtype Writable = Writable {writableSession :: Session}

-- | The session, if it read the software the table describes, major, minor
-- and patch.
writable :: Session -> Either (Mismatch Failure ModbusVersion) Writable
writable s = Writable s <$ checked modbusAgreement navigator10Software (sessionSoftware s)

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
    -- | the label of a code, where the table gives one
    sampleLabel :: Maybe Text
  }

readOne :: Session -> Register -> IO Sample
readOne s reg =
  sampleOf reg
    <$> readRegisters (sessionConnection s) (pollFunctionCode (sessionPoll s)) (registerAddress reg) (registerWidth (registerDatatype reg))

-- | What a register said, from what its read returned: the bytes in wire
-- order, or the failure.
sampleOf :: Register -> Either Failure B.ByteString -> Sample
sampleOf reg raw =
  Sample
    { sampleRegister = reg,
      sampleResult = result,
      sampleLabel = case result of
        Right (Answer _ _ (Measured (Code n))) -> enumLabel (registerAddress reg) n
        _ -> Nothing
    }
  where
    result = case raw of
      Left e -> Left e
      Right bytes -> case (asWritten reg bytes, decode reg bytes) of
        (Just written, Just v) -> Right (Answer bytes written v)
        _ -> Left (ShortResponse (B.length bytes))

-- | Read registers one after another, pausing in between.
--
-- Registers that cannot be read at all are skipped rather than reported as
-- failures: asking a write-only address for its value is a mistake in the
-- caller, not a fault of the machine.
readMany :: Session -> [Register] -> IO [Sample]
readMany s = probe s . filter (isReadable . registerAccess)

-- | Read every register given, whatever its access right.
--
-- This is what a capture does. An address the parameter list marks write-only
-- answers all the same, and recording that is the point of the capture; see
-- @doc\/verification\/2026-09-19-scan.md@.
probe :: Session -> [Register] -> IO [Sample]
probe s = go
  where
    go [] = pure []
    go (r : rs) = do
      sample <- readOne s r
      case sampleResult sample of
        -- nothing was sent, so there is nothing to pace
        Left (Unsent _) -> pure ()
        _ -> threadDelay (pollIntervalMicroseconds (sessionPoll s))
      (sample :) <$> go rs
