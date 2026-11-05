{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}

-- |
-- Module      :  IDM.Navigator.Write
-- Description :  Writing a register of a Navigator 2.0, at a cost the type states
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- A write goes to a 'Target', whose type says what it costs. A starred
-- register of the parameter list is written to the controller's EEPROM,
-- rated at 300000 cycles; there 'write' reads first and sends nothing when the
-- register holds the value already, since the manual says the EEPROM is
-- written "bei Wertänderungen". A volatile write is always sent: several of
-- them, the PV surplus at 74 among them, are meant to be repeated.
--
-- A register that reads back what was written has stored it. Whether the
-- controller acts on it is another question, and for a register the manual
-- marks @RW\/RO@ it depends on a menu setting: the PV surplus is used only
-- where @PV008@ is "Gebäudeleittechnik/Smartfox". What the controller does
-- once repeated writes stop is not known for any register.
module IDM.Navigator.Write
  ( Outcome (..),
    Confirmation (..),
    write,
  )
where

import Control.Concurrent (threadDelay)
import qualified Data.ByteString as B
import Data.List.NonEmpty (NonEmpty (..))
import Data.Word (Word16)
import IDM.Modbus.TCP
import IDM.Navigator.Client (Poll (..))
import IDM.Navigator.Register
import IDM.Navigator.Target

-- | What 'write' came to, by what the write costs.
data Outcome (c :: Cost) where
  -- | the register held the value already; nothing was sent
  Unchanged :: Outcome 'EepromCycle
  -- | the write was acknowledged; at 'EepromCycle, one cycle was spent
  Sent :: Confirmation -> Outcome c
  -- | the value does not encode; nothing was sent
  Refused :: Refusal -> Outcome c
  -- | the read before an EEPROM write failed; nothing was sent
  CheckFailed :: Failure -> Outcome 'EepromCycle
  -- | the write failed. Unless the failure is 'Unsent', the request went
  -- out, and may have taken effect.
  Failed :: Failure -> Outcome c

deriving instance Show (Outcome c)

deriving instance Eq (Outcome c)

-- | What the register read after an acknowledged write.
data Confirmation
  = -- | the value written
    Confirmed
  | -- | another value, its bytes in wire order
    DidNotStick B.ByteString
  | -- | a write-only register, not read back
    Unconfirmed
  | ReadBackFailed Failure
  deriving (Show, Eq)

-- | Write a value to a target, pausing between requests as a sweep does.
write :: forall c. Connection -> Poll -> Target c -> Value -> IO (Outcome c)
write conn poll target v = case encode reg v of
  Left r -> pure (Refused r)
  Right ws -> case targetCost target of
    SFree -> send ws
    SEepromCycle ->
      readBack >>= \held -> case held of
        Left f -> pure (CheckFailed f)
        Right old
          | old == wire ws -> pure Unchanged
          | otherwise -> pause >> send ws
  where
    reg = targetRegister target
    addr = registerAddress reg
    readBack = readRegisters conn (pollFunctionCode poll) addr (registerWidth (registerDatatype reg))
    pause = threadDelay (pollIntervalMicroseconds poll)
    send :: NonEmpty Word16 -> IO (Outcome c)
    send ws =
      writeRegisters conn (request ws) >>= \sent -> case sent of
        Left f -> pure (Failed f)
        Right ()
          | isReadable (registerAccess reg) -> do
              pause
              Sent . confirm (wire ws) <$> readBack
          | otherwise -> pure (Sent Unconfirmed)
    request (w :| []) = WriteSingle addr w
    request ws = WriteMultiple addr ws
    confirm bytes held = case held of
      Left f -> ReadBackFailed f
      Right now
        | now == bytes -> Confirmed
        | otherwise -> DidNotStick now
