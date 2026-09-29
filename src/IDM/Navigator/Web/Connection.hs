{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- |
-- Module      :  IDM.Navigator.Web.Connection
-- Description :  The websocket to a Navigator's web backend
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- Sends any JSON it is given, which is why the package does not expose it:
-- "IDM.Navigator.Web.Session" sends only a 'IDM.Navigator.Web.Query', and
-- "IDM.Navigator.Web.Level" the two requests that open and close a code level.
module IDM.Navigator.Web.Connection
  ( Pin (..),
    Pace (..),
    defaultPace,
    Failure (..),
    Session,
    open,
    close,
    exchange,
    drain,
  )
where

import Control.Concurrent (threadDelay)
import Control.Exception (IOException, SomeException, bracketOnError, catch, fromException, throwIO, try)
import Data.Aeson (Value (..), decodeStrict, encode)
import qualified Data.Aeson.KeyMap as KM
import qualified Data.ByteString as B
import GHC.Clock (getMonotonicTime)
import IDM.Modbus.TCP (Host (..))
import IDM.Navigator.Web (redact)
import qualified Network.Socket as N
import qualified Network.WebSockets as WS
import qualified Network.WebSockets.Stream as WS
import System.Timeout (timeout)

-- | The local PIN of the web interface, which travels in the URL.
newtype Pin = Pin String

-- | How to pace a session.
--
-- The manufacturer's own client polls a settings page every 500 ms, so that is
-- what the controller is known to bear.
data Pace = Pace
  { -- | pause after each answer, before the next request
    paceIntervalMicroseconds :: Int,
    -- | how long an answer, or the connection, may take
    pacePatienceMicroseconds :: Int
  }
  deriving (Show, Eq)

defaultPace :: Pace
defaultPace =
  Pace
    { paceIntervalMicroseconds = 500000,
      pacePatienceMicroseconds = 5000000
    }

-- | Why a request did not produce its answer.
--
-- After 'NoAnswer' or 'Lost' the session is not to be used again: a frame may
-- have been cut in half.
data Failure
  = -- | the controller refused the PIN; its greeting, if it sent one
    NotAuthorized (Maybe Value)
  | NoAnswer
  | Lost String
  | -- | a message that is not JSON
    Garbled B.ByteString
  | -- | an answer the parsers of "IDM.Navigator.Web" do not read
    Unrecognized Value
  deriving (Show, Eq)

data Session = Session
  { sessionSocket :: N.Socket,
    sessionConnection :: WS.Connection,
    sessionPace :: Pace
  }

webPort :: String
webPort = "61220"

-- | Connect and wait for the controller to accept the PIN.
open :: Pace -> Host -> Pin -> IO (Either Failure Session)
open pace (Host host) (Pin pin) =
  guarded pace $ do
    addrs <- N.getAddrInfo (Just hints) (Just host) (Just webPort)
    addr <- case addrs of
      [] -> ioError (userError ("cannot resolve " <> host))
      (a : _) -> pure a
    bracketOnError
      (N.socket (N.addrFamily addr) (N.addrSocketType addr) (N.addrProtocol addr))
      N.close
      $ \sock -> do
        N.connect sock (N.addrAddress addr)
        stream <- WS.makeSocketStream sock
        conn <- WS.newClientConnection stream host ("/?auth_code=" <> pin) WS.defaultConnectionOptions []
        let session = Session sock conn pace
        hello <- decodeStrict <$> WS.receiveData conn
        case hello of
          Just greeting@(Object o)
            | KM.lookup "authorized" o == Just (Bool True) -> pure (Right session)
            | otherwise -> Left (NotAuthorized (Just greeting)) <$ close session
          _ -> Left (NotAuthorized Nothing) <$ close session
  where
    hints = N.defaultHints {N.addrSocketType = N.Stream}

close :: Session -> IO ()
close s = do
  WS.sendClose (sessionConnection s) ("" :: B.ByteString) `catch` \e -> const (pure ()) (e :: SomeException)
  N.close (sessionSocket s)

-- | Send a request and collect the messages that arrive until one satisfies
-- the predicate, which is last in the list. Every message is redacted.
exchange :: Session -> Value -> (Value -> Bool) -> IO (Either Failure [Value])
exchange s request done = do
  started <- getMonotonicTime
  let deadline = started + fromIntegral (pacePatienceMicroseconds (sessionPace s)) / 1e6
  paced s $ do
    WS.sendTextData (sessionConnection s) (encode request)
    collect s deadline done >>= \case
      Right (ms, True) -> pure (Right ms)
      Right (_, False) -> pure (Left NoAnswer)
      Left e -> pure (Left e)

-- | Send a request and collect whatever arrives for a while. For a request
-- whose answer is not known in advance.
drain :: Session -> Value -> Int -> IO (Either Failure [Value])
drain s request micros = do
  started <- getMonotonicTime
  paced s $ do
    WS.sendTextData (sessionConnection s) (encode request)
    fmap fst <$> collect s (started + fromIntegral micros / 1e6) (const False)

collect :: Session -> Double -> (Value -> Bool) -> IO (Either Failure ([Value], Bool))
collect s deadline done = go []
  where
    go acc = do
      now <- getMonotonicTime
      let remaining = round ((deadline - now) * 1e6)
      message <- if remaining <= 0 then pure Nothing else timeout remaining (WS.receiveData (sessionConnection s))
      case message of
        Nothing -> pure (Right (reverse acc, False))
        Just bytes -> case decodeStrict bytes of
          Nothing -> pure (Left (Garbled bytes))
          Just v
            | done v -> pure (Right (reverse (redact v : acc), True))
            | otherwise -> go (redact v : acc)

-- | Run a request, turn a lost connection into a 'Failure', and pause
-- afterwards, whatever came of it.
paced :: Session -> IO (Either Failure a) -> IO (Either Failure a)
paced s action = do
  r <- guarded (sessionPace s) action
  threadDelay (paceIntervalMicroseconds (sessionPace s))
  pure r

-- | The websocket library and the socket signal a lost connection by
-- exception, and a stalled controller does not signal at all.
guarded :: Pace -> IO (Either Failure a) -> IO (Either Failure a)
guarded pace action = do
  r <- try (timeout (pacePatienceMicroseconds pace) action)
  case r of
    Right (Just x) -> pure x
    Right Nothing -> pure (Left NoAnswer)
    Left e
      | Just (ws :: WS.ConnectionException) <- fromException e -> pure (Left (Lost (show ws)))
      | Just (io :: IOException) <- fromException e -> pure (Left (Lost (show io)))
      | otherwise -> throwIO e
