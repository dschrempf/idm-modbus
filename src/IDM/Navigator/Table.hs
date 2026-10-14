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
  ( navigator20,
    navigator20Enums,
    byAddress,
    readable,
    present,
    enumLabel,
  )
where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Text (Text)
import IDM.Modbus.TCP (Address)
import IDM.Navigator.Register
import IDM.Navigator.Table.Parse (parseEnums, parseRegisters, parsedFile)

-- | Every register of the Navigator 2.0 parameter list, document 812170
-- revision 10, and of @N2_GLTMON@, in address order.
navigator20 :: [Register]
navigator20 = $$(parsedFile parseRegisters "data/navigator-2.0-registers.tsv")

-- | Enumerated values, keyed by address and code.
--
-- The manual prints an encoding once for a family of addresses;
-- @tools\/transcribe.py@ gives it to every member whose name differs only in
-- its final letter or digit, or in the number of its zone module. See
-- @doc\/research.md@.
navigator20Enums :: Map (Address, Int) Text
navigator20Enums = M.fromList $$(parsedFile parseEnums "data/navigator-2.0-enums.tsv")

byAddress :: Map Address Register
byAddress = M.fromList [(registerAddress r, r) | r <- navigator20]

-- | Registers that can be read at all.
readable :: [Register]
readable = filter (isReadable . registerAccess) navigator20

-- | Registers that are both readable and were observed on the reference
-- machine. This is the useful set to poll.
present :: [Register]
present = filter ((== Present) . registerPresence) readable

enumLabel :: Address -> Int -> Maybe Text
enumLabel addr code = M.lookup (addr, code) navigator20Enums
