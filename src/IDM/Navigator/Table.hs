{-# LANGUAGE TemplateHaskell #-}

-- |
-- Module      :  IDM.Navigator.Table
-- Description :  The transcribed parameter list
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- The register table is data, not code. It lives in @data\/@ as a tab separated
-- file, is parsed when this module is compiled, and a row that does not parse
-- fails the build. @tools\/transcribe.py@ writes it from two sources: the
-- manufacturer's manual, and the controller's own web page @N2_GLTMON@, which
-- lists addresses the manual does not. 'registerSource' says which a row is
-- from. There is one place to correct when a new revision of either appears.
module IDM.Navigator.Table
  ( navigator10,
    navigator10Enums,
    navigator10Software,
    byAddress,
    readable,
    present,
    enumLabel,
    myIdmAddress,
    readsMyIdm,
  )
where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Text (Text)
import IDM.Modbus.TCP (Address (..), Quantity, quantityCount)
import IDM.Navigator.Register
import IDM.Navigator.Software (Software)
import IDM.Navigator.Table.Parse (parseEnums, parseRegisters, parseSoftware, parsedFile)

-- | Every register of document 812663 revision 0, the Navigator 10's
-- Modbus manual, and of @N2_GLTMON@, in address order.
navigator10 :: [Register]
navigator10 = $$(parsedFile parseRegisters "data/navigator-10-registers.tsv")

-- | Enumerated values, keyed by address and code.
--
-- The manual prints an encoding once for a family of addresses;
-- @tools\/transcribe.py@ gives it to every member whose name differs only in
-- its final letter or digit, or in the number of its zone module. See
-- @doc\/modbus.md@. It adds the codes measured on the machine that the
-- manual does not print, from @data\/navigator-10-measured-enums.tsv@.
navigator10Enums :: Map (Address, Int) Text
navigator10Enums = M.fromList $$(parsedFile parseEnums "data/navigator-10-enums.tsv")

-- | The software the table describes: the one the captures behind its
-- @observed@ column and its @gltmon@ rows were read on. Written by hand;
-- @tools\/transcribe.py@ refuses a capture read on another. A write goes
-- ahead only on it.
navigator10Software :: Software
navigator10Software = $$(parsedFile parseSoftware "data/navigator-10-software.tsv")

byAddress :: Map Address Register
byAddress = M.fromList [(registerAddress r, r) | r <- navigator10]

-- | Registers that can be read at all.
readable :: [Register]
readable = filter (isReadable . registerAccess) navigator10

-- | Registers that are both readable and were observed on the reference
-- machine. This is the useful set to poll.
present :: [Register]
present = filter ((== Present) . registerPresence) readable

enumLabel :: Address -> Int -> Maybe Text
enumLabel addr code = M.lookup (addr, code) navigator10Enums

-- | Where the controller serves its myiDM identifier, which names the machine.
-- No capture holds it, from either channel.
myIdmAddress :: Address
myIdmAddress = Address 500

-- | Whether a read of so many registers from an address takes in a register
-- of the myiDM identifier, as wide as the table states it.
readsMyIdm :: Address -> Quantity -> Bool
readsMyIdm (Address a) q = start < idStart + idWidth && idStart < start + fromIntegral (quantityCount q)
  where
    start = fromIntegral a :: Int
    Address i = myIdmAddress
    idStart = fromIntegral i
    idWidth = maybe 1 (fromIntegral . quantityCount . registerWidth . registerDatatype) (M.lookup myIdmAddress byAddress)
