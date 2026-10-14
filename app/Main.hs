-- |
-- Module      :  Main
-- Description :  Read the registers of a Navigator 2.0, once or round after round
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
import qualified IDM.Navigator.Table as Table
import System.Environment (getArgs, getProgName)
import System.Exit (exitFailure)
import System.IO (BufferMode (..), hPutStrLn, hSetBuffering, stderr, stdout)
import Text.Printf (printf)
import Text.Read (readMaybe)

-- | What a run produces.
data Mode
  = -- | a line per register, for a person
    Report Scope
  | -- | the capture format of @captures\/navigator-2.0-scan-*.json@
    Capture
  | -- | the capture format of @captures\/navigator-2.0-watch-*.jsonl@: the
    -- same registers, round after round, until interrupted
    Watch Period [Register]
  | -- | the capture format of @captures\/navigator-2.0-widths-*.json@: how
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
  exitFailure

run :: String -> Mode -> IO ()
run host mode = case mode of
  Report scope -> connected $ \conn -> do
    samples <- readMany conn defaultPoll (registers scope)
    mapM_ (putStrLn . render) samples
    let readings = [answerReading a | s <- samples, Right a <- [sampleResult s]]
    printf
      "\n%d read, %d no value, %d perhaps no value, %d refused\n"
      (length [() | Measured _ <- readings])
      (length [() | NoValue <- readings])
      (length [() | NoValueOr _ <- readings])
      (length samples - length readings)
  Capture -> connected $ \conn -> do
    samples <- probe conn defaultPoll Table.navigator20
    putStrLn (capture samples)
  Watch period regs -> watch (connect defaultPatience (Host host) port unit) period regs
  Widths addrs -> connected $ \conn -> do
    answers <- mapM (widths conn) addrs
    putStrLn (list (map widthEntry (concat answers)))
  where
    connected = withConnection defaultPatience (Host host) port unit
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
      Right a -> case answerReading a of
        NoValue -> "--"
        NoValueOr v -> "-- or " <> shown v
        Measured v -> shown v
    shown v = case (v, sampleLabel s) of
      (Count n, Just l) -> show n <> " " <> T.unpack l
      (Count n, Nothing) -> show n
      (Real x, _) -> printf "%.2f" x
      (Flag b, _) -> if b then "on" else "off"
      (DriveSignal NotDriven, _) -> "not driven"
      (DriveSignal (Driven n), _) -> show n

-- | The capture: what the machine answered and nothing else.
--
-- The parameter list is in @data\/navigator-2.0-registers.tsv@ and is not
-- repeated here, so that a correction to the transcription cannot leave the
-- capture saying something else. The value is the number as written, not as
-- the Navigator means it: a capture that already applied the sentinel rule
-- could not be the evidence for it.
capture :: [Sample] -> String
capture = list . map (\s -> fields (sampleRegister s) (Returned (sampleResult s)))

list :: [[(String, String)]] -> String
list entries = "[\n" <> intercalate ",\n" (map entry entries) <> "\n]"

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
    [(a, Quantity 1), (a, Quantity 2), (Address (n + 1), Quantity 1)]
  where
    pause = threadDelay (pollIntervalMicroseconds defaultPoll)

-- | Bytes and nothing else: no datatype is known to spell them as a number.
widthEntry :: WidthRead -> [(String, String)]
widthEntry (WidthRead (Address a) (Quantity q) r) =
  [ ("address", show a),
    ("quantity", show q),
    ("status", quote (statusText o)),
    ("exception", maybe "null" show (refusal o)),
    ("raw", either (const "null") (quote . hex) r)
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
    ("raw", maybe "null" (quote . hex . answerRaw) answer),
    ("value", maybe "null" (number . answerWritten) answer)
  ]
  where
    Address addr = registerAddress reg
    answer = case o of
      Returned (Right a) -> Just a
      _ -> Nothing

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
watch :: IO Connection -> Period -> [Register] -> IO ()
watch opening (Period seconds) regs = do
  hSetBuffering stdout LineBuffering
  getMonotonicTime >>= go Nothing
  where
    go conn due = do
      now <- getMonotonicTime
      threadDelay (round (max 0 (due - now) * 1e6))
      conn' <- maybe open (pure . Just) conn >>= sweep regs
      -- a round that overran starts the next at once, without catching up
      getMonotonicTime >>= go conn' . max (due + fromIntegral seconds)
    open = do
      r <- try opening
      case r of
        Right conn -> pure (Just conn)
        Left e -> Nothing <$ complain (show (e :: IOException))
    sweep [] conn = pure conn
    sweep (r : rs) Nothing = emit r Unanswered >> sweep rs Nothing
    sweep (r : rs) (Just conn) = do
      t <- getZonedTime
      s <- readOne conn defaultPoll r
      putStrLn (watchLine t r (Returned (sampleResult s)))
      case sampleResult s of
        Left (Ended why) -> lose why
        Left (Unsent why) -> lose why
        _ -> do
          threadDelay (pollIntervalMicroseconds defaultPoll)
          sweep rs (Just conn)
      where
        lose why = do
          complain (endingText why)
          disconnect conn
          sweep rs Nothing
    emit r o = getZonedTime >>= \t -> putStrLn (watchLine t r o)
    complain = hPutStrLn stderr

watchLine :: ZonedTime -> Register -> Outcome Answer -> String
watchLine t reg o =
  "{" <> intercalate ", " (map field (("time", quote (stamp t)) : fields reg o)) <> "}"
  where
    stamp = formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%S%3Q%Ez"

-- 'Flag' and 'DriveSignal' are what 'decode' makes of a word; 'asWritten'
-- applies no convention, so the capture only ever sees the first two.
number :: Value -> String
number v = case v of
  Real x -> show x
  Count n -> show n
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
  UnknownUnit t -> T.unpack t
