-- |
-- Module      :  Main
-- Description :  Read the registers of a Navigator 10, once or round after round
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
module Main (main) where

import Control.Concurrent (threadDelay)
import qualified Data.ByteString as B
import Data.List (intercalate)
import qualified Data.Map.Strict as M
import qualified Data.Text as T
import IDM.Modbus.TCP
import IDM.Navigator.Capture
import IDM.Navigator.Client
import IDM.Navigator.Register
import IDM.Navigator.Rounds (Period (..), RoundEventOn (..), need, rounds)
import IDM.Navigator.Software (mismatchText, modbusVersionText)
import qualified IDM.Navigator.Table as Table
import IDM.Navigator.Web (redacted)
import System.Environment (getArgs, getProgName)
import System.Exit (exitFailure)
import System.IO (BufferMode (..), hPutStrLn, hSetBuffering, stderr, stdout)
import Text.Printf (printf)
import Text.Read (readMaybe)

-- | What a run produces.
data Mode
  = -- | a line per register, for a person
    Report Scope
  | -- | the capture format of @captures\/navigator-10-scan-*.json@
    Capture
  | -- | the capture format of @captures\/navigator-10-watch-*.jsonl@: the
    -- same registers, round after round, until interrupted
    Watch Period [Register]
  | -- | the capture format of @captures\/navigator-10-widths-*.json@: how
    -- wide the registers at addresses the parameter list does not name are
    Widths [Address]

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
    (host : "--watch" : period : addrs@(_ : _)) ->
      case Watch <$> periodArg period <*> traverse registerArg addrs of
        Right mode -> run host mode
        Left e -> hPutStrLn stderr e >> exitFailure
    (host : "--widths" : addrs@(_ : _)) ->
      case traverse addressArg addrs of
        Right as -> run host (Widths as)
        Left e -> hPutStrLn stderr e >> exitFailure
    _ -> usage

periodArg :: String -> Either String Period
periodArg a = case readMaybe a of
  Just n | n > 0 -> Right (Period n)
  _ -> Left (a <> ": not a positive whole number of seconds")

registerArg :: String -> Either String Register
registerArg a = case readMaybe a :: Maybe Integer of
  Just n
    | n >= 0,
      n <= 65535,
      Just r <- M.lookup (Address (fromInteger n)) Table.byAddress ->
        if isReadable (registerAccess r)
          then Right r
          else Left (a <> ": write-only")
  _ -> Left (a <> ": not an address in the parameter list")

-- | Any address; the one after it is read too, so the last cannot be 65535.
addressArg :: String -> Either String Address
addressArg a = case readMaybe a :: Maybe Integer of
  Just n | n >= 0, n < 65535 -> Right (Address (fromInteger n))
  _ -> Left (a <> ": not an address below 65535")

usage :: IO ()
usage = do
  name <- getProgName
  putStrLn $ "usage: " <> name <> " HOST [--all | --json]"
  putStrLn $ "       " <> name <> " HOST --watch SECONDS ADDRESS..."
  putStrLn $ "       " <> name <> " HOST --widths ADDRESS..."
  putStrLn ""
  putStrLn "  Reads every register the reference machine answered for."
  putStrLn "  --all sweeps the whole parameter list instead, including"
  putStrLn "  addresses for hardware that is probably not fitted."
  putStrLn "  --json sweeps every address, write-only ones included, and"
  putStrLn "  prints what the machine answered as a capture: address,"
  putStrLn "  status, the exception code behind a refusal, the bytes, and"
  putStrLn "  the number they spell. Nothing the parameter list already"
  putStrLn "  says is repeated there."
  putStrLn "  --watch reads the given addresses every SECONDS until"
  putStrLn "  interrupted, and prints a line per read in the same format,"
  putStrLn "  stamped with the local time the read was asked."
  putStrLn "  --widths reads each address as one register and as two, and"
  putStrLn "  the address after it as one, whether or not the parameter"
  putStrLn "  list names it, and prints what the machine answered."
  putStrLn "  The myiDM identifier names the machine, and no output shows it:"
  putStrLn "  a read that takes in one of its registers prints <redacted>."
  putStrLn "  Each connection first reads the controller's software, which"
  putStrLn "  every capture records. Where it is not the software the table"
  putStrLn "  describes, a warning on stderr names both."
  exitFailure

run :: String -> Mode -> IO ()
run host mode = case mode of
  Report scope -> connected $ \s -> do
    warn s
    samples <- readMany s (registers scope)
    mapM_ (putStrLn . render) samples
    let readings = [answerReading a | sample <- samples, Right a <- [sampleResult sample]]
    printf
      "\n%d read, %d no value, %d perhaps no value, %d refused\n"
      (length [() | Measured _ <- readings])
      (length [() | NoValue <- readings])
      (length [() | NoValueOr _ <- readings])
      (length samples - length readings)
  Capture -> connected $ \s -> do
    warn s
    samples <- probe s Table.navigator10
    putStrLn (capture s (map (\sample -> readFields (sampleRegister sample) (Just (sampleResult sample))) samples))
  Watch period regs -> watch (open defaultPatience defaultPoll (Host host) port unit) period regs
  Widths addrs -> connected $ \s -> do
    warn s
    answers <- mapM (widths (sessionConnection s)) addrs
    putStrLn (capture s (map widthEntry (concat answers)))
  where
    connected = withSession defaultPatience defaultPoll (Host host) port unit
    port = Port 502
    unit = UnitId 1
    registers Fitted = Table.present
    registers Documented = Table.readable

render :: Sample -> String
render s =
  intercalate
    "  "
    [ printf "%5d" addr,
      printf "%-5s" (accessText (registerAccess reg)),
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
      Right _ | namesMachine reg -> T.unpack redacted
      Right a -> case answerReading a of
        NoValue -> "--"
        NoValueOr v -> "-- or " <> shown v
        Measured v -> shown v
    shown v = case (v, sampleLabel s) of
      (Count n, _) -> show n
      (Code n, Just l) -> show n <> " " <> T.unpack l
      (Code n, Nothing) -> show n
      (Real x, _) -> printf "%.2f" x
      (Flag b, _) -> if b then "on" else "off"
      (DriveSignal NotDriven, _) -> "not driven"
      (DriveSignal (Driven n), _) -> show n

-- | On the terminal, both versions, where the session read another software
-- than the table describes.
warn :: Session -> IO ()
warn s =
  either
    (hPutStrLn stderr . ("warning: " <>) . T.unpack . mismatchText (T.pack . show) modbusVersionText Table.navigator10Software)
    (const (pure ()))
    (writable s)

-- | A capture: the software the session read, and the entries.
capture :: Session -> [[(String, String)]] -> String
capture s entries =
  "{\n"
    <> field ("software", software (Just (sessionSoftware s)))
    <> ",\n"
    <> field ("entries", "[\n" <> intercalate ",\n" (map entry entries) <> "\n]")
    <> "\n}"

entry :: [(String, String)] -> String
entry fs = " {\n" <> intercalate ",\n" (map (("  " <>) . field) fs) <> "\n }"

-- | One read of a width probe: an address, how many registers were asked for
-- from it, and what came back.
data WidthRead = WidthRead Address Quantity (Either Failure B.ByteString)

-- | What tells one register from two: a value two registers wide answers when
-- asked for two, while the address inside it refuses on its own. A register
-- followed by another answers for two as well, which is why the address after
-- it is read too.
widths :: Connection -> Address -> IO [WidthRead]
widths conn a@(Address n) =
  mapM
    (\(at, q) -> WidthRead at q <$> readRegisters conn ReadHoldingRegisters at q <* pause)
    [(a, singleRegister), (a, registerPair), (Address (n + 1), singleRegister)]
  where
    pause = threadDelay (pollIntervalMicroseconds defaultPoll)

-- | Bytes and nothing else: no datatype is known to spell them as a number.
widthEntry :: WidthRead -> [(String, String)]
widthEntry (WidthRead (Address a) q r) =
  [("address", show a), ("quantity", show (quantityCount q))]
    <> statusFields (Just r)
    <> [("raw", either (const "null") (if Table.readsMyIdm (Address a) q then const redactedJSON else quote . hex) r)]

-- | Read the same registers round after round, a line per read, until
-- interrupted.
--
-- A lost connection is opened again at the next round, so that a stall does
-- not end a run left to watch a charge. Each read it cost is still a line, with
-- status @error@, so the gap is in the capture rather than only on stderr.
-- Every line carries the software of the session it was read on, which a new
-- connection reads anew. A line is printed as its read is made.
watch :: IO Session -> Period -> [Register] -> IO ()
watch opening period regs = do
  hSetBuffering stdout LineBuffering
  rounds opening report period [need regs (const (pure ()))]
  where
    report e = case e of
      ReadDone a -> putStrLn (watchLine a)
      Opened s -> warn s
      NotOpened why -> hPutStrLn stderr (T.unpack why)
      Dropped why -> hPutStrLn stderr (endingText why)

endingText :: Ending -> String
endingText e = case e of
  NoAnswer -> "no answer in time"
  UnexpectedTransaction (TransactionId t) -> "an answer to another request, transaction " <> show t
  Malformed frame -> "a malformed frame, " <> hex frame
  ConnectionClosed -> "connection closed"
  Lost why -> why

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
  Supplied -> "rw/ro"

persistenceText :: Persistence -> String
persistenceText p = case p of
  Eeprom -> "eeprom"
  Volatile -> ""
  UnknownPersistence -> "?"

unitText :: Unit -> String
unitText u = case u of
  DegreeCelsius -> "°C"
  Percent -> "%"
  RelativeHumidity -> "%rF"
  Kilowatt -> "kW"
  KilowattHour -> "kWh"
  Hour -> "h"
  Bar -> "bar"
  Liter -> "l"
  LiterPerHour -> "l/h"
  LiterPerMinute -> "l/min"
  Minute -> "min"
  EuroPerMegawattHour -> "€/MWh"
  UnknownUnit t -> T.unpack t
