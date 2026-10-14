{-# LANGUAGE DeriveLift #-}
{-# LANGUAGE LambdaCase #-}

-- |
-- Module      :  IDM.Modbus.TCP
-- Description :  Modbus TCP framing, as much of it as an iDM Navigator uses
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- A Navigator answers read requests and nothing else that matters here, so this
-- module implements the request/response framing for the two read function
-- codes and leaves the rest of the specification alone.
module IDM.Modbus.TCP
  ( Connection,
    Host (..),
    Port (..),
    UnitId (..),
    Patience (..),
    defaultPatience,
    withConnection,
    connect,
    disconnect,
    FunctionCode (..),
    Address (..),
    Quantity (..),
    ExceptionCode (..),
    exceptionByte,
    Failure (..),
    Ending (..),
    TransactionId (..),
    readRegisters,
    parseResponse,
  )
where

import Control.Exception (Exception, IOException, bracket, bracketOnError, try)
import Data.Bits (testBit, (.&.))
import qualified Data.ByteString as B
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef, writeIORef)
import Data.Word (Word16, Word8)
import Language.Haskell.TH.Syntax (Lift)
import qualified Network.Socket as N
import qualified Network.Socket.ByteString as NB
import System.Timeout (timeout)

newtype Host = Host String
  deriving (Show, Eq)

newtype Port = Port Int
  deriving (Show, Eq)

-- | Modbus unit identifier. A Navigator answers on 1 and ignores the field
-- otherwise, but sending the documented value costs nothing.
newtype UnitId = UnitId Word8
  deriving (Show, Eq)

-- | How long connecting, or one read, may take. A stalled Navigator does not
-- signal at all, and the socket has no timeout of its own.
newtype Patience = Patience {patienceMicroseconds :: Int}
  deriving (Show, Eq)

defaultPatience :: Patience
defaultPatience = Patience 5000000

newtype Address = Address Word16
  deriving (Show, Eq, Ord, Lift)

-- | Number of 16-bit registers to read.
newtype Quantity = Quantity Word16
  deriving (Show, Eq)

-- | The two read function codes. The Navigator serves the same address space
-- under both, so the choice is ours; 'ReadHoldingRegisters' is the default
-- because write support will need it.
data FunctionCode
  = ReadHoldingRegisters
  | ReadInputRegisters
  deriving (Show, Eq)

functionCodeByte :: FunctionCode -> Word8
functionCodeByte ReadHoldingRegisters = 3
functionCodeByte ReadInputRegisters = 4

-- | Modbus exception code as returned by the device.
data ExceptionCode
  = IllegalFunction
  | IllegalDataAddress
  | IllegalDataValue
  | ServerDeviceFailure
  | OtherException Word8
  deriving (Show, Eq)

exceptionCode :: Word8 -> ExceptionCode
exceptionCode 1 = IllegalFunction
exceptionCode 2 = IllegalDataAddress
exceptionCode 3 = IllegalDataValue
exceptionCode 4 = ServerDeviceFailure
exceptionCode n = OtherException n

-- | The inverse. The manual and the community name these codes by number, so a
-- record of what a machine answered gives the number.
exceptionByte :: ExceptionCode -> Word8
exceptionByte IllegalFunction = 1
exceptionByte IllegalDataAddress = 2
exceptionByte IllegalDataValue = 3
exceptionByte ServerDeviceFailure = 4
exceptionByte (OtherException n) = n

-- | Why a read did not produce registers. 'DeviceException' is the ordinary
-- case on a Navigator: an address belonging to hardware that is not fitted
-- answers 'IllegalDataAddress'.
data Failure
  = DeviceException ExceptionCode
  | ShortResponse Int
  | UnexpectedFunctionCode Word8
  | -- | sent; this read ended the connection
    Ended Ending
  | -- | not sent: the connection had ended
    Unsent Ending
  deriving (Show, Eq)

instance Exception Failure

-- | Why a connection ended. Each leaves the stream out of step, or gone: an
-- answer still on its way would be taken for the answer to the next request.
data Ending
  = -- | no answer in time
    NoAnswer
  | -- | the answer belongs to another request
    UnexpectedTransaction TransactionId
  | -- | a frame whose header disagrees with its length, as received
    Malformed B.ByteString
  | -- | the device closed the connection
    ConnectionClosed
  | -- | the socket failed
    Lost String
  deriving (Show, Eq)

-- | What pairs an answer with its request.
newtype TransactionId = TransactionId Word16
  deriving (Show, Eq)

data Connection = Connection
  { connectionSocket :: N.Socket,
    connectionUnitId :: UnitId,
    connectionPatience :: Patience,
    connectionNextTransaction :: IORef Word16,
    -- | why the connection ended, if it has
    connectionEnded :: IORef (Maybe Ending)
  }

-- | Open a connection, run an action, close it again.
--
-- One connection reused for many reads is deliberate: the Navigator is slow to
-- accept sockets and has been reported to stall when hammered.
withConnection :: Patience -> Host -> Port -> UnitId -> (Connection -> IO a) -> IO a
withConnection patience host port unit = bracket (connect patience host port unit) disconnect

-- | Open a connection, or throw an 'IOException', also when it takes longer
-- than the patience.
connect :: Patience -> Host -> Port -> UnitId -> IO Connection
connect patience (Host host) (Port port) unit = do
  opened <- timeout (patienceMicroseconds patience) $ do
    addrs <- N.getAddrInfo (Just hints) (Just host) (Just (show port))
    case addrs of
      [] -> ioError (userError ("cannot resolve " <> host))
      (addr : _) ->
        bracketOnError
          (N.socket (N.addrFamily addr) (N.addrSocketType addr) (N.addrProtocol addr))
          N.close
          (\sock -> sock <$ N.connect sock (N.addrAddress addr))
  case opened of
    Nothing -> ioError (userError ("connecting to " <> host <> " timed out"))
    Just sock -> Connection sock unit patience <$> newIORef 1 <*> newIORef Nothing
  where
    hints = N.defaultHints {N.addrSocketType = N.Stream}

disconnect :: Connection -> IO ()
disconnect = N.close . connectionSocket

-- | Read @quantity@ consecutive registers, returning their raw bytes in wire
-- order. Interpreting them is not this module's business.
--
-- A read that ends the connection closes its socket, and every later read on
-- it fails unsent; 'disconnect' may still be called.
readRegisters ::
  Connection ->
  FunctionCode ->
  Address ->
  Quantity ->
  IO (Either Failure B.ByteString)
readRegisters conn fc (Address addr) (Quantity quantity) =
  readIORef (connectionEnded conn) >>= \case
    Just e -> pure (Left (Unsent e))
    Nothing -> do
      tid <- nextTransaction conn
      let pdu =
            B.pack [functionCodeByte fc]
              <> word16BE addr
              <> word16BE quantity
          adu =
            word16BE tid
              <> word16BE 0 -- protocol identifier
              <> word16BE (fromIntegral (B.length pdu + 1))
              <> B.pack [unUnitId (connectionUnitId conn)]
              <> pdu
      received <- exchange conn adu
      let result = either (Left . Ended) (parseResponse (TransactionId tid) fc) received
      case result of
        Left (Ended e) -> do
          writeIORef (connectionEnded conn) (Just e)
          disconnect conn
        _ -> pure ()
      pure result
  where
    unUnitId (UnitId u) = u

-- | Send a request and receive a frame, header and body.
exchange :: Connection -> B.ByteString -> IO (Either Ending B.ByteString)
exchange conn adu = do
  r <- try (timeout (patienceMicroseconds (connectionPatience conn)) (NB.sendAll (connectionSocket conn) adu >> receive))
  pure $ case r of
    Left e -> Left (Lost (show (e :: IOException)))
    Right Nothing -> Left NoAnswer
    Right (Just frame) -> frame
  where
    receive =
      recvExactly conn headerLength >>= \case
        Nothing -> pure (Left ConnectionClosed)
        Just h
          -- 'parseResponse' refuses a length out of bounds
          | len < 2 || len > maxLength -> pure (Right h)
          | otherwise -> maybe (Left ConnectionClosed) (Right . (h <>)) <$> recvExactly conn (len - 2)
          where
            len = lengthField h

-- | Read a frame, header and body, as the answer to the request with this
-- transaction id and function code.
parseResponse :: TransactionId -> FunctionCode -> B.ByteString -> Either Failure B.ByteString
parseResponse expected fc frame
  | B.length frame < headerLength
      || B.length frame /= headerLength - 2 + lengthField frame
      || lengthField frame > maxLength =
      Left (Ended (Malformed frame))
  | answered /= expected = Left (Ended (UnexpectedTransaction answered))
  | testBit returned 7 = case B.uncons body of
      Just (c, _) -> Left (DeviceException (exceptionCode c))
      Nothing -> Left (ShortResponse 0)
  | returned /= functionCodeByte fc = Left (UnexpectedFunctionCode returned)
  | otherwise = case B.uncons body of
      -- first byte is the byte count, which we can rebuild
      Just (_, payload) -> Right payload
      Nothing -> Left (ShortResponse 0)
  where
    answered = TransactionId (beWord16 (B.take 2 frame))
    returned = B.index frame 7
    body = B.drop headerLength frame

-- | The MBAP header and the function code.
headerLength :: Int
headerLength = 8

-- | The length field counts the unit id and the PDU, which Modbus limits to 253
-- bytes.
maxLength :: Int
maxLength = 254

lengthField :: B.ByteString -> Int
lengthField = fromIntegral . beWord16 . B.take 2 . B.drop 4

nextTransaction :: Connection -> IO Word16
nextTransaction conn =
  atomicModifyIORef' (connectionNextTransaction conn) $ \t ->
    (if t == maxBound then 1 else t + 1, t)

recvExactly :: Connection -> Int -> IO (Maybe B.ByteString)
recvExactly conn n = go B.empty
  where
    go acc
      | B.length acc >= n = pure (Just acc)
      | otherwise = do
          chunk <- NB.recv (connectionSocket conn) (n - B.length acc)
          if B.null chunk then pure Nothing else go (acc <> chunk)

word16BE :: Word16 -> B.ByteString
word16BE w = B.pack [fromIntegral (w `div` 256), fromIntegral (w .&. 0xFF)]

beWord16 :: B.ByteString -> Word16
beWord16 bs = case B.unpack bs of
  [hi, lo] -> fromIntegral hi * 256 + fromIntegral lo
  _ -> 0
