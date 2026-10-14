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
    ended,
    exchange,
    drain,
    andThen,
  )
where

import Control.Applicative ((<|>))
import Control.Concurrent (ThreadId, forkIO, killThread, threadDelay)
import Control.Concurrent.STM
import Control.Exception (IOException, SomeException, bracketOnError, catch, fromException, throwIO, try)
import Control.Monad (forever)
import Data.Aeson (Value (..), decodeStrict, encode)
import qualified Data.Aeson.KeyMap as KM
import qualified Data.ByteString as B
import Data.Maybe (fromMaybe)
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
-- A session that has ended answers every later request with 'Lost'. The
-- request that ended it may have failed otherwise: see 'NoAnswer' and
-- 'Garbled'.
data Failure
  = -- | the controller refused the PIN; its greeting, if it sent one
    NotAuthorized (Maybe Value)
  | -- | the answer did not come in time. It may still come and be taken for
    -- the answer to a later request, so the session ends.
    NoAnswer
  | -- | the connection, or a send that was cut; every later request fails
    -- with the same reason, unsent
    Lost String
  | -- | a message that is not JSON. The answer may still be on its way, so
    -- the session ends.
    Garbled B.ByteString
  | -- | an answer the parsers of "IDM.Navigator.Web" do not read
    Unrecognized Value
  deriving (Show, Eq)

-- | A thread receives every message as it arrives, so a request that runs out
-- of patience never interrupts a frame half read.
data Session = Session
  { sessionSocket :: N.Socket,
    sessionConnection :: WS.Connection,
    sessionPace :: Pace,
    sessionInbox :: TQueue B.ByteString,
    -- | why the session ended, first reason only
    sessionLost :: TVar (Maybe String),
    sessionReader :: ThreadId
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
        hello <- decodeStrict <$> WS.receiveData conn
        case hello of
          Just greeting@(Object o)
            | KM.lookup "authorized" o == Just (Bool True) -> Right <$> listen sock conn
            | otherwise -> Left (NotAuthorized (Just greeting)) <$ hangUp sock conn
          _ -> Left (NotAuthorized Nothing) <$ hangUp sock conn
  where
    hints = N.defaultHints {N.addrSocketType = N.Stream}

    listen sock conn = do
      inbox <- newTQueueIO
      lost <- newTVarIO Nothing
      reader <-
        forkIO $
          forever (WS.receiveData conn >>= atomically . writeTQueue inbox)
            `catch` (\(e :: SomeException) -> loseWith lost (show e))
      pure (Session sock conn pace inbox lost reader)

close :: Session -> IO ()
close s = do
  hangUp (sessionSocket s) (sessionConnection s)
  killThread (sessionReader s)

hangUp :: N.Socket -> WS.Connection -> IO ()
hangUp sock conn = do
  WS.sendClose conn ("" :: B.ByteString)
    `catch` (\(_ :: WS.ConnectionException) -> pure ())
    `catch` (\(_ :: IOException) -> pure ())
  N.close sock

-- | Why the session ended, if it has.
ended :: Session -> IO (Maybe String)
ended = readTVarIO . sessionLost

loseWith :: TVar (Maybe String) -> String -> IO ()
loseWith lost reason = atomically (modifyTVar' lost (<|> Just reason))

-- | Send a request and collect the messages that arrive until one satisfies
-- the predicate, which is last in the list. What arrived before the request
-- was sent comes first and is not tested. Every message is redacted.
exchange :: Session -> Value -> (Value -> Bool) -> IO (Either Failure [Value])
exchange s request done = do
  started <- getMonotonicTime
  let deadline = started + fromIntegral (pacePatienceMicroseconds (sessionPace s)) / 1e6
  paced s $
    traverse decoded <$> atomically (flushTQueue (sessionInbox s)) >>= \case
      Left e -> pure (Left e)
      Right earlier ->
        andThen (send s request) $ \() ->
          collect s deadline done (map redact earlier) >>= \case
            Right (ms, True) -> pure (Right ms)
            Right (_, False) -> pure (Left NoAnswer)
            Left e -> pure (Left e)

-- | Send a request and collect whatever arrives for a while. For a request
-- whose answer is not known in advance.
drain :: Session -> Value -> Int -> IO (Either Failure [Value])
drain s request micros = do
  started <- getMonotonicTime
  paced s $
    andThen (send s request) $ \() ->
      fmap fst <$> collect s (started + fromIntegral micros / 1e6) (const False) []

-- | A send cut short leaves half a frame on the wire, after which the
-- controller cannot read another.
send :: Session -> Value -> IO (Either Failure ())
send s request =
  maybe (Left (Lost "a send was cut")) Right
    <$> timeout (pacePatienceMicroseconds (sessionPace s)) (WS.sendTextData (sessionConnection s) (encode request))

collect :: Session -> Double -> (Value -> Bool) -> [Value] -> IO (Either Failure ([Value], Bool))
collect s deadline done earlier = go (reverse earlier)
  where
    go acc = do
      now <- getMonotonicTime
      let remaining = round ((deadline - now) * 1e6)
      message <- if remaining <= 0 then pure Nothing else timeout remaining (atomically next)
      case message of
        Nothing -> pure (Right (reverse acc, False))
        Just (Left reason) -> pure (Left (Lost reason))
        Just (Right bytes) -> case decoded bytes of
          Left e -> pure (Left e)
          Right v
            | done v -> pure (Right (reverse (redact v : acc), True))
            | otherwise -> go (redact v : acc)
    -- what arrived before the connection was lost comes first
    next = (Right <$> readTQueue (sessionInbox s)) `orElse` (readTVar (sessionLost s) >>= maybe retry (pure . Left))

decoded :: B.ByteString -> Either Failure Value
decoded bytes = maybe (Left (Garbled bytes)) Right (decodeStrict bytes)

-- | Run a request, end the session after a failure that leaves it out of
-- step, and pause afterwards, whatever came of it.
paced :: Session -> IO (Either Failure a) -> IO (Either Failure a)
paced s action =
  ended s >>= \case
    Just reason -> pure (Left (Lost reason))
    Nothing -> do
      r <- caught action
      mapM_ (loseWith (sessionLost s)) (either ending (const Nothing) r)
      threadDelay (paceIntervalMicroseconds (sessionPace s))
      pure r

-- | Why a failure ends the session, if it does.
ending :: Failure -> Maybe String
ending e = case e of
  NotAuthorized _ -> Nothing
  NoAnswer -> Just "an answer did not come in time"
  Lost reason -> Just reason
  Garbled _ -> Just "a message was not JSON"
  Unrecognized _ -> Nothing

-- | A stalled controller does not signal at all.
guarded :: Pace -> IO (Either Failure a) -> IO (Either Failure a)
guarded pace action = caught (fromMaybe (Left NoAnswer) <$> timeout (pacePatienceMicroseconds pace) action)

-- | The websocket library and the socket signal a lost connection by
-- exception.
caught :: IO (Either Failure a) -> IO (Either Failure a)
caught action =
  try action >>= \case
    Right x -> pure x
    Left e
      | Just (ws :: WS.ConnectionException) <- fromException e -> pure (Left (Lost (show ws)))
      | Just (io :: IOException) <- fromException e -> pure (Left (Lost (show io)))
      | otherwise -> throwIO e

andThen :: IO (Either e a) -> (a -> IO (Either e b)) -> IO (Either e b)
andThen m k = m >>= either (pure . Left) k
