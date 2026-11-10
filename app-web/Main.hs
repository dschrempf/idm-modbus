{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module      :  Main
-- Description :  Read a Navigator 10's web backend, and open or close the Fachmann level
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
module Main (main) where

import Control.Concurrent (ThreadId, myThreadId, threadDelay, throwTo)
import Control.Exception (AsyncException (UserInterrupt), finally)
import Control.Monad (unless, void)
import Data.Aeson (Value (..), encode, object, pairs, (.=))
import Data.Aeson.Encoding (encodingToLazyByteString)
import qualified Data.ByteString.Lazy.Char8 as BL
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef, writeIORef)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (ZonedTime, defaultTimeLocale, formatTime, getZonedTime)
import GHC.Clock (getMonotonicTime)
import IDM.Modbus.TCP (Host (..))
import IDM.Navigator.Software (Mismatch, WebVersion (..), mismatchText)
import IDM.Navigator.Table (navigator10Software)
import IDM.Navigator.Web
import IDM.Navigator.Web.Fachmann
import IDM.Navigator.Web.Level
import IDM.Navigator.Web.Session
import System.Environment (getArgs, getProgName, lookupEnv)
import System.Exit (ExitCode (..), exitFailure)
import System.IO (BufferMode (..), hPutStrLn, hSetBuffering, stderr, stdout)
import System.Posix.Signals (Handler (..), Signal, installHandler, sigINT, sigTERM)
import Text.Printf (printf)
import Text.Read (readMaybe)

data Mode
  = -- | the user level, the controller's clock, the notices standing
    Report
  | -- | settings, read for a person
    Show [SettingId]
  | -- | the capture format of @captures\/navigator-10-webwatch-*.jsonl@:
    -- a line per query of a round
    Watch Period [Query] Hold
  | Enter
  | Leave

-- | Seconds from the start of one round of a watch to the start of the next.
newtype Period = Period Int

-- | What a watch does about the user level.
data Hold
  = -- | nothing: it reads at whatever level the controller is at
    AsItIs
  | -- | it enters the Fachmann level, renews it, and leaves it on every exit
    HoldFachmann

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
  ("--watch" : period : rest) -> uncurry . Watch <$> periodArg period <*> watchArgs rest
  ["--enter-fachmann"] -> pure Enter
  ["--leave-fachmann"] -> pure Leave
  _ -> usage

periodArg :: String -> IO Period
periodArg a = case readMaybe a of
  Just n | n > 0 -> pure (Period n)
  _ -> die (a <> ": not a positive whole number of seconds")

-- | The reason is asked first in a round, and makes the settings optional.
watchArgs :: [String] -> IO ([Query], Hold)
watchArgs args = case args of
  ("--reason" : rest) -> (\(qs, h) -> (SystemOverview : qs, h)) <$> held True rest
  _ -> held False args
  where
    held optional rest = case rest of
      ("--fachmann" : ids) -> flip (,) HoldFachmann <$> settings optional ids
      _ -> flip (,) AsItIs <$> settings optional rest
    settings optional ids
      | null ids && not optional = usage
      | otherwise = traverse (fmap SettingDetail . settingArg) ids

settingArg :: String -> IO SettingId
settingArg a = case readMaybe a :: Maybe Int of
  -- the controller names a setting in its answer as it spells the id
  Just n -> pure (SettingId (T.pack (show n)))
  Nothing -> die (a <> ": not a setting id")

usage :: IO a
usage = do
  name <- getProgName
  putStrLn $ "usage: " <> name <> " HOST --status"
  putStrLn $ "       " <> name <> " HOST --show SETTING..."
  putStrLn $ "       " <> name <> " HOST --watch SECONDS [--reason] [--fachmann] SETTING..."
  putStrLn $ "       " <> name <> " HOST --enter-fachmann | --leave-fachmann"
  putStrLn ""
  putStrLn $ "  " <> pinVariable <> " holds the PIN of the web interface."
  putStrLn "  --status prints the user level, the controller's clock, the"
  putStrLn "  notices standing, and what the heat pump does and at whose"
  putStrLn "  request, by the keys the web interface translates. --show reads"
  putStrLn "  settings by the id the settings tree gives them, e.g. 4768 for the"
  putStrLn "  sensor values, and names the user level where it does not reach one."
  putStrLn "  --watch asks the given settings every SECONDS until interrupted,"
  putStrLn "  and prints a line per request: the request, the local time it was"
  putStrLn "  asked, and the responses, verbatim but for what names the machine."
  putStrLn "  --reason asks the system overview as well, first in every round;"
  putStrLn "  its heatpump holds the mode and the request's reason."
  putStrLn "  --fachmann reads the user level first in every round, enters the"
  putStrLn $ "  Fachmann level, renews it " <> show (round (renewAfterSeconds / 60) :: Int) <> " minutes from each entry, and leaves it"
  putStrLn "  on every exit; a line records each change of level. It gives up"
  putStrLn $ "  after " <> show tries <> " entries in a row that did not take, and reads on."
  putStrLn "  --enter-fachmann sends the code of the controller's clock, from"
  putStrLn "  Kunde only; --leave-fachmann acknowledges the notice that level"
  putStrLn "  raises. The level holds, for the display as well, until it is left"
  putStrLn "  or the controller ends it, sixty minutes from the entry."
  putStrLn "  Each session first reads the controller's software, which every"
  putStrLn "  mode prints and every line of a watch records. Where it is not the"
  putStrLn "  software the table describes, a read warns on stderr and the level"
  putStrLn "  is left as it is."
  exitFailure
  where
    Tries tries = maxTries

run :: Host -> Pin -> Mode -> IO ()
run host pin mode = case mode of
  Watch period ids hold -> watch host pin period ids hold
  _ -> withSession defaultPace host pin (session mode) >>= either (die . show) pure
  where
    session m s = do
      printf "software    %s\n" (softwareLine (sessionSoftware s))
      case m of
        Report -> do
          warn s
          st <- askStatus s >>= orDie
          printf "user level  %s\nclock       %s\nprotocol    %d\n" (levelText (statusUserLevel st)) (show (statusClock st)) (statusProtocol st)
          standing <- askNotifications s >>= orDie
          mapM_ (\n -> printf "notice      %s %s\n" (codeText (notificationCode n)) (notificationText n)) standing
          op <- askOperation s >>= orDie
          printf "operation   %s\n" (modeText (operationMode op))
          case operationReasons op of
            [] -> putStrLn "reason      none"
            rs -> mapM_ (printf "reason      %s\n" . reasonText) rs
        Show ids -> do
          warn s
          refused <- concat <$> traverse (showSetting s) ids
          if null refused then pure () else exitFailure
        Enter -> writableOrDie s >>= enterFachmann >>= orDie >>= reportEntry
        Leave -> writableOrDie s >>= leaveFachmann >>= orDie >>= reportExit
        Watch {} -> pure ()
    codeText (NotificationCode c) = c

-- | Print a setting, or that the user level does not reach it; the
-- setting, if so.
showSetting :: Session -> SettingId -> IO [SettingId]
showSetting s i =
  askSetting s i >>= \case
    Left (Refused r) -> do
      st <- askStatus s >>= orDie
      let SettingId t = r
      printf "%s not accessible at user level %s\n" t (levelText (statusUserLevel st))
      pure [r]
    r -> [] <$ (orDie r >>= putStr . renderSetting)

softwareLine :: Either Unread WebVersion -> String
softwareLine = either (\u -> "not read: " <> show u) (T.unpack . webVersionText)

mismatch :: Mismatch Unread WebVersion -> String
mismatch = T.unpack . mismatchText (T.pack . show) webVersionText navigator10Software

-- | On the terminal, both versions, where the session read another software
-- than the table describes.
warn :: Session -> IO ()
warn s = either (hPutStrLn stderr . ("warning: " <>) . mismatch) (const (pure ())) (writable s)

writableOrDie :: Session -> IO Writable
writableOrDie = either (die . ("refused, nothing sent: " <>) . mismatch) pure . writable

reportEntry :: Entry -> IO ()
reportEntry e = case e of
  AlreadyFachmann -> reportLevel Fachmann
  EntryDeclined n -> die (declined (OtherLevel n))
  EntrySent sent -> reportSent Fachmann sent

reportExit :: Exit -> IO ()
reportExit x = case x of
  AlreadyCustomer -> reportLevel Customer
  NoNotice level -> die (noNotice level)
  ExitSent sent -> reportSent Customer sent

declined :: UserLevel -> String
declined level = "user level " <> levelText level <> ": the code is sent from " <> levelText Customer <> " only"

noNotice :: UserLevel -> String
noNotice level = "user level " <> levelText level <> ", but no " <> T.unpack userLevelNotice <> " notice to acknowledge"

-- | Nothing was sent.
reportLevel :: UserLevel -> IO ()
reportLevel = printf "user level  %s\n" . levelText

reportSent :: UserLevel -> Sent -> IO ()
reportSent wanted sent = do
  case sentResponses sent of
    [] -> putStrLn "answer      none"
    responses -> mapM_ (BL.putStrLn . encode) responses
  printf "user level  %s -> %s\n" (levelText (sentBefore sent)) (levelText (sentAfter sent))
  if sentAfter sent == wanted then pure () else die "the level did not change"

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
      SettingOther kind whole -> printf "  (type %s, not read)\n  %s\n" kind (T.unpack (TE.decodeUtf8 (BL.toStrict (encode whole))))
    row r = case r of
      InfoReading d l x u -> printf "  %-9s %-40s %10s %s\n" (maybe "" T.unpack d) l (infoText x) u
      InfoCells cs -> "  " <> T.unpack (T.intercalate " | " cs) <> "\n"
    infoText (InfoNumber x) = show x
    infoText (InfoText t) = T.unpack t

modeText :: OperationMode -> String
modeText m = case m of
  OtherMode n -> "mode " <> show n
  _ -> show m

-- | The key, or the value of a bit that has none.
reasonText :: Reason -> String
reasonText r = case r of
  Unnamed b -> "bit " <> show b
  _ -> maybe (show r) T.unpack (reasonKey r)

levelText :: UserLevel -> String
levelText l = case l of
  Customer -> "Kunde (0)"
  Fachmann -> "Fachmann (2)"
  OtherLevel n -> show n

-- | Ask the same queries round after round, a line per request, until
-- interrupted.
--
-- A session that ends is opened again for the next request. Each request it
-- cost is still a line, with an @error@, so the gap is in the capture. Every
-- line carries the software of the session it was asked on, which a new
-- session reads anew.
--
-- At 'HoldFachmann', the level is read first in every round and 'decide'
-- says what to do about it; a change of level is a line of its own,
-- 'levelLine'. The level is left on every exit, with SIGINT and SIGTERM
-- ignored from the first of them on.
watch :: Host -> Pin -> Period -> [Query] -> Hold -> IO ()
watch host pin (Period seconds) queries hold = do
  hSetBuffering stdout LineBuffering
  current <- newIORef Nothing
  -- a PIN that is refused now will be refused at every round
  first <- open defaultPace host pin
  case (first, hold) of
    (Left e@(NotAuthorized _), _) -> die (show e)
    (Left e, AsItIs) -> complain (show e) >> rounds current Nothing
    -- the level must be read before anything is sent
    (Left e, HoldFachmann) -> die (show e)
    (Right s, AsItIs) -> warn s >> writeIORef current (Just s) >> rounds current Nothing
    (Right s, HoldFachmann) -> do
      writeIORef current (Just s)
      w <- writableOrDie s
      myThreadId >>= interruptOnSignals
      since <- begin w
      rounds current (Just (Holding (Tries 0) since))
        `finally` (ignoreSignals >> leaveAtExit host pin current)
  where
    rounds current h = getMonotonicTime >>= go current h
    go current h due = do
      now <- getMonotonicTime
      threadDelay (round (max 0 (due - now) * 1e6))
      h' <- maybe (pure Nothing) (levelRound host pin current) h
      sweep current queries
      -- a round that overran starts the next at once, without catching up
      getMonotonicTime >>= go current h' . max (due + fromIntegral seconds)
    sweep _ [] = pure ()
    sweep current (q : qs) =
      connected host pin current >>= \case
        Nothing -> getZonedTime >>= \t -> line t Nothing q (Left "not connected") >> sweep current qs
        Just s -> do
          t <- getZonedTime
          r <- ask s q
          either (\e -> complain (show e) >> line t (Just s) q (Left (show e))) (line t (Just s) q . Right) r
          dropEnded current s
          sweep current qs
    line t s q r = BL.putStrLn (encode (watchLine t s q r))

-- | The session of the watch, opened again if it has ended.
connected :: Host -> Pin -> IORef (Maybe Session) -> IO (Maybe Session)
connected host pin current =
  readIORef current >>= \case
    Just s -> pure (Just s)
    Nothing -> do
      r <- open defaultPace host pin >>= either (\e -> Nothing <$ complain (show e)) (\s -> Just s <$ warn s)
      r <$ writeIORef current r

-- | Close the session if a request ended it, so that the next opens another.
dropEnded :: IORef (Maybe Session) -> Session -> IO ()
dropEnded current s = ended s >>= maybe (pure ()) (const (close s >> writeIORef current Nothing))

-- | The level before the first round. Kunde is entered in the first round,
-- and Fachmann left now, to be entered 'gapSeconds' later, so that the watch
-- knows when its sixty minutes began. At any other level, or at Fachmann
-- without its notice, the watch exits, having sent nothing.
begin :: Writable -> IO (Since Double)
begin w = do
  level <- statusUserLevel <$> (askStatus s >>= orDie)
  case level of
    Customer -> pure Unentered
    OtherLevel _ -> die (declined level)
    Fachmann ->
      leaveFachmann w >>= orDie >>= \case
        AlreadyCustomer -> pure Unentered
        NoNotice l -> die (noNotice l)
        ExitSent sent
          | sentAfter sent == Customer -> do
              levelLine (Just s) LevelLeaving (Just Customer) Nothing
              Paused <$> getMonotonicTime
          | otherwise -> die ("user level " <> levelText (sentAfter sent) <> ": the level did not change")
  where
    s = writableSession w

-- | Read the level and act on it, first in a round, where the watch stands
-- at instants on the monotonic clock. 'Nothing' once the watch has given
-- up.
levelRound :: Host -> Pin -> IORef (Maybe Session) -> Holding Double -> IO (Maybe (Holding Double))
levelRound host pin current h@Holding {holdingTries = tries, holdingSince = since} =
  connected host pin current >>= \case
    -- no level read: nothing to decide on
    Nothing -> pure (Just h)
    Just s -> do
      level <- askStatus s >>= either (\e -> Nothing <$ complain (show e)) (pure . Just . statusUserLevel)
      dropEnded current s
      now <- getMonotonicTime
      let w = either (const Nothing) Just (writable s)
          decision = decide (maybe CannotWrite (const CanWrite) w) level (fmap (now -) h)
          noted change = levelLine (Just s) change level Nothing
      case (decision, w) of
        (Hold, _) -> pure (Just h)
        (Unwritable, _) -> Just h {holdingSince = Barred} <$ noted LevelNotWritable
        (GiveUp, _) -> Nothing <$ noted LevelGaveUp
        (FellBack, _) -> Just h {holdingSince = Unentered} <$ noted LevelFellBack
        (Try, Just wr) -> Just <$> entry s wr
        (Renew, Just wr) -> Just <$> renewal s wr
        -- 'decide' tries nothing without a 'Writable'
        (_, Nothing) -> pure (Just h)
  where
    entry s wr = do
      started <- getMonotonicTime
      a <- attempt <$> enterFachmann wr
      case a of
        Took -> levelLine (Just s) (took since) (Just Fachmann) Nothing
        Untaken u -> levelLine (Just s) LevelFailed (untakenLevel u) (Just (untakenText u))
        Preempted -> pure ()
      pure (afterTry started tries a)
    untakenLevel u = case u of
      AnsweredAt l -> Just l
      Declined n -> Just (OtherLevel n)
      FailedWith _ -> Nothing
    untakenText u = case u of
      AnsweredAt _ -> "answered, but the level did not change"
      Declined n -> declined (OtherLevel n)
      FailedWith e -> show e
    renewal s wr =
      leaveFachmann wr >>= \case
        Right (ExitSent sent)
          | sentAfter sent == Customer -> do
              levelLine (Just s) LevelLeaving (Just Customer) Nothing
              Holding tries . Paused <$> getMonotonicTime
          | otherwise -> h <$ complain ("leaving to renew: user level " <> levelText (sentAfter sent) <> ", the level did not change")
        -- fell back between the two reads
        Right AlreadyCustomer -> Holding tries Unentered <$ levelLine (Just s) LevelFellBack (Just Customer) Nothing
        Right (NoNotice l) -> h <$ complain ("leaving to renew: " <> noNotice l)
        Left e -> h <$ complain ("leaving to renew: " <> show e)
    -- the entry that ends a renewal's pause
    took (Paused _) = LevelRenewed
    took _ = LevelEntered

-- | Leave the level as the watch ends, on its session or, if that fails, on
-- a new one. At Kunde nothing is sent.
leaveAtExit :: Host -> Pin -> IORef (Maybe Session) -> IO ()
leaveAtExit host pin current = do
  done <- leaveOnce
  unless done $ do
    readIORef current >>= mapM_ close
    writeIORef current Nothing
    void leaveOnce
  where
    -- whether another session could not do better
    leaveOnce =
      connected host pin current >>= \case
        Nothing -> False <$ complain "the level was not left: no session"
        Just s -> case writable s of
          Left m -> True <$ complain ("the level was not left: " <> mismatch m)
          Right w ->
            leaveFachmann w >>= \case
              Right (ExitSent sent) -> do
                levelLine (Just s) LevelLeft (Just (sentAfter sent)) Nothing
                unless (sentAfter sent == Customer) (complain "the level did not change")
                pure True
              Right AlreadyCustomer -> pure True
              Right (NoNotice l) -> True <$ complain ("the level was not left: " <> noNotice l)
              Left e -> False <$ complain ("the level was not left: " <> show e)

-- | Handle SIGINT and SIGTERM, in place of GHC's default for SIGINT. The
-- first of either ignores both from then on and interrupts the watch, whose
-- leave then runs under the ordinary mask, so that its requests' timeouts
-- still work.
interruptOnSignals :: ThreadId -> IO ()
interruptOnSignals mainThread = do
  fired <- newIORef False
  let on signal interruption = void (installHandler signal (Catch (once fired interruption)) Nothing)
  on sigINT (throwTo mainThread UserInterrupt)
  -- the exit status of a process a SIGTERM ended
  on sigTERM (throwTo mainThread (ExitFailure (128 + fromIntegral sigTERM)))
  where
    once fired interruption = do
      first <- atomicModifyIORef' fired (\f -> (True, not f))
      if first then ignoreSignals >> interruption else pure ()

-- | Ignore SIGINT and SIGTERM, also for an exit that no signal began: under
-- the ordinary mask, a second interruption would arrive at the first wait
-- for an answer.
ignoreSignals :: IO ()
ignoreSignals = mapM_ ignore [sigINT, sigTERM]
  where
    ignore :: Signal -> IO ()
    ignore signal = void (installHandler signal Ignore Nothing)

-- | A change of level, as a line of a webwatch names it.
data Change
  = LevelEntered
  | -- | a renewal begins
    LevelLeaving
  | LevelRenewed
  | -- | Kunde, or another level, where Fachmann was entered
    LevelFellBack
  | -- | a try that did not take
    LevelFailed
  | LevelGaveUp
  | LevelNotWritable
  | -- | the leave on exit
    LevelLeft

changeText :: Change -> String
changeText c = case c of
  LevelEntered -> "entered"
  LevelLeaving -> "leaving"
  LevelRenewed -> "renewed"
  LevelFellBack -> "fell-back"
  LevelFailed -> "failed"
  LevelGaveUp -> "gave-up"
  LevelNotWritable -> "not-writable"
  LevelLeft -> "left"

-- | A line of a webwatch for a change of level, beside the lines of its
-- reads. It has no @request@ and no @responses@, so that a reader of the
-- reads skips it.
levelLine ::
  Maybe Session ->
  Change ->
  -- | the level the controller reported after the change
  Maybe UserLevel ->
  -- | what went wrong, for 'LevelFailed'
  Maybe String ->
  IO ()
levelLine s change level e = do
  t <- getZonedTime
  BL.putStrLn . encodingToLazyByteString . pairs $
    "captured" .= stamp t
      <> "software" .= fmap (softwareJSON . sessionSoftware) s
      <> "level" .= changeText change
      <> "userLevel" .= fmap levelText level
      <> "error" .= e

complain :: String -> IO ()
complain = hPutStrLn stderr

-- | A line of a watch: an entry of a @webapi@ capture, with the time to the
-- millisecond, the software of the session, and what went wrong if nothing
-- came back.
watchLine :: ZonedTime -> Maybe Session -> Query -> Either String [Value] -> Value
watchLine t s q r =
  object
    [ "request" .= queryJSON q,
      "captured" .= stamp t,
      "software" .= fmap (softwareJSON . sessionSoftware) s,
      "responses" .= either (const []) id r,
      "error" .= either Just (const Nothing) r
    ]

-- | The local time, to the millisecond.
stamp :: ZonedTime -> String
stamp = formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%S%3Q%Ez"

-- | The version a session read, as a capture records it: the page's string,
-- or why it was not read.
softwareJSON :: Either Unread WebVersion -> Value
softwareJSON = either (\u -> object ["error" .= show u]) (String . webVersionText)

orDie :: Either Failure a -> IO a
orDie = either (die . show) pure

die :: String -> IO a
die m = hPutStrLn stderr m >> exitFailure
