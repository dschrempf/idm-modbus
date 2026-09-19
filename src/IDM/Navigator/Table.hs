{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

-- |
-- Module      :  IDM.Navigator.Table
-- Description :  The transcribed parameter list
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- The register table is data, not code. It lives in @data\/@ as a tab separated
-- file transcribed from the manufacturer's manual, is embedded at compile time,
-- and is parsed into 'Register' values here. There is one place to correct when
-- a new revision of the manual appears.
module IDM.Navigator.Table
  ( navigator20,
    navigator20Enums,
    byAddress,
    readable,
    present,
    enumLabel,
    ParseError (..),
  )
where

import qualified Data.ByteString as B
import Data.FileEmbed (embedFile)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import IDM.Modbus.TCP (Address (..))
import IDM.Navigator.Register

newtype ParseError = ParseError Text
  deriving (Show, Eq)

registerFile :: B.ByteString
registerFile = $(embedFile "data/navigator-2.0-registers.tsv")

enumFile :: B.ByteString
enumFile = $(embedFile "data/navigator-2.0-enums.tsv")

-- | Every register of the Navigator 2.0 parameter list, document 812170
-- revision 10, in address order.
navigator20 :: [Register]
navigator20 = mapMaybe parseRegister (tsvRows registerFile)

-- | Enumerated values, keyed by address and code.
--
-- The manual prints an encoding once for a family of addresses, so a circuit
-- other than A carries no entry even though it uses the same codes. See
-- @doc\/research.md@; resolving this is deliberately left to a later revision
-- rather than guessed at here.
navigator20Enums :: Map (Address, Int) Text
navigator20Enums = M.fromList (mapMaybe parseEnum (tsvRows enumFile))

byAddress :: Map Address Register
byAddress = M.fromList [(registerAddress r, r) | r <- navigator20]

-- | Registers that can be read at all.
readable :: [Register]
readable = filter (isReadable . registerAccess) navigator20

-- | Registers that are both readable and were observed on the reference
-- machine. This is the useful set to poll.
present :: [Register]
present = filter ((== Present) . registerPresence) readable

enumLabel :: Address -> Int -> Maybe Text
enumLabel addr code = M.lookup (addr, code) navigator20Enums

tsvRows :: B.ByteString -> [[Text]]
tsvRows = drop 1 . map (T.splitOn "\t") . T.lines . TE.decodeUtf8

parseRegister :: [Text] -> Maybe Register
parseRegister [addr, dtype, access, persistence, name, param, lo, hi, def, unit, presence] = do
  a <- Address <$> readMaybeT addr
  d <- parseDatatype dtype
  acc <- parseAccess access
  p <- parsePersistence persistence
  pr <- parsePresence presence
  pure
    Register
      { registerAddress = a,
        registerDatatype = d,
        registerAccess = acc,
        registerPersistence = p,
        registerName = name,
        registerParameter = nonEmpty param,
        registerRange = Range <$> readMaybeT lo <*> readMaybeT hi,
        registerDefault = readMaybeT def,
        registerUnit = parseUnit <$> nonEmpty unit,
        registerPresence = pr
      }
parseRegister _ = Nothing

parseEnum :: [Text] -> Maybe ((Address, Int), Text)
parseEnum [addr, code, label] = do
  a <- Address <$> readMaybeT addr
  c <- readMaybeT code
  pure ((a, c), label)
parseEnum _ = Nothing

parseDatatype :: Text -> Maybe Datatype
parseDatatype t = case t of
  "FLOAT" -> Just Float32
  "UCHAR" -> Just UChar
  "WORD" -> Just Word
  "BOOL" -> Just Boolean
  "DWORD" -> Just DWord
  _ -> Nothing

parseAccess :: Text -> Maybe Access
parseAccess t = case t of
  "RO" -> Just ReadOnly
  "RW" -> Just ReadWrite
  "W" -> Just WriteOnly
  "RW/RO" -> Just Supplied
  _ -> Nothing

parsePersistence :: Text -> Maybe Persistence
parsePersistence t = case t of
  "eeprom" -> Just Eeprom
  "volatile" -> Just Volatile
  _ -> Nothing

parsePresence :: Text -> Maybe Presence
parsePresence t = case t of
  "present" -> Just Present
  "absent" -> Just Absent
  "untested" -> Just Untested
  _ -> Nothing

parseUnit :: Text -> Unit
parseUnit t = case T.strip t of
  "°C" -> DegreeCelsius
  "%" -> Percent
  "%rF" -> RelativeHumidity
  "kW" -> Kilowatt
  "kWh" -> KilowattHour
  "h" -> Hour
  "bar" -> Bar
  "l" -> Litre
  "l/h" -> LitrePerHour
  "min" -> Minute
  "" -> Unitless
  other -> UnknownUnit other

nonEmpty :: Text -> Maybe Text
nonEmpty t = if T.null (T.strip t) then Nothing else Just (T.strip t)

readMaybeT :: (Read a) => Text -> Maybe a
readMaybeT t = case reads (T.unpack (T.strip t)) of
  [(v, "")] -> Just v
  _ -> Nothing
