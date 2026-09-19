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
    withConnection,
    FunctionCode (..),
    Address (..),
    Quantity (..),
    ExceptionCode (..),
    Failure (..),
    readRegisters,
  )
where

import Control.Exception (Exception, bracket)
import Data.Bits (testBit, (.&.))
import qualified Data.ByteString as B
import Data.IORef (IORef, atomicModifyIORef', newIORef)
import Data.Word (Word16, Word8)
import qualified Network.Socket as N
import qualified Network.Socket.ByteString as NB

newtype Host = Host String
  deriving (Show, Eq)

newtype Port = Port Int
  deriving (Show, Eq)

-- | Modbus unit identifier. A Navigator answers on 1 and ignores the field
-- otherwise, but sending the documented value costs nothing.
newtype UnitId = UnitId Word8
  deriving (Show, Eq)

newtype Address = Address Word16
  deriving (Show, Eq, Ord)

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

-- | Why a read did not produce registers. 'DeviceException' is the ordinary
-- case on a Navigator: an address belonging to hardware that is not fitted
-- answers 'IllegalDataAddress'.
data Failure
  = DeviceException ExceptionCode
  | ShortResponse Int
  | UnexpectedFunctionCode Word8
  | ConnectionClosed
  deriving (Show, Eq)

instance Exception Failure

data Connection = Connection
  { connectionSocket :: N.Socket,
    connectionUnitId :: UnitId,
    connectionNextTransaction :: IORef Word16
  }

-- | Open a connection, run an action, close it again.
--
-- One connection reused for many reads is deliberate: the Navigator is slow to
-- accept sockets and has been reported to stall when hammered.
withConnection :: Host -> Port -> UnitId -> (Connection -> IO a) -> IO a
withConnection (Host host) (Port port) unit act =
  bracket open close $ \sock -> do
    ref <- newIORef 1
    act (Connection sock unit ref)
  where
    hints = N.defaultHints {N.addrSocketType = N.Stream}
    open = do
      addrs <- N.getAddrInfo (Just hints) (Just host) (Just (show port))
      case addrs of
        [] -> ioError (userError ("cannot resolve " <> host))
        (addr : _) -> do
          sock <- N.socket (N.addrFamily addr) (N.addrSocketType addr) (N.addrProtocol addr)
          N.connect sock (N.addrAddress addr)
          pure sock
    close = N.close

-- | Read @quantity@ consecutive registers, returning their raw bytes in wire
-- order. Interpreting them is not this module's business.
readRegisters ::
  Connection ->
  FunctionCode ->
  Address ->
  Quantity ->
  IO (Either Failure B.ByteString)
readRegisters conn fc (Address addr) (Quantity quantity) = do
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
  NB.sendAll (connectionSocket conn) adu
  header <- recvExactly conn 8
  case header of
    Nothing -> pure (Left ConnectionClosed)
    Just h -> do
      let len = fromIntegral (beWord16 (B.take 2 (B.drop 4 h)))
          returned = B.index h 7
      body <- recvExactly conn (len - 2)
      pure $ case body of
        Nothing -> Left ConnectionClosed
        Just b
          | testBit returned 7 ->
              case B.uncons b of
                Just (c, _) -> Left (DeviceException (exceptionCode c))
                Nothing -> Left (ShortResponse 0)
          | returned /= functionCodeByte fc -> Left (UnexpectedFunctionCode returned)
          | otherwise -> case B.uncons b of
              -- first byte is the byte count, which we can rebuild
              Just (_, payload) -> Right payload
              Nothing -> Left (ShortResponse 0)
  where
    unUnitId (UnitId u) = u

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
