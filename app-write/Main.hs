{-# LANGUAGE GADTs #-}

-- |
-- Module      :  Main
-- Description :  Write one register of a Navigator 2.0
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
module Main (main) where

import qualified Data.ByteString as B
import qualified Data.Text as T
import IDM.Modbus.TCP
import IDM.Navigator.Client (defaultPoll)
import IDM.Navigator.Register
import IDM.Navigator.Target
import IDM.Navigator.Write
import System.Environment (getArgs, getProgName)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)
import Text.Printf (printf)
import Text.Read (readMaybe)

-- | Whether the caller has said that a write may cost an EEPROM cycle.
data Consent = Consented | NotConsented

main :: IO ()
main = do
  args <- getArgs
  case args of
    [host, addr, value] -> run host addr value NotConsented
    [host, addr, value, "--eeprom"] -> run host addr value Consented
    _ -> usage

usage :: IO ()
usage = do
  name <- getProgName
  putStrLn $ "usage: " <> name <> " HOST ADDRESS VALUE [--eeprom]"
  putStrLn ""
  putStrLn "  Writes VALUE to the register at ADDRESS and reads it back."
  putStrLn "  Only the targets of data/navigator-2.0-targets.tsv may be"
  putStrLn "  written. A register stored in the EEPROM is read first and"
  putStrLn "  left alone if it holds VALUE already; otherwise it is written"
  putStrLn "  only with --eeprom, since a write that changes it costs one of"
  putStrLn "  the controller's 300000 EEPROM cycles."
  putStrLn ""
  putStrLn "  Targets:"
  mapM_ (\(SomeTarget t) -> putStrLn ("    " <> describe (targetRegister t) <> costText (targetCost t))) targets
  exitFailure
  where
    costText :: SCost c -> String
    costText SFree = ""
    costText SEepromCycle = " (EEPROM)"

run :: String -> String -> String -> Consent -> IO ()
run host addrArg valueArg consent = case find addrArg of
  Nothing -> die (addrArg <> ": not a target; see the usage for the list")
  Just (SomeTarget t) -> do
    let reg = targetRegister t
    v <- maybe (die (valueArg <> ": not a value of " <> describe reg)) pure (parseValue reg valueArg)
    case (targetCost t, consent) of
      (SEepromCycle, NotConsented) ->
        die $
          describe reg
            <> " is stored in EEPROM; a write that changes it costs one of"
            <> " 300000 cycles. Repeat with --eeprom."
      _ -> do
        outcome <- withConnection defaultPatience (Host host) (Port 502) (UnitId 1) $ \conn ->
          write conn defaultPoll t v
        let (line, ok) = report reg (targetCost t) v outcome
        putStrLn (describe reg <> ": " <> line)
        if ok then pure () else exitFailure
  where
    find a = case readMaybe a :: Maybe Integer of
      Just n
        | n >= 0 && n <= 65535 ->
            case [s | s@(SomeTarget t) <- targets, registerAddress (targetRegister t) == Address (fromInteger n)] of
              s : _ -> Just s
              [] -> Nothing
      _ -> Nothing

-- | A value as the register's datatype reads it: a number for a @FLOAT@, a
-- whole number for the integral datatypes, 0 or 1 for a @BOOL@.
parseValue :: Register -> String -> Maybe Value
parseValue reg s = case registerDatatype reg of
  Float32 -> Real <$> readMaybe s
  Boolean -> case s of
    "0" -> Just (Flag False)
    "1" -> Just (Flag True)
    _ -> Nothing
  _ -> Count <$> readMaybe s

-- | A line for a person, and whether the write did what was asked.
report :: Register -> SCost c -> Value -> Outcome c -> (String, Bool)
report reg cost v outcome = case outcome of
  Unchanged -> ("holds " <> number v <> " already; nothing sent, no EEPROM cycle spent", True)
  Sent c -> case c of
    Confirmed -> ("wrote " <> number v <> spent <> "; reads it back", True)
    DidNotStick bytes -> ("wrote " <> number v <> spent <> "; reads back " <> heldText bytes, False)
    Unconfirmed -> ("wrote " <> number v <> spent <> "; write-only, not read back", True)
    ReadBackFailed f -> ("wrote " <> number v <> spent <> "; reading it back failed: " <> show f, False)
  Refused r -> ("refused, nothing sent: " <> show r, False)
  CheckFailed f -> ("reading it before the write failed, nothing sent: " <> show f, False)
  Failed f -> ("the write failed: " <> show f <> sentText f, False)
  where
    spent = case cost of
      SFree -> ""
      SEepromCycle -> ", one EEPROM cycle spent"
    heldText bytes = maybe (hex bytes) number (asWritten reg bytes) <> " (" <> hex bytes <> ")"
    sentText (Unsent _) = "; nothing was sent"
    sentText _ = "; the request went out and may have taken effect"

describe :: Register -> String
describe reg =
  let Address a = registerAddress reg
   in show a <> " " <> T.unpack (registerName reg)

number :: Value -> String
number v = case v of
  Real x -> show x
  Count n -> show n
  Flag b -> if b then "1" else "0"
  DriveSignal NotDriven -> "-1"
  DriveSignal (Driven n) -> show n

hex :: B.ByteString -> String
hex = concatMap (printf "%02x") . B.unpack

die :: String -> IO a
die msg = hPutStrLn stderr msg >> exitFailure
