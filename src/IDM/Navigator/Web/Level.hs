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
-- and the level is the controller's, not the connection's: it holds until it
-- is closed again, or for sixty minutes from the entry, however often it is
-- read meanwhile.
--
-- Entering saves the code of the hour into the settings item
-- @N2_CODE_ENTRY_EXPERT@, of type @actioncode@, as the settings page does.
-- Leaving acknowledges the notice the controller raises while the level is
-- open; the web interface has no other way out.
module IDM.Navigator.Web.Level
  ( fachmannCode,
    Entry (..),
    Exit (..),
    Sent (..),
    enterFachmann,
    leaveFachmann,
  )
where

import Control.Concurrent (threadDelay)
import Data.Aeson (Value, object, (.=))
import Data.List (find)
import Data.Text (Text)
import Data.Time (LocalTime (..), TimeOfDay (..), toGregorian)
import IDM.Navigator.Web
import IDM.Navigator.Web.Connection
import IDM.Navigator.Web.Session (askNotifications, askStatus)

-- | The code of the Fachmann level, from the controller's clock: the last
-- digit of the hour, the first digit of the hour, and the last digits of the
-- year, the month and the day. 2026-09-29 15:52 gives 51699. The web interface
-- sends it as a number, so a leading zero is lost: 10:16 on 2022-09-14 gives
-- 1294. The code changes on the hour.
fachmannCode :: LocalTime -> Int
fachmannCode t = foldl (\acc digit -> acc * 10 + digit) 0 [h `mod` 10, h `div` 10, fromInteger (y `mod` 10), m `mod` 10, d `mod` 10]
  where
    (y, m, d) = toGregorian (localDay t)
    h = todHour (localTimeOfDay t)

-- | What 'enterFachmann' came to.
data Entry
  = -- | nothing was sent
    AlreadyFachmann
  | -- | a level neither Kunde nor Fachmann. Nothing was sent: what the code
    -- does there is unknown.
    EntryDeclined Int
  | EntrySent Sent
  deriving (Show, Eq)

-- | What 'leaveFachmann' came to.
data Exit
  = -- | nothing was sent
    AlreadyCustomer
  | -- | a code level without the notice that would close it. Nothing was
    -- sent.
    NoNotice UserLevel
  | ExitSent Sent
  deriving (Show, Eq)

-- | A request to change the level that was sent, with the level by the
-- controller's own account before and after.
data Sent = Sent
  { sentBefore :: UserLevel,
    sentAfter :: UserLevel,
    -- | what arrived before the level was asked for again; possibly nothing
    sentResponses :: [Value]
  }
  deriving (Show, Eq)

-- | Enter the Fachmann level with the code of the controller's clock, from
-- Kunde only. Near the hour it waits for the hour to turn first, at most
-- 'paceIntervalMicroseconds' and twice 'pacePatienceMicroseconds'.
enterFachmann :: Session -> IO (Either Failure Entry)
enterFachmann s = andThen (statusForCode s) $ \before ->
  case statusUserLevel before of
    Fachmann -> pure (Right AlreadyFachmann)
    OtherLevel n -> pure (Right (EntryDeclined n))
    Customer ->
      fmap EntrySent
        <$> change
          s
          Customer
          ( object
              [ "controller" .= ("setting" :: Text),
                "command" .= ("save" :: Text),
                "data" .= object ["settingId" .= codeEntry, "value" .= fachmannCode (statusClock before)]
              ]
          )
  where
    SettingId codeEntry = codeEntrySetting

-- | The status whose clock spells the code. The code arrives later than the
-- clock was read, by at most the answer's way back, the pause and the send;
-- if the hour turns meanwhile, the code is the previous hour's. So when the
-- clock is that close to the hour, the status is read again once it has
-- turned.
statusForCode :: Session -> IO (Either Failure Status)
statusForCode s = andThen (askStatus s) $ \st ->
  let left = untilTheHour (statusClock st)
   in if left > margin then pure (Right st) else threadDelay (ceiling (left * 1e6)) >> askStatus s
  where
    Pace {paceIntervalMicroseconds = interval, pacePatienceMicroseconds = patience} = paceOf s
    margin = fromIntegral (interval + 2 * patience) / 1e6

-- | Seconds until the clock reaches the next full hour.
untilTheHour :: LocalTime -> Double
untilTheHour t = 3600 - realToFrac (fromIntegral (todMin tod * 60) + todSec tod)
  where
    tod = localTimeOfDay t

-- | Leave the Fachmann level by acknowledging its notice, as the notices page
-- does. Only that notice: acknowledging all of them would also acknowledge a
-- fault.
leaveFachmann :: Session -> IO (Either Failure Exit)
leaveFachmann s = andThen (askStatus s) $ \before ->
  case statusUserLevel before of
    Customer -> pure (Right AlreadyCustomer)
    level -> andThen (askNotifications s) $ \standing ->
      case find ((== userLevelNotice) . notificationText) standing of
        Nothing -> pure (Right (NoNotice level))
        Just notice ->
          fmap ExitSent
            <$> change
              s
              level
              ( object
                  [ "controller" .= ("notification" :: Text),
                    "command" .= ("save" :: Text),
                    "data"
                      .= object
                        [ "code" .= code (notificationCode notice),
                          "remindMeLater" .= (notificationQuitType notice == 2)
                        ]
                  ]
              )
  where
    code (NotificationCode c) = c

-- | Send a request whose answer is not known, and ask for the level after.
change :: Session -> UserLevel -> Value -> IO (Either Failure Sent)
change s before request =
  andThen (drain s request settleMicroseconds) $ \responses ->
    andThen (askStatus s) $ \after ->
      pure (Right (Sent before (statusUserLevel after) responses))

-- | How long to listen after a change before asking for the level. The web
-- interface asks for the notifications a second after acknowledging one.
settleMicroseconds :: Int
settleMicroseconds = 1000000

-- | @N2_CODE_ENTRY_EXPERT@, at the root of the settings tree.
codeEntrySetting :: SettingId
codeEntrySetting = SettingId "12503"
