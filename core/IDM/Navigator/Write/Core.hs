{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}

-- |
-- Module      :  IDM.Navigator.Write.Core
-- Description :  What a write sends, and what it came to, apart from the socket
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- 'writeWith' writes any register it is given, at the cost it is given, so
-- the package does not expose it: @IDM.Navigator.Write@ applies it to a
-- target and a connection.
module IDM.Navigator.Write.Core
  ( Outcome (..),
    Confirmation (..),
    Requests (..),
    writeWith,
  )
where

import qualified Data.ByteString as B
import IDM.Modbus.TCP
import IDM.Navigator.Register

-- | What a write came to, by what it costs.
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

-- | The requests a write is made of.
data Requests m = Requests
  { requestRead :: Address -> Quantity -> m (Either Failure B.ByteString),
    requestWrite :: Write -> m (Either Failure ()),
    -- | between two requests, so as not to stall the controller
    requestPause :: m ()
  }

-- | Write a value to a register. At 'SEepromCycle, read it first, and send
-- nothing if it holds the value already. Read a readable register back.
writeWith :: forall m c. (Monad m) => Requests m -> SCost c -> Register -> Value -> m (Outcome c)
writeWith requests cost reg v = case encode reg v of
  Left r -> pure (Refused r)
  Right rs -> case cost of
    SFree -> send rs
    SEepromCycle ->
      readBack >>= \held -> case held of
        Left f -> pure (CheckFailed f)
        Right old
          | old == wire rs -> pure Unchanged
          | otherwise -> requestPause requests >> send rs
  where
    addr = registerAddress reg
    readBack = requestRead requests addr (registerWidth (registerDatatype reg))
    send :: Registers -> m (Outcome c)
    send rs =
      requestWrite requests (Write addr rs) >>= \sent -> case sent of
        Left f -> pure (Failed f)
        Right ()
          | isReadable (registerAccess reg) -> do
              requestPause requests
              Sent . confirm (wire rs) <$> readBack
          | otherwise -> pure (Sent Unconfirmed)
    confirm bytes held = case held of
      Left f -> ReadBackFailed f
      Right now
        | now == bytes -> Confirmed
        | otherwise -> DidNotStick now
