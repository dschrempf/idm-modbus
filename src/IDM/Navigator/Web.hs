{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module      :  IDM.Navigator.Web
-- Description :  The vocabulary of the Navigator's web backend
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- The web interface of a Navigator 2.0 is a single-page application; every
-- value it shows arrives as JSON over a websocket on port 61220. The protocol is
-- undocumented. What is known of it comes from the controller's own JavaScript
-- and from what the controller answered; see
-- @doc\/verification-2026-09-20-webapi.md@.
--
-- A request names a controller and a command. The commands that read are
-- @overview@, @detail@ and @traverse@, and 'Query' can express nothing else.
-- A response is an object with a single key, the controller's last dotted
-- segment followed by the command, capitalized, unless the command is
-- @overview@: @settingDetail@, @graphTraverse@, @status@.
--
-- A response the parsers here do not recognize is handed back whole rather
-- than read as empty.
module IDM.Navigator.Web
  ( -- * Requests
    SettingId (..),
    settingsRoot,
    GraphId (..),
    Span (..),
    Query (..),
    queryJSON,
    answerKey,
    answerIn,

    -- * Status
    UserLevel (..),
    userLevel,
    Status (..),
    status,

    -- * Notifications
    NotificationCode (..),
    Notification (..),
    notifications,
    userLevelNotice,

    -- * Settings
    ParameterId (..),
    Setting (..),
    SettingValue (..),
    Choice (..),
    InfoRow (..),
    InfoValue (..),
    setting,
    infoRows,

    -- * Captures
    redact,
    redacted,
  )
where

import Control.Applicative ((<|>))
import Data.Aeson (Value (..), object, (.:), (.:?), (.=))
import qualified Data.Aeson.Key as K
import qualified Data.Aeson.KeyMap as KM
import Data.Aeson.Types (Parser, parseMaybe, withObject)
import Data.Char (isDigit, isHexDigit, isUpper)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (LocalTime, utc, utcToLocalTime)
import Data.Time.Clock.POSIX (posixSecondsToUTCTime)
import Text.Read (readMaybe)

-- | A node of the settings tree. The protocol sends it as a string of digits,
-- and the root as @-1@.
newtype SettingId = SettingId Text
  deriving (Show, Eq, Ord)

settingsRoot :: SettingId
settingsRoot = SettingId "-1"

-- | A graph, as @graph@\/@overview@ numbers it.
newtype GraphId = GraphId Int
  deriving (Show, Eq)

-- | How much of a graph's history to ask for: @fromSecs@ reaches back from now,
-- and a step of 0 lets the controller choose the resolution.
data Span = Span
  { spanFromSeconds :: Int,
    spanStepSeconds :: Int
  }
  deriving (Show, Eq)

-- | Every request this library can send on its own. The write commands,
-- @save@ and @execute@, have no constructor, and neither have the two reads
-- that open the relay test and ask for user level 4.
data Query
  = StatusOverview
  | NotificationOverview
  | SettingOverview SettingId
  | -- | a read for every item type: the web interface asks it of each item it
    -- opens, and acts only on a later @save@ or @execute@
    SettingDetail SettingId
  | GraphOverview
  | -- | every channel that could be plotted, whether or not a graph holds it
    GraphTraverse
  | GraphDetail GraphId Span
  deriving (Show, Eq)

queryJSON :: Query -> Value
queryJSON q = case q of
  StatusOverview -> request "status" "overview" []
  NotificationOverview -> request "notification" "overview" []
  SettingOverview i -> request "setting" "overview" (onSetting i)
  SettingDetail i -> request "setting" "detail" (onSetting i)
  GraphOverview -> request "graph" "overview" []
  GraphTraverse -> request "graph" "traverse" []
  GraphDetail (GraphId g) (Span from step) ->
    request "graph" "detail" ["id" .= g, "fromSecs" .= from, "stepSecs" .= step]
  where
    request :: Text -> Text -> [(K.Key, Value)] -> Value
    request c m d =
      object $
        ["controller" .= c, "command" .= m]
          <> ["data" .= object d | not (null d)]
    onSetting (SettingId i) = ["settingId" .= i]

-- | The key the answer to a query arrives under.
answerKey :: Query -> K.Key
answerKey q = case q of
  StatusOverview -> "status"
  NotificationOverview -> "notification"
  SettingOverview _ -> "setting"
  SettingDetail _ -> "settingDetail"
  GraphOverview -> "graph"
  GraphTraverse -> "graphTraverse"
  GraphDetail _ _ -> "graphDetail"

-- | The payload of a message, if it is the answer to the query.
answerIn :: Query -> Value -> Maybe Value
answerIn q (Object o) = KM.lookup (answerKey q) o
answerIn _ _ = Nothing

-- | Who the controller takes the web interface to be. The house document on
-- the codes names three levels; the captures have seen 0 and 2 only.
data UserLevel
  = -- | Kundenebene, no code
    Customer
  | -- | the code of the hour, 'IDM.Navigator.Web.Level.fachmannCode'
    Fachmann
  | OtherLevel Int
  deriving (Show, Eq)

userLevel :: Int -> UserLevel
userLevel 0 = Customer
userLevel 2 = Fachmann
userLevel n = OtherLevel n

data Status = Status
  { statusUserLevel :: UserLevel,
    -- | the controller's wall clock. It sends milliseconds since 1970 as if
    -- local time were UTC.
    statusClock :: LocalTime,
    -- | @jsonVersion@; the captures have seen 11
    statusProtocol :: Int
  }
  deriving (Show, Eq)

-- | Read the payload of a @status@ answer.
status :: Value -> Maybe Status
status = parseMaybe $ withObject "status" $ \o -> do
  level <- o .: "userlevel"
  millis <- o .: "timestamp"
  version <- o .: "jsonVersion"
  pure
    Status
      { statusUserLevel = userLevel level,
        statusClock = utcToLocalTime utc (posixSecondsToUTCTime (fromInteger millis / 1000)),
        statusProtocol = version
      }

-- | A notification is acknowledged by its code, as the list gave it.
newtype NotificationCode = NotificationCode Text
  deriving (Show, Eq)

-- | A notification that is still standing.
data Notification = Notification
  { notificationCode :: NotificationCode,
    -- | the translation key, e.g. @N2_USERLEVELACTIVE@
    notificationText :: Text,
    -- | @quitType@. The web interface acknowledges a notification of type 2
    -- with @remindMeLater@ set; the captures have seen 2 and 4.
    notificationQuitType :: Int
  }
  deriving (Show, Eq)

-- | Read the payload of a @notification@ answer: the notifications standing,
-- not the history.
notifications :: Value -> Maybe [Notification]
notifications = parseMaybe $ withObject "notification" $ \o -> do
  current <- o .: "current"
  traverse one current
  where
    one = withObject "current" $ \n ->
      Notification
        <$> (NotificationCode <$> n .: "code")
        <*> n .: "textEnum"
        <*> n .: "quitType"

-- | The notice the controller raises while a code level is open. Acknowledging
-- it is how the web interface leaves the level.
userLevelNotice :: Text
userLevelNotice = "N2_USERLEVELACTIVE"

-- | The manufacturer's identifier of a parameter, the @FW030@ and @BV002@ of the
-- parameter list. The one place the settings tree and the register table
-- ('IDM.Navigator.Register.registerParameter') speak the same vocabulary.
newtype ParameterId = ParameterId Text
  deriving (Show, Eq, Ord)

data Setting = Setting
  { settingId :: SettingId,
    -- | the translation key, e.g. @N2_SENSORS@
    settingName :: Text,
    settingParameter :: Maybe ParameterId,
    settingValue :: SettingValue
  }
  deriving (Show, Eq)

-- | A value by the @type@ the controller gives it.
data SettingValue
  = SettingFloat Double
  | SettingInt Integer
  | SettingBool Bool
  | SettingChoice Choice
  | -- | a table of live readings, one row per line of the page
    SettingInfo [InfoRow]
  | -- | a type this module does not read, and the whole detail
    SettingOther Text Value
  deriving (Show, Eq)

-- | The chosen entry of a list. A language is chosen by key, everything the
-- captures have seen else by number.
data Choice
  = ChoiceIndex Integer
  | ChoiceKey Text
  deriving (Show, Eq)

-- | A row of an info table. The sensor pages print four cells, the other
-- tables what they please.
data InfoRow
  = InfoReading
      { -- | the sensor designator, e.g. @B86v@
        infoDesignator :: Maybe Text,
        infoLabel :: Text,
        infoValue :: InfoValue,
        infoUnit :: Text
      }
  | -- | the cells of a row in any other shape, markup removed
    InfoCells [Text]
  deriving (Show, Eq)

-- | A value as the page prints it, at the precision the page prints.
data InfoValue
  = InfoNumber Double
  | InfoText Text
  deriving (Show, Eq)

-- | Read the payload of a @settingDetail@ answer.
setting :: Value -> Maybe Setting
setting v = flip parseMaybe v $ withObject "settingDetail" $ \o -> do
  i <- o .: "id"
  name <- o .: "name"
  param <- o .:? "param"
  kind <- o .: "type"
  value <- settingValueOf kind o <|> pure (SettingOther kind v)
  pure
    Setting
      { settingId = SettingId i,
        settingName = name,
        settingParameter = ParameterId <$> param,
        settingValue = value
      }
  where
    settingValueOf :: Text -> KM.KeyMap Value -> Parser SettingValue
    settingValueOf kind o = case kind of
      "float" -> SettingFloat <$> o .: "value"
      "int" -> SettingInt <$> o .: "value"
      "bool" -> SettingBool <$> o .: "value"
      "chooselist" ->
        SettingChoice
          <$> ((ChoiceIndex <$> o .: "value") <|> (ChoiceKey <$> o .: "value"))
      "info" -> SettingInfo . infoRows <$> o .: "value"
      _ -> fail "unknown type"

-- | The rows of an info table. The page is HTML, one @tr@ per row and one @td@
-- per cell, and nothing outside a row is a value.
infoRows :: Text -> [InfoRow]
infoRows = map (row . cells . fst . T.breakOn "</tr>") . drop 1 . T.splitOn "<tr"
  where
    -- a cell opens with a tag that may carry attributes, @<td colspan = "4">@
    cells = map (T.strip . stripTags . T.drop 1 . T.dropWhile (/= '>')) . drop 1 . T.splitOn "<td"
    row [d, l, v, u]
      | not (T.null l) = InfoReading (if T.null d then Nothing else Just d) l (valueOf v) u
    row cs = InfoCells cs
    valueOf t = maybe (InfoText t) InfoNumber (readMaybe (T.unpack t))
    stripTags t = case T.breakOn "<" t of
      (before, rest)
        | T.null rest -> before
        | otherwise -> before <> stripTags (T.drop 1 (T.dropWhile (/= '>') rest))

-- | Strip a response of what identifies the machine, as @tools\/webprobe.py@
-- does: the code that opens the controller, the myIDM identifier, the MAC
-- address, and the session identifier the controller stamps on every message.
-- The marker stays, so a reader can tell a removal from an absence.
redact :: Value -> Value
redact v = case v of
  Object o -> Object (KM.mapWithKey field (KM.delete "remoteSessionId" (hide o)))
  Array a -> Array (fmap redact a)
  String t -> String (redactText t)
  _ -> v
  where
    field k x
      | k == "myidmInfo" = String redacted
      | otherwise = redact x
    -- the code appears twice: as @param@ on its own detail, and under its
    -- translation key in the menu that lists it, where it carries no @param@
    hide o
      | KM.lookup "param" o == Just "SSYSLPIN" || KM.lookup "name" o == Just "N2_NETWORK_LOCAL_CODE" =
          KM.mapWithKey (\k x -> if k `elem` ["value", "displayValue"] then String redacted else x) o
      | otherwise = o

redacted :: Text
redacted = "<redacted>"

-- | Replace every myIDM identifier, @m@ digits @\@@ lowercase hex, and every
-- MAC address, uppercase hex in six pairs.
redactText :: Text -> Text
redactText = T.concat . go
  where
    go s = case T.uncons s of
      Nothing -> []
      Just (c, rest) -> case myIdm s <|> mac s of
        Just n -> redacted : go (T.drop n s)
        Nothing -> let (plain, more) = T.break starts rest in T.cons c plain : go more
    starts c = c == 'm' || upperHex c
    upperHex c = isDigit c || (isHexDigit c && isUpper c)
    lowerHex c = isDigit c || (isHexDigit c && not (isUpper c))
    myIdm s = do
      rest <- T.stripPrefix "m" s
      let digits = T.takeWhile isDigit rest
      hex <- T.takeWhile lowerHex <$> T.stripPrefix "@" (T.drop (T.length digits) rest)
      if T.null digits || T.null hex then Nothing else Just (2 + T.length digits + T.length hex)
    mac s =
      let pairs = T.splitOn ":" (T.take 17 s)
       in if length pairs == 6 && all (\p -> T.length p == 2 && T.all upperHex p) pairs
            then Just 17
            else Nothing
