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
import System.Timeout (timeout)
import Text.Printf (printf)
import Text.Read (readMaybe)

-- | What a run produces.
data Mode
  = -- | a line per register, for a person
    Report Scope
  | -- | the capture format of @data\/navigator-2.0-scan-*.json@
    Capture
  | -- | the capture format of @captures\/navigator-2.0-watch-*.jsonl@: the
    -- same registers, round after round, until interrupted
    Watch Period [Register]

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

usage :: IO ()
usage = do
  name <- getProgName
  putStrLn $ "usage: " <> name <> " HOST [--all | --json]"
  putStrLn $ "       " <> name <> " HOST --watch SECONDS ADDRESS..."
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
  exitFailure

run :: String -> Mode -> IO ()
run host mode = case mode of
  Report scope -> connected $ \conn -> do
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
  Capture -> connected $ \conn -> do
    samples <- probe conn defaultPoll Table.navigator20
    putStrLn (capture samples)
  Watch period regs -> watch (connect (Host host) port unit) period regs
  where
    connected = withConnection (Host host) port unit
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
        NotFitted -> "--"
        Measured v -> case (v, sampleLabel s) of
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
capture samples = "[\n" <> intercalate ",\n" (map entry samples) <> "\n]"

entry :: Sample -> String
entry s =
  " {\n"
    <> intercalate ",\n" (map (("  " <>) . field) (fields (sampleRegister s) (Returned (sampleResult s))))
    <> "\n }"

-- | What became of a read: what the machine returned, or nothing, because no
-- answer came in time or there was no connection to ask on.
data Outcome
  = Returned (Either Failure Answer)
  | Unanswered

fields :: Register -> Outcome -> [(String, String)]
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
statusText :: Outcome -> String
statusText o = case o of
  Returned (Right _) -> "ok"
  Returned (Left (DeviceException _)) -> "exception"
  _ -> "error"

-- | The Modbus exception code behind a refusal. An unfitted option answers 2,
-- @IllegalDataAddress@, and the capture is where that is shown.
refusal :: Outcome -> Maybe Word8
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
      r <- try (timeout patienceMicroseconds opening)
      case r of
        Right (Just conn) -> pure (Just conn)
        Right Nothing -> Nothing <$ complain "connecting timed out"
        Left e -> Nothing <$ complain (show (e :: IOException))
    sweep [] conn = pure conn
    sweep (r : rs) Nothing = emit r Unanswered >> sweep rs Nothing
    sweep (r : rs) (Just conn) = do
      t <- getZonedTime
      result <- try (timeout patienceMicroseconds (readOne conn defaultPoll r))
      let lose why o = do
            complain why
            putStrLn (watchLine t r o)
            disconnect conn
            sweep rs Nothing
      case result of
        Right (Just s) -> case sampleResult s of
          Left ConnectionClosed -> lose "connection closed" (Returned (sampleResult s))
          _ -> do
            putStrLn (watchLine t r (Returned (sampleResult s)))
            threadDelay (pollIntervalMicroseconds defaultPoll)
            sweep rs (Just conn)
        Right Nothing -> lose "no answer in time" Unanswered
        Left e -> lose (show (e :: IOException)) Unanswered
    emit r o = getZonedTime >>= \t -> putStrLn (watchLine t r o)
    complain = hPutStrLn stderr

-- | How long a read or a connection attempt may take. The socket has no
-- timeout of its own, so without this a stalled Navigator hangs the run.
patienceMicroseconds :: Int
patienceMicroseconds = 5000000

watchLine :: ZonedTime -> Register -> Outcome -> String
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
