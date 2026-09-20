-- |
-- Module      :  Main
-- Description :  Checks that do not need a heat pump
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
module Main (main) where

import qualified Data.ByteString as B
import Data.List (group, sort)
import qualified Data.Text as T
import IDM.Modbus.TCP (Address (..), Quantity (..))
import IDM.Navigator.Register
import qualified IDM.Navigator.Table as Table
import System.Exit (exitFailure)

main :: IO ()
main = do
  results <- mapM check checks
  if and results then putStrLn "all checks passed" else exitFailure

check :: (String, Bool) -> IO Bool
check (name, ok) = do
  putStrLn $ (if ok then "ok    " else "FAIL  ") <> name
  pure ok

checks :: [(String, Bool)]
checks =
  [ ( "the table parses to the number of rows in the file",
      length Table.navigator20 == 663
    ),
    ( "addresses are unique",
      all ((== 1) . length) (group (sort (map registerAddress Table.navigator20)))
    ),
    ( "every register has a name",
      all (not . T.null . registerName) Table.navigator20
    ),
    ( "a name carries its sensor designator whole",
      all (balanced . registerName) Table.navigator20
    ),
    ( "a documented range is well ordered",
      all wellOrdered Table.navigator20
    ),
    ( "write-only registers are not offered for reading",
      all ((/= WriteOnly) . registerAccess) Table.readable
    ),
    ( "enumerations resolve",
      Table.enumLabel (Address 1005) 4 == Just (T.pack "Nur Warmwasser")
    ),
    ( "an enumeration printed once reaches every circuit it describes",
      -- the list prints the operating modes beside heating circuit A only
      Table.enumLabel (Address 1395) 1 == Just (T.pack "Zeitprogramm")
        && Table.enumLabel (Address 1504) 0 == Just (T.pack "Aus")
        && Table.enumLabel (Address 1103) 1 == Just (T.pack "Ein")
    ),
    ( "a float arrives low word first",
      -- 0x41ab4a89 is 21.41; the machine sends 4a89 41ab
      decodeAt 1000 (B.pack [0x4a, 0x89, 0x41, 0xab]) `approximately` 21.41
    ),
    ( "minus one is not a temperature",
      -- the documented sentinel for an unfitted sensor
      decodeRaw 1000 (B.pack [0x00, 0x00, 0xbf, 0x80]) == Just NotFitted
    ),
    ( "a word documented below zero is signed",
      -- 65531 is the documented -5 degree bivalence point
      decodeRaw 1120 (B.pack [0xff, 0xfb]) == Just (Measured (Count (-5)))
    ),
    ( "a bivalence point may be set to minus one",
      -- documented down to -90, so all ones is in range and cannot be absence
      decodeRaw 1120 (B.pack [0xff, 0xff]) == Just (Measured (Count (-1)))
    ),
    ( "a capture records the number, not the reading",
      asWritten (register 1120) (B.pack [0xff, 0xfb]) == Just (Count 65531)
        && asWritten (register 1000) (B.pack [0x00, 0x00, 0xbf, 0x80]) == Just (Real (-1))
    ),
    ( "a pump that is not driven is not a pump that is missing",
      -- the list documents the control signal from -1, so all ones is -1
      decodeRaw 1104 (B.pack [0xff, 0xff]) == Just (Measured (DriveSignal NotDriven))
    ),
    ( "a pump at its minimum speed is not a pump at rest",
      decodeRaw 1104 (B.pack [0x00, 0x00]) == Just (Measured (DriveSignal (Driven 0)))
        && decodeRaw 1104 (B.pack [0x00, 0x64]) == Just (Measured (DriveSignal (Driven 100)))
    ),
    ( "a word documented from zero up keeps the sentinel",
      -- the circulation pump runs or does not; a percentage it is not
      decodeRaw 1118 (B.pack [0xff, 0xff]) == Just NotFitted
        -- and a battery charge level is not a pump, for all it is in per cent
        && decodeRaw 86 (B.pack [0xff, 0xff]) == Just NotFitted
    ),
    ( "a byte-sized register reads only its low byte",
      decodeRaw 1032 (B.pack [0x00, 0x2e]) == Just (Measured (Count 46))
    ),
    ( "widths match the datatypes",
      registerWidth Float32 == Quantity 2 && registerWidth UChar == Quantity 1
    ),
    ( "presence was recorded for every register",
      all ((/= Untested) . registerPresence) Table.navigator20
    )
  ]

register :: Int -> Register
register a = case filter ((== Address (fromIntegral a)) . registerAddress) Table.navigator20 of
  (r : _) -> r
  [] -> error ("no register " <> show a)

decodeRaw :: Int -> B.ByteString -> Maybe (Reading Value)
decodeRaw a = decode (register a)

decodeAt :: Int -> B.ByteString -> Maybe Double
decodeAt a bs = case decodeRaw a bs of
  Just (Measured (Real x)) -> Just x
  _ -> Nothing

approximately :: Maybe Double -> Double -> Bool
approximately (Just x) y = abs (x - y) < 0.01
approximately Nothing _ = False

-- | The parameter list prints a footnote marker exactly like the tail of a
-- sensor designator, so a transcription that confuses the two leaves
-- @Außentemperatur (B32)@ as @Außentemperatur (B3@.
balanced :: T.Text -> Bool
balanced t = T.count (T.pack "(") t == T.count (T.pack ")") t

wellOrdered :: Register -> Bool
wellOrdered r = case registerRange r of
  Just (Range lo hi) -> lo <= hi
  Nothing -> True
