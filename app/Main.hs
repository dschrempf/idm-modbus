-- |
-- Module      :  Main
-- Description :  Read the registers of a Navigator 10, once or round after round
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
module Main (main) where

import Control.Concurrent (threadDelay)
import Control.Exception (IOException, try)
import qualified Data.ByteString as B
import Data.List (intercalate)
import qualified Data.Map.Strict as M
import qualified Data.Text as T
import Data.Time (ZonedTime, defaultTimeLocale, formatTime, getZonedTime)
import Data.Word (Word8)
import GHC.Clock (getMonotonicTime)
import IDM.Modbus.TCP
import IDM.Navigator.Client
import IDM.Navigator.Register
import IDM.Navigator.Software (ModbusVersion (..), mismatchText, modbusVersionText)
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

-- | Seconds from the start of one round of a watch to the start of the next.
newtype Period = Period Int

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
    putStrLn (capture s (map (\sample -> fields (sampleRegister sample) (Returned (sampleResult sample))) samples))
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
--
-- The parameter list is in @data\/navigator-10-registers.tsv@ and is not
-- repeated here, so that a correction to the transcription cannot leave the
-- capture saying something else. The value is the number as written, not as
-- the Navigator means it: a capture that already applied the sentinel rule
-- could not be the evidence for it.
capture :: Session -> [[(String, String)]] -> String
capture s entries =
  "{\n"
    <> field ("software", software (Just s))
    <> ",\n"
    <> field ("entries", "[\n" <> intercalate ",\n" (map entry entries) <> "\n]")
    <> "\n}"

-- | The version a session read, as a capture records it: like a read, with
-- the three numbers where it answered. A read made on no session has none.
software :: Maybe Session -> String
software Nothing = "null"
software (Just s) =
  "{" <> intercalate ", " (map field (status <> parts)) <> "}"
  where
    o = Returned (sessionSoftware s)
    status = [("status", quote (statusText o)), ("exception", maybe "null" show (refusal o))]
    parts = case sessionSoftware s of
      Right v -> [("major", show (modbusMajor v)), ("minor", show (modbusMinor v)), ("patch", show (modbusPatch v))]
      Left _ -> []

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
  [ ("address", show a),
    ("quantity", show (quantityCount q)),
    ("status", quote (statusText o)),
    ("exception", maybe "null" show (refusal o)),
    ("raw", either (const "null") (if Table.readsMyIdm (Address a) q then const redactedJSON else quote . hex) r)
  ]
  where
    o = Returned r

-- | What became of a read: what the machine returned, or nothing, because
-- there was no connection to ask on.
data Outcome a
  = Returned (Either Failure a)
  | Unanswered

fields :: Register -> Outcome Answer -> [(String, String)]
fields reg o =
  [ ("address", show addr),
    ("status", quote (statusText o)),
    ("exception", maybe "null" show (refusal o)),
    ("raw", maybe "null" (hidden . quote . hex . answerRaw) answer),
    ("value", maybe "null" (hidden . number . answerWritten) answer)
  ]
  where
    Address addr = registerAddress reg
    hidden = if namesMachine reg then const redactedJSON else id
    answer = case o of
      Returned (Right a) -> Just a
      _ -> Nothing

-- | Whether a read of the register takes in the myiDM identifier.
namesMachine :: Register -> Bool
namesMachine reg = Table.readsMyIdm (registerAddress reg) (registerWidth (registerDatatype reg))

-- | The marker that stands for what was read, where it names the machine.
redactedJSON :: String
redactedJSON = quote (T.unpack redacted)

field :: (String, String) -> String
field (key, value) = quote key <> ": " <> value

-- | Why an address holds no value: the machine refused it, or the read itself
-- went wrong, which says nothing about the address.
statusText :: Outcome a -> String
statusText o = case o of
  Returned (Right _) -> "ok"
  Returned (Left (DeviceException _)) -> "exception"
  _ -> "error"

-- | The Modbus exception code behind a refusal. An unfitted option answers 2,
-- @IllegalDataAddress@, and the capture is where that is shown.
refusal :: Outcome a -> Maybe Word8
refusal o = case o of
  Returned (Left (DeviceException e)) -> Just (exceptionByte e)
  _ -> Nothing

-- | Read the same registers round after round, a line per read, until
-- interrupted.
--
-- A lost connection is opened again at the next round, so that a stall does
-- not end a run left to watch a charge. Each read it cost is still a line, with
-- status @error@, so the gap is in the capture rather than only on stderr.
-- Every line carries the software of the session it was read on, which a new
-- connection reads anew.
watch :: IO Session -> Period -> [Register] -> IO ()
watch opening (Period seconds) regs = do
  hSetBuffering stdout LineBuffering
  getMonotonicTime >>= go Nothing
  where
    go session due = do
      now <- getMonotonicTime
      threadDelay (round (max 0 (due - now) * 1e6))
      session' <- maybe reopen (pure . Just) session >>= sweep regs
      -- a round that overran starts the next at once, without catching up
      getMonotonicTime >>= go session' . max (due + fromIntegral seconds)
    reopen = do
      r <- try opening
      case r of
        Right s -> Just s <$ warn s
        Left e -> Nothing <$ complain (show (e :: IOException))
    sweep [] session = pure session
    sweep (r : rs) Nothing = emit r Unanswered >> sweep rs Nothing
    sweep (r : rs) (Just s) = do
      t <- getZonedTime
      sample <- readOne s r
      putStrLn (watchLine t (Just s) r (Returned (sampleResult sample)))
      case sampleResult sample of
        Left (Ended why) -> lose why
        Left (Unsent why) -> lose why
        _ -> do
          threadDelay (pollIntervalMicroseconds (sessionPoll s))
          sweep rs (Just s)
      where
        lose why = do
          complain (endingText why)
          close s
          sweep rs Nothing
    emit r o = getZonedTime >>= \t -> putStrLn (watchLine t Nothing r o)
    complain = hPutStrLn stderr

watchLine :: ZonedTime -> Maybe Session -> Register -> Outcome Answer -> String
watchLine t s reg o =
  "{" <> intercalate ", " (map field (("time", quote (stamp t)) : ("software", software s) : fields reg o)) <> "}"
  where
    stamp = formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%S%3Q%Ez"

-- 'Code', 'Flag' and 'DriveSignal' are what 'decode' makes of a word;
-- 'asWritten' applies no convention, so the capture only ever sees the first
-- two.
number :: Value -> String
number v = case v of
  Real x -> show x
  Count n -> show n
  Code n -> show n
  Flag b -> if b then "true" else "false"
  DriveSignal NotDriven -> "-1"
  DriveSignal (Driven n) -> show n

quote :: String -> String
quote t = "\"" <> t <> "\""

hex :: B.ByteString -> String
hex = concatMap (printf "%02x") . B.unpack

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
