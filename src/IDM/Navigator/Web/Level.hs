{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module      :  IDM.Navigator.Web.Level
-- Description :  Opening and closing the Fachmann level
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- The only writes this library sends, and the two the web interface itself
-- sends to change the user level. They change no setting of the machine, but
-- they do change what the controller shows, on its display as well as here,
-- until the level is closed again.
--
-- Entering saves the code of the day into the settings item
-- @N2_CODE_ENTRY_EXPERT@, of type @actioncode@, as the settings page does.
-- Leaving acknowledges the notice the controller raises while the level is
-- open; the web interface has no other way out.
module IDM.Navigator.Web.Level
  ( fachmannCode,
    LevelChange (..),
    enterFachmann,
    leaveFachmann,
  )
where

import Data.Aeson (Value, object, (.=))
import Data.List (find)
import Data.Text (Text)
import Data.Time (LocalTime (..), toGregorian)
import IDM.Navigator.Web
import IDM.Navigator.Web.Connection
import IDM.Navigator.Web.Session (askNotifications, askStatus)

-- | The code of the Technikerbereich: day and month of the controller's date,
-- @DDMM@. The web interface sends it as a number, so the 5th of September is
-- 509.
fachmannCode :: LocalTime -> Int
fachmannCode t = d * 100 + m
  where
    (_, m, d) = toGregorian (localDay t)

-- | What a request to change the level achieved, by the controller's own
-- account before and after, and what it answered to the request itself.
data LevelChange = LevelChange
  { levelBefore :: UserLevel,
    levelAfter :: UserLevel,
    -- | empty when the level already was what was asked for, and nothing was
    -- sent
    levelResponses :: [Value]
  }
  deriving (Show, Eq)

-- | Enter the Fachmann level with the code of the controller's day.
enterFachmann :: Session -> IO (Either Failure LevelChange)
enterFachmann s = andThen (askStatus s) $ \before ->
  case statusUserLevel before of
    Fachmann -> pure (Right (LevelChange Fachmann Fachmann []))
    level ->
      change s level $
        object
          [ "controller" .= ("setting" :: Text),
            "command" .= ("save" :: Text),
            "data" .= object ["settingId" .= codeEntry, "value" .= fachmannCode (statusClock before)]
          ]
  where
    SettingId codeEntry = codeEntrySetting

-- | Leave the Fachmann level by acknowledging its notice, as the notices page
-- does. Only that notice: acknowledging all of them would also acknowledge a
-- fault.
leaveFachmann :: Session -> IO (Either Failure LevelChange)
leaveFachmann s = andThen (askStatus s) $ \before ->
  andThen (askNotifications s) $ \standing ->
    case find ((== userLevelNotice) . notificationText) standing of
      Nothing -> pure (Right (LevelChange (statusUserLevel before) (statusUserLevel before) []))
      Just notice ->
        change s (statusUserLevel before) $
          object
            [ "controller" .= ("notification" :: Text),
              "command" .= ("save" :: Text),
              "data"
                .= object
                  [ "code" .= code (notificationCode notice),
                    "remindMeLater" .= (notificationQuitType notice == 2)
                  ]
            ]
  where
    code (NotificationCode c) = c

-- | Send a request whose answer is not known, and ask for the level after.
change :: Session -> UserLevel -> Value -> IO (Either Failure LevelChange)
change s before request =
  andThen (drain s request settleMicroseconds) $ \responses ->
    andThen (askStatus s) $ \after ->
      pure (Right (LevelChange before (statusUserLevel after) responses))

-- | How long to listen after a change before asking for the level. The web
-- interface asks for the notifications a second after acknowledging one.
settleMicroseconds :: Int
settleMicroseconds = 1000000

-- | @N2_CODE_ENTRY_EXPERT@, at the root of the settings tree.
codeEntrySetting :: SettingId
codeEntrySetting = SettingId "12503"

andThen :: IO (Either e a) -> (a -> IO (Either e b)) -> IO (Either e b)
andThen m k = m >>= either (pure . Left) k
