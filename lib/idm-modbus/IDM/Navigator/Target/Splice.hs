{-# LANGUAGE TemplateHaskellQuotes #-}

-- |
-- Module      :  IDM.Navigator.Target.Splice
-- Description :  Taking a target's register from the table at compile time
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- Apart from "IDM.Navigator.Target" because a splice cannot run a function of
-- the module it splices into.
module IDM.Navigator.Target.Splice
  ( registerOf,
    costAt,
  )
where

import qualified Data.Map.Strict as M
import IDM.Modbus.TCP (Address (..))
import IDM.Navigator.Register
import IDM.Navigator.Table (byAddress)
import Language.Haskell.TH.Syntax (Code, Exp, Q, liftTyped, unsafeCodeCoerce)

-- | The register at an address, as the table has it.
registerOf :: Address -> Code Q Register
registerOf addr = either (unsafeCodeCoerce . fail) liftTyped (target addr)

-- | What a write to the register at an address costs, as an 'SCost'. Untyped,
-- so that GHC checks it against the cost the constructor's type states.
costAt :: Address -> Q Exp
costAt addr = case costOf . registerPersistence <$> target addr of
  Left why -> fail why
  Right Free -> [|SFree|]
  Right EepromCycle -> [|SEepromCycle|]

-- | The register a target may write, or why the build fails: the table has
-- no register there, nothing may write it, or it is write-only and costs an
-- EEPROM cycle, which 'IDM.Navigator.Write.write' saves only by reading first.
target :: Address -> Either String Register
target addr@(Address a) = case M.lookup addr byAddress of
  Nothing -> refuse "the table has no register there"
  Just r
    | registerAccess r == ReadOnly -> refuse "the register is read-only"
    | not (isReadable (registerAccess r)) && costOf (registerPersistence r) /= Free ->
        refuse "the register is write-only, and a write to it costs an EEPROM cycle"
    | otherwise -> Right r
  where
    refuse why = Left ("target " <> show a <> ": " <> why)
