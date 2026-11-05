{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module      :  IDM.Navigator.Web.Session
-- Description :  Reading a Navigator's web backend
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- Read support only: a session sends a 'Query' and nothing else. Opening and
-- closing a code level is the one exception, and it lives in
-- "IDM.Navigator.Web.Level"; it needs a 'Writable'.
--
-- What the backend answers depends on the user level the controller stands
-- at; nothing here raises it.
module IDM.Navigator.Web.Session
  ( Pin (..),
    Pace (..),
    defaultPace,
    Failure (..),
    Session,
    sessionLink,
    sessionSoftware,
    Unread (..),
    softwareOf,
    open,
    close,
    ended,
    withSession,
    Writable,
    writableSession,
    writable,
    ask,
    askFor,
    askStatus,
    askNotifications,
    askSetting,
  )
where

import Control.Exception (bracket)
import Data.Aeson (Value)
import Data.Maybe (isJust)
import Data.Text (Text)
import IDM.Modbus.TCP (Host)
import IDM.Navigator.Software (Mismatch, WebVersion, checked, webAgreement, webVersion)
import IDM.Navigator.Table (navigator20Software)
import IDM.Navigator.Web
import IDM.Navigator.Web.Connection (Failure (..), Pace (..), Pin (..), andThen, defaultPace, exchange)
import qualified IDM.Navigator.Web.Connection as C

-- | A connection, and the software the controller ran when it was made.
-- An update restarts the controller and ends the connection, so the version
-- holds for as long as the session can ask anything.
data Session = Session
  { -- | the websocket, which sends any JSON
    sessionLink :: C.Session,
    sessionSoftware :: Either Unread WebVersion
  }

-- | Why the version could not be read off @N2_SYSTEM_INFO@.
data Unread
  = Failed Failure
  | -- | the page, without a row @Software Version@
    NoVersionRow Setting
  | -- | the row, in a spelling 'webVersion' does not read
    Unspelled Text
  deriving (Show, Eq)

-- | Connect, wait for the controller to accept the PIN, and read the
-- version. A version that cannot be read leaves the session open for reads.
open :: Pace -> Host -> Pin -> IO (Either Failure Session)
open pace host pin = C.open pace host pin >>= traverse (\l -> Session l <$> readSoftware l)

close :: Session -> IO ()
close = C.close . sessionLink

-- | Why the session ended, if it has.
ended :: Session -> IO (Maybe String)
ended = C.ended . sessionLink

-- | Open a session, run an action, close it again.
withSession :: Pace -> Host -> Pin -> (Session -> IO a) -> IO (Either Failure a)
withSession pace host pin action =
  bracket (open pace host pin) (either (const (pure ())) close) $
    either (pure . Left) (fmap Right . action)

-- | @N2_SYSTEM_INFO@, which Kunde level shows.
systemInfo :: SettingId
systemInfo = SettingId "4754"

readSoftware :: C.Session -> IO (Either Unread WebVersion)
readSoftware l = either (Left . Failed) softwareOf <$> askForOn setting l (SettingDetail systemInfo)

-- | The version @N2_SYSTEM_INFO@ prints.
softwareOf :: Setting -> Either Unread WebVersion
softwareOf st = case settingValue st of
  SettingInfo rows
    | (t : _) <- [t | InfoCells ["Software Version", t] <- rows] ->
        maybe (Left (Unspelled t)) Right (webVersion t)
  _ -> Left (NoVersionRow st)

-- | A session on the software the table describes; see 'writable'.
newtype Writable = Writable {writableSession :: Session}

-- | The session, if it read the software the table describes, series, major
-- and minor; the page states no patch.
writable :: Session -> Either (Mismatch Unread WebVersion) Writable
writable s = Writable s <$ checked webAgreement navigator20Software (sessionSoftware s)

-- | Send a query and return every message that arrived until its reply, the
-- reply last, redacted but otherwise verbatim. This is what a capture keeps.
ask :: Session -> Query -> IO (Either Failure [Value])
ask = askOn . sessionLink

askOn :: C.Session -> Query -> IO (Either Failure [Value])
askOn l q = exchange l (queryJSON q) (isJust . replyTo q)

-- | Send a query and read its answer; a refusal is a 'Refused'.
askFor :: (Value -> Maybe a) -> Session -> Query -> IO (Either Failure a)
askFor parse = askForOn parse . sessionLink

askForOn :: (Value -> Maybe a) -> C.Session -> Query -> IO (Either Failure a)
askForOn parse l q = andThen (askOn l q) $ \ms -> pure $
  -- the answer is last
  case reverse ms of
    [] -> Left NoAnswer
    (message : _) -> case replyTo q message of
      Just (Answered a) -> maybe (Left (Unrecognized message)) Right (parse a)
      Just (Inaccessible i) -> Left (Refused i)
      Nothing -> Left (Unrecognized message)

askStatus :: Session -> IO (Either Failure Status)
askStatus s = askFor status s StatusOverview

askNotifications :: Session -> IO (Either Failure [Notification])
askNotifications s = askFor notifications s NotificationOverview

askSetting :: Session -> SettingId -> IO (Either Failure Setting)
askSetting s = askFor setting s . SettingDetail
