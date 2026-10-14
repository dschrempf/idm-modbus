{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module      :  IDM.Navigator.Table.Parse
-- Description :  Parsing the transcribed parameter list at compile time
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- The parsers live apart from "IDM.Navigator.Table" because a splice cannot
-- run a function of the module it splices into.
module IDM.Navigator.Table.Parse
  ( parsedFile,
    parseRegisters,
    parseEnums,
  )
where

import qualified Data.ByteString as B
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import IDM.Modbus.TCP (Address (..))
import IDM.Navigator.Register
import Language.Haskell.TH.Syntax (Code, Lift, Q, addDependentFile, joinCode, liftTyped, runIO)

-- | The file at a path relative to the package, parsed when the module that
-- splices it is compiled. A file that does not parse fails the build.
parsedFile :: (Lift a) => (B.ByteString -> Either String a) -> FilePath -> Code Q a
parsedFile parse path = joinCode $ do
  addDependentFile path
  bytes <- runIO (B.readFile path)
  either (fail . ((path <> ":") <>)) (pure . liftTyped) (parse bytes)

parseRegisters :: B.ByteString -> Either String [Register]
parseRegisters =
  tsv
    ["address", "datatype", "access", "persistence", "name", "parameter", "min", "max", "default", "unit", "source", "observed"]
    parseRegister

parseEnums :: B.ByteString -> Either String [((Address, Int), Text)]
parseEnums = tsv ["address", "code", "label"] parseEnum

-- | Rows after a header that must read as given; an error names the line.
tsv :: [Text] -> ([Text] -> Either String a) -> B.ByteString -> Either String [a]
tsv header row bytes = case zip [1 :: Int ..] (map (T.splitOn "\t") (T.lines (TE.decodeUtf8 bytes))) of
  (_, h) : rows
    | h == header -> traverse (\(n, cells) -> either (Left . ((show n <> ": ") <>)) Right (row cells)) rows
    | otherwise -> Left ("1: header " <> show h <> ", expected " <> show header)
  [] -> Left "1: no header"

parseRegister :: [Text] -> Either String Register
parseRegister [addr, dtype, access, persistence, name, param, lo, hi, def, unit, source, presence] = do
  a <- parseAddress addr
  d <- cell "datatype" parseDatatype dtype
  acc <- cell "access" parseAccess access
  p <- cell "persistence" parsePersistence persistence
  r <- parseRange lo hi
  df <- traverse (cell "default" readMaybeT) (nonEmpty def)
  s <- cell "source" parseSource source
  pr <- cell "observed" parsePresence presence
  pure
    Register
      { registerAddress = a,
        registerDatatype = d,
        registerAccess = acc,
        registerPersistence = p,
        registerName = name,
        registerParameter = nonEmpty param,
        registerRange = r,
        registerDefault = df,
        registerUnit = parseUnit <$> nonEmpty unit,
        registerSource = s,
        registerPresence = pr
      }
parseRegister cells = Left ("12 cells expected, found " <> show (length cells))

parseEnum :: [Text] -> Either String ((Address, Int), Text)
parseEnum [addr, code, label] = do
  a <- parseAddress addr
  c <- cell "code" readMaybeT code
  l <- maybe (Left "empty label") Right (nonEmpty label)
  pure ((a, c), l)
parseEnum cells = Left ("3 cells expected, found " <> show (length cells))

cell :: String -> (Text -> Maybe a) -> Text -> Either String a
cell column parse t = maybe (Left ("cannot read " <> column <> " " <> show t)) Right (parse t)

parseAddress :: Text -> Either String Address
parseAddress = cell "address" $ \t -> do
  n <- readMaybeT t :: Maybe Integer
  if 0 <= n && n <= 65535 then Just (Address (fromInteger n)) else Nothing

-- | A range is stated with both bounds or not at all.
parseRange :: Text -> Text -> Either String (Maybe Range)
parseRange lo hi = case (nonEmpty lo, nonEmpty hi) of
  (Nothing, Nothing) -> Right Nothing
  (Just l, Just h) -> Just <$> (Range <$> cell "min" readMaybeT l <*> cell "max" readMaybeT h)
  _ -> Left ("one bound of a range: " <> show (lo, hi))

parseDatatype :: Text -> Maybe Datatype
parseDatatype t = case t of
  "FLOAT" -> Just Float32
  "UCHAR" -> Just UChar
  "WORD" -> Just Word
  "BOOL" -> Just Boolean
  "DWORD" -> Just DWord
  "one-register" -> Just OneRegister
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
  "unknown" -> Just UnknownPersistence
  _ -> Nothing

parseSource :: Text -> Maybe Source
parseSource t = case t of
  "manual" -> Just Manual
  "gltmon" -> Just GltMonitor
  _ -> Nothing

parsePresence :: Text -> Maybe Presence
parsePresence t = case t of
  "present" -> Just Present
  "absent" -> Just Absent
  "untested" -> Just Untested
  _ -> Nothing

parseUnit :: Text -> Unit
parseUnit t = case t of
  "°C" -> DegreeCelsius
  "%" -> Percent
  "%rF" -> RelativeHumidity
  "kW" -> Kilowatt
  "kWh" -> KilowattHour
  "h" -> Hour
  "bar" -> Bar
  "l" -> Liter
  "l/h" -> LiterPerHour
  "l/min" -> LiterPerMinute
  "min" -> Minute
  other -> UnknownUnit other

nonEmpty :: Text -> Maybe Text
nonEmpty t = if T.null (T.strip t) then Nothing else Just (T.strip t)

readMaybeT :: (Read a) => Text -> Maybe a
readMaybeT t = case reads (T.unpack (T.strip t)) of
  [(v, "")] -> Just v
  _ -> Nothing
