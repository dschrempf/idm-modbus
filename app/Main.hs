-- |
-- Module      :  Main
-- Description :  Print every readable register of a Navigator 2.0
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
module Main (main) where

import qualified Data.ByteString as B
import Data.List (intercalate)
import qualified Data.Text as T
import Data.Word (Word8)
import IDM.Modbus.TCP
import IDM.Navigator.Client
import IDM.Navigator.Register
import qualified IDM.Navigator.Table as Table
import System.Environment (getArgs, getProgName)
import System.Exit (exitFailure)
import Text.Printf (printf)

-- | What a run produces.
data Mode
  = -- | a line per register, for a person
    Report Scope
  | -- | the capture format of @data\/navigator-2.0-scan-*.json@
    Capture

-- | Which registers to ask.
data Scope
  = -- | those the reference machine answered for
    Fitted
  | -- | every readable address in the parameter list
    Documented

main :: IO ()
main = do
  args <- getArgs
  case args of
    [host] -> run host (Report Fitted)
    [host, "--all"] -> run host (Report Documented)
    [host, "--json"] -> run host Capture
    _ -> usage

usage :: IO ()
usage = do
  name <- getProgName
  putStrLn $ "usage: " <> name <> " HOST [--all | --json]"
  putStrLn ""
  putStrLn "  Reads every register the reference machine answered for."
  putStrLn "  --all sweeps the whole parameter list instead, including"
  putStrLn "  addresses for hardware that is probably not fitted."
  putStrLn "  --json sweeps every address, write-only ones included, and"
  putStrLn "  prints what the machine answered as a capture: address,"
  putStrLn "  status, the exception code behind a refusal, the bytes, and"
  putStrLn "  the number they spell. Nothing the parameter list already"
  putStrLn "  says is repeated there."
  exitFailure

run :: String -> Mode -> IO ()
run host mode =
  withConnection (Host host) (Port 502) (UnitId 1) $ \conn -> case mode of
    Report scope -> do
      samples <- readMany conn defaultPoll (registers scope)
      mapM_ (putStrLn . render) samples
      let readings = [answerReading a | s <- samples, Right a <- [sampleResult s]]
          fitted = length [() | Measured _ <- readings]
          notFitted = length [() | NotFitted <- readings]
      printf
        "\n%d read, %d not fitted, %d refused\n"
        fitted
        notFitted
        (length samples - length readings)
    Capture -> do
      samples <- probe conn defaultPoll Table.navigator20
      putStrLn (capture samples)
  where
    registers Fitted = Table.present
    registers Documented = Table.readable

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
      Right a -> case answerReading a of
        NotFitted -> "--"
        Measured v -> case (v, sampleLabel s) of
          (Count n, Just l) -> show n <> " " <> T.unpack l
          (Count n, Nothing) -> show n
          (Real x, _) -> printf "%.2f" x
          (Flag b, _) -> if b then "on" else "off"

-- | The capture: what the machine answered and nothing else.
--
-- The parameter list is in @data\/navigator-2.0-registers.tsv@ and is not
-- repeated here, so that a correction to the transcription cannot leave the
-- capture saying something else. The value is the number as written, not as
-- the Navigator means it: a capture that already applied the sentinel rule
-- could not be the evidence for it.
capture :: [Sample] -> String
capture samples = "[\n" <> intercalate ",\n" (map entry samples) <> "\n]"

entry :: Sample -> String
entry s = " {\n" <> intercalate ",\n" (map field fields) <> "\n }"
  where
    field (key, value) = "  " <> quote key <> ": " <> value
    fields =
      [ ("address", show addr),
        ("status", quote (statusText (sampleResult s))),
        ("exception", maybe "null" show (refusal (sampleResult s))),
        ("raw", maybe "null" (quote . hex . answerRaw) answer),
        ("value", maybe "null" (number . answerWritten) answer)
      ]
    Address addr = registerAddress (sampleRegister s)
    answer = either (const Nothing) Just (sampleResult s)

-- | Why an address holds no value: the machine refused it, or the read itself
-- went wrong, which says nothing about the address.
statusText :: Either Failure Answer -> String
statusText r = case r of
  Right _ -> "ok"
  Left (DeviceException _) -> "exception"
  Left _ -> "error"

-- | The Modbus exception code behind a refusal. An unfitted option answers 2,
-- @IllegalDataAddress@, and the capture is where that is shown.
refusal :: Either Failure Answer -> Maybe Word8
refusal r = case r of
  Left (DeviceException e) -> Just (exceptionByte e)
  _ -> Nothing

number :: Value -> String
number v = case v of
  Real x -> show x
  Count n -> show n
  Flag b -> if b then "true" else "false"

quote :: String -> String
quote t = "\"" <> t <> "\""

hex :: B.ByteString -> String
hex = concatMap (printf "%02x") . B.unpack

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
