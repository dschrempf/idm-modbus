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
      length Table.navigator20 == 497
    ),
    ( "addresses are unique",
      all ((== 1) . length) (group (sort (map registerAddress Table.navigator20)))
    ),
    ( "every register has a name",
      all (not . T.null . registerName) Table.navigator20
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
    ( "a float arrives low word first",
      -- 0x41ab4a89 is 21.41; the machine sends 4a89 41ab
      decodeAt 1000 (B.pack [0x4a, 0x89, 0x41, 0xab]) `approximately` 21.41
    ),
    ( "minus one is not a temperature",
      -- the documented sentinel for an unfitted sensor
      decodeRaw 1000 (B.pack [0x00, 0x00, 0xbf, 0x80]) == Just NotFitted
    ),
    ( "an unsigned word carrying a temperature is signed",
      -- 65531 is the documented -5 degree bivalence point
      decodeRaw 1120 (B.pack [0xff, 0xfb]) == Just (Measured (Count (-5)))
    ),
    ( "an all-ones word is absence, not minus one",
      decodeRaw 1104 (B.pack [0xff, 0xff]) == Just NotFitted
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

wellOrdered :: Register -> Bool
wellOrdered r = case registerRange r of
  Just (Range lo hi) -> lo <= hi
  Nothing -> True
