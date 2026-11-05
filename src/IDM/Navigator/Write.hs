-- |
-- Module      :  IDM.Navigator.Write
-- Description :  Writing a register of a Navigator 2.0, at a cost the type states
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- A write goes to a 'Target', whose type says what it costs. A starred
-- register of the parameter list is written to the controller's EEPROM,
-- rated at 300000 cycles; there 'write' reads first and sends nothing when the
-- register holds the value already, since the manual says the EEPROM is
-- written "bei Wertänderungen". A volatile write is always sent: several of
-- them, the PV surplus at 74 among them, are meant to be repeated.
--
-- A register that reads back what was written has stored it. Whether the
-- controller acts on it is another question, and for a register the manual
-- marks @RW\/RO@ it depends on a menu setting: the PV surplus is used only
-- where @PV008@ is "Gebäudeleittechnik/Smartfox". What the controller does
-- once repeated writes stop is not known for any register.
--
-- A write goes only to a controller running the software the table
-- describes, which 'IDM.Navigator.Client.writable' checks: an update may have
-- moved the register.
module IDM.Navigator.Write
  ( Outcome (..),
    Confirmation (..),
    write,
  )
where

import Control.Concurrent (threadDelay)
import IDM.Modbus.TCP.Internal
import IDM.Navigator.Client (Poll (..), Writable, sessionConnection, sessionPoll, writableSession)
import IDM.Navigator.Register (Value)
import IDM.Navigator.Target
import IDM.Navigator.Write.Core

-- | Write a value to a target, on a session that read the software the table
-- describes, pausing between requests as a sweep does.
write :: Writable -> Target c -> Value -> IO (Outcome c)
write w target = writeWith requests (targetCost target) (targetRegister target)
  where
    s = writableSession w
    conn = sessionConnection s
    poll = sessionPoll s
    requests =
      Requests
        { requestRead = readRegisters conn (pollFunctionCode poll),
          requestWrite = writeRegisters conn,
          requestPause = threadDelay (pollIntervalMicroseconds poll)
        }
