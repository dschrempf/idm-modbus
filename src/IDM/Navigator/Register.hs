{-# LANGUAGE DeriveFunctor #-}

-- |
-- Module      :  IDM.Navigator.Register
-- Description :  What a Navigator register is
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- The vocabulary of the manufacturer's parameter list, as types. Every
-- distinction the manual draws in prose or in a footnote is a constructor here,
-- so that a caller cannot silently ignore it.
module IDM.Navigator.Register
  ( Datatype (..),
    registerWidth,
    Access (..),
    isReadable,
    Persistence (..),
    Unit (..),
    Range (..),
    Presence (..),
    Register (..),
    Reading (..),
    reading,
    Value (..),
    asWritten,
    decode,
  )
where

import Data.Bits (shiftL, (.|.))
import qualified Data.ByteString as B
import Data.Text (Text)
import Data.Word (Word16, Word32)
import GHC.Float (castWord32ToFloat)
import IDM.Modbus.TCP (Address, Quantity (..))

-- | Datatype as printed in the parameter list.
--
-- The names are the manufacturer's. 'DWord' does not occur in revision 10 of
-- the Navigator 2.0 list but is kept so that a later revision can be
-- transcribed without changing this type.
data Datatype
  = -- | IEEE 754 single precision across two registers, low word first
    Float32
  | -- | one register, only the low byte carries the value
    UChar
  | -- | one register; signed where the unit is a temperature
    Word
  | -- | one register, 0 or 1
    Boolean
  | DWord
  deriving (Show, Eq, Ord)

-- | How many 16-bit registers the datatype occupies.
registerWidth :: Datatype -> Quantity
registerWidth Float32 = Quantity 2
registerWidth DWord = Quantity 2
registerWidth UChar = Quantity 1
registerWidth Word = Quantity 1
registerWidth Boolean = Quantity 1

-- | Access right. Write-only registers exist and reading them is not an error
-- worth reporting to a user, it is a mistake in the caller.
data Access
  = ReadOnly
  | ReadWrite
  | WriteOnly
  | -- | a value the building management system may supply to the heat pump,
    -- and may read back. Printed @RW\/RO@, which chapter 4.1 does not define;
    -- whether the pump uses what is written depends on a menu setting.
    Supplied
  deriving (Show, Eq, Ord)

isReadable :: Access -> Bool
isReadable WriteOnly = False
isReadable _ = True

-- | Whether writing the register wears out the controller.
--
-- The manual marks these with a star and warns of at most 300000 write cycles
-- before the EEPROM is destroyed. Keeping it in the type is the whole point:
-- an automation that nudges a setpoint every minute would exhaust a starred
-- register in about seven months.
data Persistence
  = Volatile
  | Eeprom
  deriving (Show, Eq, Ord)

data Unit
  = DegreeCelsius
  | Percent
  | RelativeHumidity
  | Kilowatt
  | KilowattHour
  | Hour
  | Bar
  | Litre
  | LitrePerHour
  | Minute
  | Unitless
  | -- | a unit string the transcription does not know yet
    UnknownUnit Text
  deriving (Show, Eq, Ord)

-- | Documented bounds for a writable register.
data Range = Range
  { rangeMinimum :: Double,
    rangeMaximum :: Double
  }
  deriving (Show, Eq)

-- | Whether the reference machine answered for this address.
--
-- The parameter list describes every option the Navigator supports, including
-- zone modules, solar and cascade. An address for absent hardware answers with
-- 'IDM.Modbus.TCP.IllegalDataAddress'. Recording what was observed keeps the
-- documented table and one machine's reality separate, rather than pretending
-- the table is wrong.
data Presence
  = Present
  | Absent
  | Untested
  deriving (Show, Eq, Ord)

data Register = Register
  { registerAddress :: Address,
    registerDatatype :: Datatype,
    registerAccess :: Access,
    registerPersistence :: Persistence,
    registerName :: Text,
    -- | identifier of the same parameter in the controller menu, e.g. @FW030@
    registerParameter :: Maybe Text,
    registerRange :: Maybe Range,
    registerDefault :: Maybe Double,
    registerUnit :: Maybe Unit,
    registerPresence :: Presence
  }
  deriving (Show, Eq)

-- | A register that reports hardware which is not fitted answers with a
-- datatype-specific sentinel. That is not a measurement, and this type refuses
-- to let it be mistaken for one.
--
-- The sentinels are not documented. They were determined by reading every
-- address of a machine whose configuration is known; see
-- @doc\/verification-2026-09-19.md@.
data Reading a
  = NotFitted
  | Measured a
  deriving (Show, Eq, Functor)

-- | Eliminator for 'Reading'.
reading :: b -> (a -> b) -> Reading a -> b
reading nothing just r = case r of
  NotFitted -> nothing
  Measured a -> just a

data Value
  = Real Double
  | Count Int
  | Flag Bool
  deriving (Show, Eq)

-- | The number the machine sent, as the datatype alone describes it.
--
-- Two things about the wire format are easy to get wrong and are handled here.
-- A 32-bit float arrives low word first, against the usual Modbus habit. And a
-- @UCHAR@ occupies a whole register of which only the low byte is meaningful.
--
-- None of the conventions the manual leaves out are applied: a sentinel is
-- still a -1 here, and a temperature-carrying @WORD@ is still unsigned. This
-- is what a capture records, so that the evidence for a convention does not
-- rest on the convention.
asWritten :: Register -> B.ByteString -> Maybe Value
asWritten reg bytes = case registerDatatype reg of
  Float32 -> withWords 2 $ \ws -> case ws of
    [lo, hi] -> Just (Real (realToFrac (castWord32ToFloat (wide lo hi))))
    _ -> Nothing
  DWord -> withWords 2 $ \ws -> case ws of
    [lo, hi] -> Just (Count (fromIntegral (wide lo hi)))
    _ -> Nothing
  UChar -> withWords 1 $ \ws -> case ws of
    [w] -> Just (Count (fromIntegral w `mod` 256))
    _ -> Nothing
  Word -> withWords 1 $ \ws -> case ws of
    [w] -> Just (Count (fromIntegral w))
    _ -> Nothing
  Boolean -> withWords 1 $ \ws -> case ws of
    [w] -> Just (Count (fromIntegral w))
    _ -> Nothing
  where
    wide lo hi = (fromIntegral hi `shiftL` 16) .|. fromIntegral lo :: Word32
    withWords n k
      | B.length bytes == 2 * n = k (toWords bytes)
      | otherwise = Nothing

-- | Read the bytes of a read the way the Navigator means them.
decode :: Register -> B.ByteString -> Maybe (Reading Value)
decode reg bytes = navigator reg <$> asWritten reg bytes

-- | The conventions the parameter list does not state: the sentinel an
-- unfitted sensor answers with, the sign of a temperature-carrying @WORD@, and
-- the 0 or 1 of a @BOOL@.
navigator :: Register -> Value -> Reading Value
navigator reg v = case (registerDatatype reg, v) of
  (Float32, Real x) -> sentinel (x == -1) v
  (DWord, Count n) -> sentinel (n == 0xFFFFFFFF) v
  (UChar, Count n) -> sentinel (n >= 254) v
  (Boolean, Count n) -> sentinel (n >= 254) (Flag (n /= 0))
  (Word, Count n) -> sentinel (n == 0xFFFF) (Count (signedIfTemperature n))
  -- 'asWritten' pairs each datatype with one constructor; nothing else arises
  _ -> Measured v
  where
    sentinel isSentinel w = if isSentinel then NotFitted else Measured w
    -- A @WORD@ carrying a temperature is two's complement: the bivalence
    -- points read 65531 and 65516 for the documented -5 and -20 degrees.
    signedIfTemperature n
      | registerUnit reg == Just DegreeCelsius && n > 0x7FFF = n - 65536
      | otherwise = n

toWords :: B.ByteString -> [Word16]
toWords bs
  | B.length bs < 2 = []
  | otherwise =
      let hi = B.index bs 0
          lo = B.index bs 1
       in (fromIntegral hi `shiftL` 8 .|. fromIntegral lo) : toWords (B.drop 2 bs)
