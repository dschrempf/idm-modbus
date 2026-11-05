{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DeriveLift #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE StandaloneDeriving #-}

-- |
-- Module      :  IDM.Navigator.Register
-- Description :  What a Navigator register is
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- The vocabulary of the manufacturer's parameter list, as types. Every
-- distinction the manual draws in prose or in a footnote is a constructor here,
-- so that a caller cannot silently ignore it. So is what a source other than
-- the manual leaves unstated.
module IDM.Navigator.Register
  ( Datatype (..),
    registerWidth,
    Access (..),
    isReadable,
    Persistence (..),
    Cost (..),
    costOf,
    SCost (..),
    Unit (..),
    Source (..),
    Range (..),
    Presence (..),
    Register (..),
    Reading (..),
    reading,
    Drive (..),
    Value (..),
    asWritten,
    decode,
    Refusal (..),
    encode,
    wire,
  )
where

import Data.Bits (shiftL, shiftR, (.&.), (.|.))
import qualified Data.ByteString as B
import Data.Int (Int16)
import Data.Text (Text)
import Data.Word (Word16, Word32)
import GHC.Float (castFloatToWord32, castWord32ToFloat, double2Float, float2Double)
import IDM.Modbus.TCP (Address, Quantity, Registers (..), registerPair, singleRegister)
import Language.Haskell.TH.Syntax (Lift)

-- | Datatype as printed in the parameter list, or as far as a read measured it
-- where the list does not name the address.
--
-- The names are the manufacturer's. 'DWord' occurs in neither revision 10
-- nor revision 12 of the Navigator 2.0 list but is kept so that a later
-- revision can be transcribed without changing this type.
data Datatype
  = -- | IEEE 754 single precision across two registers, low word first
    Float32
  | -- | one register, a byte by the manual's name, signed by the controller's
    -- reading
    UChar
  | -- | one register; signed as 'signedWord' says
    Word
  | -- | one register, 0 or 1
    Boolean
  | DWord
  | -- | one register of an encoding no source states. Read unsigned, with no
    -- sentinel claimed.
    OneRegister
  deriving (Show, Eq, Ord, Lift)

-- | How many 16-bit registers the datatype occupies.
registerWidth :: Datatype -> Quantity
registerWidth Float32 = registerPair
registerWidth DWord = registerPair
registerWidth UChar = singleRegister
registerWidth Word = singleRegister
registerWidth Boolean = singleRegister
registerWidth OneRegister = singleRegister

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
  deriving (Show, Eq, Ord, Lift)

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
  | -- | a register the manual does not list, so no star says either way; a
    -- writer must assume the EEPROM
    UnknownPersistence
  deriving (Show, Eq, Ord, Lift)

-- | What a write costs, as a kind: a target of a write carries it in its
-- type, so that code writing an EEPROM register says so in its signature.
data Cost
  = Free
  | -- | one of the EEPROM's 300000 cycles, where the value changes
    EepromCycle
  deriving (Show, Eq, Ord, Lift)

-- | The cost of writing a register of this persistence. Unknown is
-- 'EepromCycle' until measured.
costOf :: Persistence -> Cost
costOf Volatile = Free
costOf Eeprom = EepromCycle
costOf UnknownPersistence = EepromCycle

-- | The cost, as a value, for code that only learns it at run time.
data SCost (c :: Cost) where
  SFree :: SCost 'Free
  SEepromCycle :: SCost 'EepromCycle

deriving instance Show (SCost c)

data Unit
  = DegreeCelsius
  | Percent
  | RelativeHumidity
  | Kilowatt
  | KilowattHour
  | Hour
  | Bar
  | Liter
  | LiterPerHour
  | LiterPerMinute
  | Minute
  | -- | the electricity price at 1048
    EuroPerMegawattHour
  | -- | a unit string the transcription does not know yet
    UnknownUnit Text
  deriving (Show, Eq, Ord, Lift)

-- | Documented bounds for a writable register.
data Range = Range
  { rangeMinimum :: Double,
    rangeMaximum :: Double
  }
  deriving (Show, Eq, Lift)

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
  deriving (Show, Eq, Ord, Lift)

-- | Which document describes a register.
data Source
  = -- | the parameter list, document 812170
    Manual
  | -- | the controller's own list of the addresses it serves, the web page
    -- @N2_GLTMON@. It states a name, a unit and an access right, and nothing
    -- else; the datatype is measured. See @doc\/verification-2026-10-14-gltmon.md@.
    -- The parameter identifier is joined by hand, where moving a setting
    -- showed which register followed it; see
    -- @doc\/verification-2026-10-15-flow-temperature.md@.
    GltMonitor
  deriving (Show, Eq, Ord, Lift)

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
    registerSource :: Source,
    registerPresence :: Presence
  }
  deriving (Show, Eq, Lift)

-- | A register that holds no value answers with a datatype-specific sentinel.
-- That is not a measurement, and this type refuses to let it be mistaken for
-- one.
--
-- The sentinels are not documented. They were determined by reading every
-- address of a machine whose configuration is known; see
-- @doc\/verification-2026-09-19.md@.
data Reading a
  = -- | the sentinel, where no value the register may hold equals it. It says
    -- that the register holds no value, not why: an unfitted sensor answers
    -- it, and so do the fitted B33 and B34 at 1050 and 1052.
    NoValue
  | -- | the sentinel, where a value the register may hold equals it: no value,
    -- or this one. An outdoor temperature passes through -1 °C, and no
    -- documented range tells it from an unfitted sensor.
    NoValueOr a
  | Measured a
  deriving (Show, Eq, Functor)

-- | Eliminator for 'Reading'.
reading :: b -> (a -> b) -> (a -> b) -> Reading a -> b
reading none noneOr just r = case r of
  NoValue -> none
  NoValueOr a -> noneOr a
  Measured a -> just a

-- | How hard a pump is being driven.
--
-- The controller's scale, printed on its own service page: @-1@ the pump is
-- not being driven, @0@ it runs at its minimum speed, @100@ at its maximum.
-- 'NotDriven' and @'Driven' 0@ are therefore different states, and neither is
-- the absence of a pump: a fitted pump that nothing is calling for and a pump
-- that was never installed both answer @-1@. See
-- @doc\/verification-2026-09-20.md@.
data Drive
  = NotDriven
  | -- | per cent of the pump's speed range
    Driven Int
  deriving (Show, Eq, Ord)

data Value
  = Real Double
  | Count Int
  | Flag Bool
  | DriveSignal Drive
  deriving (Show, Eq)

-- | The number the machine sent, as the datatype alone describes it.
--
-- Two things about the wire format are easy to get wrong and are handled here.
-- A 32-bit float arrives low word first, against the usual Modbus habit. And a
-- @UCHAR@ occupies a whole register, which the controller reads as a signed
-- word: its own register page prints @fffe@ as -2. See
-- @doc\/verification-2026-10-15-web-app.md@.
--
-- None of the conventions the manual leaves out are applied: a sentinel is
-- still a -1 here, and a temperature-carrying @WORD@ is still unsigned. This
-- is what a capture records, so that the evidence for a convention does not
-- rest on the convention.
asWritten :: Register -> B.ByteString -> Maybe Value
asWritten reg bytes = case registerDatatype reg of
  Float32 -> withWords 2 $ \ws -> case ws of
    [lo, hi] -> Just (Real (float2Double (castWord32ToFloat (wide lo hi))))
    _ -> Nothing
  DWord -> withWords 2 $ \ws -> case ws of
    [lo, hi] -> Just (Count (fromIntegral (wide lo hi)))
    _ -> Nothing
  UChar -> withWords 1 $ \ws -> case ws of
    [w] -> Just (Count (fromIntegral (fromIntegral w :: Int16)))
    _ -> Nothing
  Word -> withWords 1 $ \ws -> case ws of
    [w] -> Just (Count (fromIntegral w))
    _ -> Nothing
  Boolean -> withWords 1 $ \ws -> case ws of
    [w] -> Just (Count (fromIntegral w))
    _ -> Nothing
  OneRegister -> withWords 1 $ \ws -> case ws of
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

-- | The conventions the parameter list does not state: the sentinel a
-- register without a value answers with, the sign of a @WORD@, and the 0 or 1
-- of a @BOOL@.
navigator :: Register -> Value -> Reading Value
navigator reg v = case (registerDatatype reg, v) of
  -- No @FLOAT@ documents a negative minimum, and most document none at all,
  -- so only a printed range can rule -1 out.
  (Float32, Real x)
    | x /= -1 -> Measured v
    | outOfRange x -> NoValue
    | otherwise -> NoValueOr v
  (DWord, Count n) -> sentinel (n == 0xFFFFFFFF) v
  -- -1 answers for an unfitted sensor, and -2 at 1714 and 1715, whose meaning
  -- is unknown
  (UChar, Count n) -> sentinel (n < 0) v
  (Boolean, Count n) -> sentinel (n >= 254) (Flag (n /= 0))
  (Word, Count n)
    | signedWord reg -> Measured (meaning (n - if n > 0x7FFF then 65536 else 0))
    | otherwise -> sentinel (n == 0xFFFF) v
  -- 'OneRegister' claims no sentinel; 'asWritten' pairs each other datatype
  -- with one constructor, so nothing else arises
  _ -> Measured v
  where
    sentinel isSentinel w = if isSentinel then NoValue else Measured w
    outOfRange x =
      maybe False (\r -> x < rangeMinimum r || x > rangeMaximum r) (registerRange reg)
    -- A signed percentage is a pump's control signal, and -1 is a state of it.
    meaning n
      | registerUnit reg == Just Percent =
          DriveSignal (if n < 0 then NotDriven else Driven n)
      | otherwise = Count n

-- | Why 'encode' refused a value. Nothing is sent for it.
data Refusal
  = -- | a value of another kind than the datatype holds
    Mismatch Datatype Value
  | -- | outside the documented range, as the register would hold it
    OutOfRange Range Double
  | -- | a whole number the datatype cannot hold
    Unrepresentable Datatype Integer
  | -- | not a number, or infinite as a @FLOAT@: 1e39 is
    NotFinite Double
  | -- | a register nothing may write
    NotWritable Access
  deriving (Show, Eq)

-- | The registers that write a value, as 'wire' sends them: the inverse of
-- 'asWritten', so a @FLOAT@ goes low word first and a @UCHAR@ or a signed
-- @WORD@ in two's complement. A @BOOL@ is written from a 'Flag', and a
-- pump's control signal from a 'DriveSignal'. A -1 is an ordinary value
-- here: what writing a sentinel means is not documented.
encode :: Register -> Value -> Either Refusal Registers
encode reg v = case (registerAccess reg, registerDatatype reg, v) of
  (ReadOnly, _, _) -> Left (NotWritable ReadOnly)
  (_, Float32, Real x)
    | isNaN f || isInfinite f -> Left (NotFinite x)
    | otherwise -> do
        let w = castFloatToWord32 f
        inRange (float2Double f)
        Right (Two (fromIntegral w) (fromIntegral (w `shiftR` 16)))
    where
      f = double2Float x
  (_, DWord, Count n) -> do
    w <- whole 0 0xFFFFFFFF n
    Right (Two (fromIntegral w) (fromIntegral (w `shiftR` 16)))
  (_, UChar, Count n) -> word16 <$> whole (-32768) 32767 n
  (_, Word, Count n)
    | signedWord reg -> word16 <$> whole (-32768) 32767 n
    | otherwise -> word16 <$> whole 0 65535 n
  (_, Word, DriveSignal d)
    | signedWord reg && registerUnit reg == Just Percent ->
        word16 <$> whole (-32768) 32767 (case d of NotDriven -> -1; Driven n -> n)
  (_, Boolean, Flag b) -> Right (word16 (if b then 1 else 0))
  (_, OneRegister, Count n) -> word16 <$> whole 0 65535 n
  (_, d, _) -> Left (Mismatch d v)
  where
    inRange x = case registerRange reg of
      Just r | x < rangeMinimum r || x > rangeMaximum r -> Left (OutOfRange r x)
      _ -> Right ()
    whole :: Integer -> Integer -> Int -> Either Refusal Integer
    whole lo hi n
      | i < lo || i > hi = Left (Unrepresentable (registerDatatype reg) i)
      | otherwise = i <$ inRange (fromIntegral n)
      where
        i = toInteger n
    word16 :: Integer -> Registers
    word16 i = One (fromIntegral (i .&. 0xFFFF))

-- | Whether a @WORD@ is two's complement. The manual's own minimum and
-- default decide the sign, and with it which words are reachable. A
-- bivalence point is documented down to -40, so it is two's complement and
-- 65535 is a value it may legitimately hold, not a sentinel. A pump's control
-- signal is documented from 0 with a default of -1, which a read-only
-- register holds as a state of the machine, so it is two's complement too. A
-- default of a register the building management system supplies is what it
-- holds before anything is supplied: the -1 of the battery level at 86 is
-- absence. Every other @WORD@ is documented from 0 up, leaving 65535 out of
-- range and free to mean absence.
signedWord :: Register -> Bool
signedWord reg = negativeMinimum || (registerAccess reg == ReadOnly && negativeDefault)
  where
    negativeMinimum = maybe False ((< 0) . rangeMinimum) (registerRange reg)
    negativeDefault = maybe False (< 0) (registerDefault reg)

-- | Registers as bytes in wire order, as a read returns them.
wire :: Registers -> B.ByteString
wire rs = B.pack (concatMap bytes (case rs of One v -> [v]; Two v w -> [v, w]))
  where
    bytes w = [fromIntegral (w `shiftR` 8), fromIntegral (w .&. 0xFF)]

toWords :: B.ByteString -> [Word16]
toWords bs
  | B.length bs < 2 = []
  | otherwise =
      let hi = B.index bs 0
          lo = B.index bs 1
       in (fromIntegral hi `shiftL` 8 .|. fromIntegral lo) : toWords (B.drop 2 bs)
