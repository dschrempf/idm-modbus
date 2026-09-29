-- |
-- Module      :  IDM.Navigator.Web.Session
-- Description :  Reading a Navigator's web backend
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- Read support only: a session sends a 'Query' and nothing else. Opening and
-- closing a code level is the one exception, and it lives in
-- "IDM.Navigator.Web.Level".
--
-- What the backend answers depends on the user level the controller stands
-- at; nothing here raises it.
module IDM.Navigator.Web.Session
  ( Pin (..),
    Pace (..),
    defaultPace,
    Failure (..),
    Session,
    open,
    close,
    withSession,
    ask,
    askFor,
    askStatus,
    askNotifications,
    askSetting,
  )
where

import Control.Exception (bracket)
import Data.Aeson (Value)
import IDM.Modbus.TCP (Host)
import IDM.Navigator.Web
import IDM.Navigator.Web.Connection

-- | Open a session, run an action, close it again.
withSession :: Pace -> Host -> Pin -> (Session -> IO a) -> IO (Either Failure a)
withSession pace host pin action =
  bracket (open pace host pin) (either (const (pure ())) close) $
    either (pure . Left) (fmap Right . action)

-- | Send a query and return every message that arrived until its answer, the
-- answer last, redacted but otherwise verbatim. This is what a capture keeps.
ask :: Session -> Query -> IO (Either Failure [Value])
ask s q = exchange s (queryJSON q) (maybe False (const True) . answerIn q)

-- | Send a query and read its answer.
askFor :: (Value -> Maybe a) -> Session -> Query -> IO (Either Failure a)
askFor parse s q = do
  r <- ask s q
  pure $ case r of
    Left e -> Left e
    -- the answer is last
    Right ms -> case reverse ms of
      [] -> Left NoAnswer
      (message : _) -> maybe (Left (Unrecognized message)) Right (answerIn q message >>= parse)

askStatus :: Session -> IO (Either Failure Status)
askStatus s = askFor status s StatusOverview

askNotifications :: Session -> IO (Either Failure [Notification])
askNotifications s = askFor notifications s NotificationOverview

askSetting :: Session -> SettingId -> IO (Either Failure Setting)
askSetting s = askFor setting s . SettingDetail
