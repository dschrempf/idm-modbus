-- |
-- Module      :  IDM.Modbus.TCP
-- Description :  Modbus TCP framing, without a way to connect or to write
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- What a consumer of the package may reach of "IDM.Modbus.TCP.Internal". A
-- 'Connection' comes only from a session, which reads the controller's
-- software when it opens, and a write goes only through a target and the
-- guard of "IDM.Navigator.Write".
module IDM.Modbus.TCP
  ( Connection,
    Host (..),
    Port (..),
    UnitId (..),
    Patience (..),
    defaultPatience,
    FunctionCode (..),
    Address (..),
    Quantity,
    quantity,
    quantityCount,
    singleRegister,
    registerPair,
    ExceptionCode (..),
    exceptionByte,
    Failure (..),
    Ending (..),
    TransactionId (..),
    readRegisters,
    parseResponse,
    Registers (..),
  )
where

import IDM.Modbus.TCP.Internal
