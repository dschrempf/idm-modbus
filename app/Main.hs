-- |
-- Module      :  Main
-- Description :  Print every readable register of a Navigator 2.0
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
module Main (main) where

import Data.List (intercalate)
import qualified Data.Text as T
import IDM.Modbus.TCP
import IDM.Navigator.Client
import IDM.Navigator.Register
import qualified IDM.Navigator.Table as Table
import System.Environment (getArgs, getProgName)
import System.Exit (exitFailure)
import Text.Printf (printf)

main :: IO ()
main = do
  args <- getArgs
  case args of
    [host] -> run host False
    [host, "--all"] -> run host True
    _ -> usage

usage :: IO ()
usage = do
  name <- getProgName
  putStrLn $ "usage: " <> name <> " HOST [--all]"
  putStrLn ""
  putStrLn "  Reads every register the reference machine answered for."
  putStrLn "  --all sweeps the whole parameter list instead, including"
  putStrLn "  addresses for hardware that is probably not fitted."
  exitFailure

run :: String -> Bool -> IO ()
run host sweepAll =
  withConnection (Host host) (Port 502) (UnitId 1) $ \conn -> do
    let regs = if sweepAll then Table.readable else Table.present
    samples <- readMany conn defaultPoll regs
    mapM_ (putStrLn . render) samples
    let fitted = length [() | s <- samples, Right (Measured _) <- [sampleResult s]]
        notFitted = length [() | s <- samples, Right NotFitted <- [sampleResult s]]
        failed = length [() | s <- samples, Left _ <- [sampleResult s]]
    printf "\n%d read, %d not fitted, %d refused\n" fitted notFitted failed

render :: Sample -> String
render s =
  intercalate
    "  "
    [ printf "%5d" addr,
      printf "%-2s" (accessText (registerAccess reg)),
      printf "%-8s" (persistenceText (registerPersistence reg)),
      printf "%18s" value,
      printf "%-4s" (maybe "" unitText (registerUnit reg)),
      T.unpack (registerName reg)
    ]
  where
    reg = sampleRegister s
    Address addr = registerAddress reg
    value = case sampleResult s of
      Left e -> failureText e
      Right NotFitted -> "--"
      Right (Measured v) -> case (v, sampleLabel s) of
        (Count n, Just l) -> show n <> " " <> T.unpack l
        (Count n, Nothing) -> show n
        (Real x, _) -> printf "%.2f" x
        (Flag b, _) -> if b then "on" else "off"

failureText :: Failure -> String
failureText f = case f of
  DeviceException IllegalDataAddress -> "(absent)"
  DeviceException e -> "(" <> show e <> ")"
  e -> "(" <> show e <> ")"

accessText :: Access -> String
accessText a = case a of
  ReadOnly -> "ro"
  ReadWrite -> "rw"
  WriteOnly -> "w"

persistenceText :: Persistence -> String
persistenceText p = case p of
  Eeprom -> "eeprom"
  Volatile -> ""

unitText :: Unit -> String
unitText u = case u of
  DegreeCelsius -> "°C"
  Percent -> "%"
  RelativeHumidity -> "%rF"
  Kilowatt -> "kW"
  KilowattHour -> "kWh"
  Hour -> "h"
  Bar -> "bar"
  Litre -> "l"
  LitrePerHour -> "l/h"
  Minute -> "min"
  Unitless -> ""
  UnknownUnit t -> T.unpack t
