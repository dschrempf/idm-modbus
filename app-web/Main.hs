{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module      :  Main
-- Description :  Read a Navigator 2.0's web backend, and open or close the Fachmann level
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
module Main (main) where

import Control.Concurrent (threadDelay)
import Data.Aeson (Value (..), encode, object, (.=))
import qualified Data.ByteString.Lazy.Char8 as BL
import qualified Data.Text as T
import Data.Time (ZonedTime, defaultTimeLocale, formatTime, getZonedTime)
import GHC.Clock (getMonotonicTime)
import IDM.Modbus.TCP (Host (..))
import IDM.Navigator.Web
import IDM.Navigator.Web.Level
import IDM.Navigator.Web.Session
import System.Environment (getArgs, getProgName, lookupEnv)
import System.Exit (exitFailure)
import System.IO (BufferMode (..), hPutStrLn, hSetBuffering, stderr, stdout)
import Text.Printf (printf)
import Text.Read (readMaybe)

data Mode
  = -- | the user level, the controller's clock, the notices standing
    Report
  | -- | settings, read for a person
    Show [SettingId]
  | -- | the capture format of @captures\/navigator-2.0-webwatch-*.jsonl@
    Watch Period [SettingId]
  | Enter
  | Leave

-- | Seconds from the start of one round of a watch to the start of the next.
newtype Period = Period Int

-- | Where the PIN comes from, so that it stays out of the shell history and
-- the process list.
pinVariable :: String
pinVariable = "IDM_PIN"

main :: IO ()
main = do
  args <- getArgs
  (host, mode) <- case args of
    (h : rest) -> (,) (Host h) <$> modeArg rest
    [] -> usage
  pin <- lookupEnv pinVariable >>= maybe (die (pinVariable <> " is not set")) (pure . Pin)
  run host pin mode

modeArg :: [String] -> IO Mode
modeArg args = case args of
  ["--status"] -> pure Report
  ("--show" : ids@(_ : _)) -> Show <$> traverse settingArg ids
  ("--watch" : period : ids@(_ : _)) -> Watch <$> periodArg period <*> traverse settingArg ids
  ["--enter-fachmann"] -> pure Enter
  ["--leave-fachmann"] -> pure Leave
  _ -> usage

periodArg :: String -> IO Period
periodArg a = case readMaybe a of
  Just n | n > 0 -> pure (Period n)
  _ -> die (a <> ": not a positive whole number of seconds")

settingArg :: String -> IO SettingId
settingArg a = case readMaybe a :: Maybe Int of
  Just _ -> pure (SettingId (T.pack a))
  Nothing -> die (a <> ": not a setting id")

usage :: IO a
usage = do
  name <- getProgName
  putStrLn $ "usage: " <> name <> " HOST --status"
  putStrLn $ "       " <> name <> " HOST --show SETTING..."
  putStrLn $ "       " <> name <> " HOST --watch SECONDS SETTING..."
  putStrLn $ "       " <> name <> " HOST --enter-fachmann | --leave-fachmann"
  putStrLn ""
  putStrLn $ "  " <> pinVariable <> " holds the PIN of the web interface."
  putStrLn "  --status prints the user level, the controller's clock and the"
  putStrLn "  notices standing. --show reads settings by the id the settings"
  putStrLn "  tree gives them, e.g. 4768 for the sensor values."
  putStrLn "  --watch asks the given settings every SECONDS until interrupted,"
  putStrLn "  and prints a line per request: the request, the local time it was"
  putStrLn "  asked, and the responses, verbatim but for what names the machine."
  putStrLn "  --enter-fachmann sends the code of the controller's clock;"
  putStrLn "  --leave-fachmann acknowledges the notice that level raises. The"
  putStrLn "  level holds, for the display as well, until it is left or for"
  putStrLn "  sixty minutes from the entry."
  exitFailure

run :: Host -> Pin -> Mode -> IO ()
run host pin mode = case mode of
  Watch period ids -> watch host pin period ids
  _ -> withSession defaultPace host pin (session mode) >>= either (die . show) pure
  where
    session m s = case m of
      Report -> do
        st <- askStatus s >>= orDie
        printf "user level  %s\nclock       %s\nprotocol    %d\n" (levelText (statusUserLevel st)) (show (statusClock st)) (statusProtocol st)
        standing <- askNotifications s >>= orDie
        mapM_ (\n -> printf "notice      %s %s\n" (codeText (notificationCode n)) (notificationText n)) standing
      Show ids -> mapM_ (\i -> askSetting s i >>= orDie >>= putStr . renderSetting) ids
      Enter -> enterFachmann s >>= orDie >>= reportChange Fachmann
      Leave -> leaveFachmann s >>= orDie >>= reportChange Customer
      Watch _ _ -> pure ()
    codeText (NotificationCode c) = c

reportChange :: UserLevel -> LevelChange -> IO ()
reportChange wanted c = do
  mapM_ (BL.putStrLn . encode) (levelResponses c)
  printf "user level  %s -> %s\n" (levelText (levelBefore c)) (levelText (levelAfter c))
  if levelAfter c == wanted then pure () else die "the level did not change"

renderSetting :: Setting -> String
renderSetting st = header <> body (settingValue st)
  where
    SettingId i = settingId st
    header = printf "%s %s%s\n" i (settingName st) (maybe "" (\(ParameterId p) -> " " <> T.unpack p) (settingParameter st))
    body v = case v of
      SettingFloat x -> printf "  %s\n" (show x)
      SettingInt n -> printf "  %d\n" n
      SettingBool b -> printf "  %s\n" (show b)
      SettingChoice (ChoiceIndex n) -> printf "  choice %d\n" n
      SettingChoice (ChoiceKey k) -> printf "  choice %s\n" k
      SettingInfo rows -> concatMap row rows
      -- the whole detail, so a type can be read before it has a parser
      SettingOther kind whole -> printf "  (type %s, not read)\n  %s\n" kind (BL.unpack (encode whole))
    row r = case r of
      InfoReading d l x u -> printf "  %-9s %-40s %10s %s\n" (maybe "" T.unpack d) l (infoText x) u
      InfoCells cs -> "  " <> T.unpack (T.intercalate " | " cs) <> "\n"
    infoText (InfoNumber x) = show x
    infoText (InfoText t) = T.unpack t

levelText :: UserLevel -> String
levelText l = case l of
  Customer -> "Kunde (0)"
  Fachmann -> "Fachmann (2)"
  OtherLevel n -> show n

-- | Ask the same settings round after round, a line per request, until
-- interrupted.
--
-- A lost connection is opened again at the next round. Each request it cost is
-- still a line, with an @error@, so the gap is in the capture.
watch :: Host -> Pin -> Period -> [SettingId] -> IO ()
watch host pin (Period seconds) ids = do
  hSetBuffering stdout LineBuffering
  -- a PIN that is refused now will be refused at every round
  first <- open defaultPace host pin
  case first of
    Left e@(NotAuthorized _) -> die (show e)
    Left e -> complain (show e) >> getMonotonicTime >>= go Nothing
    Right s -> getMonotonicTime >>= go (Just s)
  where
    go s due = do
      now <- getMonotonicTime
      threadDelay (round (max 0 (due - now) * 1e6))
      s' <- maybe reopen (pure . Just) s >>= sweep ids
      -- a round that overran starts the next at once, without catching up
      getMonotonicTime >>= go s' . max (due + fromIntegral seconds)
    reopen = open defaultPace host pin >>= either (\e -> Nothing <$ complain (show e)) (pure . Just)
    sweep [] s = pure s
    sweep (i : is) Nothing = getZonedTime >>= \t -> line t i (Left "not connected") >> sweep is Nothing
    sweep (i : is) (Just s) = do
      t <- getZonedTime
      r <- ask s (SettingDetail i)
      case r of
        Right ms -> line t i (Right ms) >> sweep is (Just s)
        Left e -> do
          complain (show e)
          line t i (Left (show e))
          close s
          sweep is Nothing
    line t i r = BL.putStrLn (encode (watchLine t i r))
    complain = hPutStrLn stderr

-- | A line of a watch: an entry of a @webapi@ capture, with the time to the
-- millisecond, and what went wrong if nothing came back.
watchLine :: ZonedTime -> SettingId -> Either String [Value] -> Value
watchLine t i r =
  object
    [ "request" .= queryJSON (SettingDetail i),
      "captured" .= formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%S%3Q%Ez" t,
      "responses" .= either (const []) id r,
      "error" .= either Just (const Nothing) r
    ]

orDie :: Either Failure a -> IO a
orDie = either (die . show) pure

die :: String -> IO a
die m = hPutStrLn stderr m >> exitFailure
