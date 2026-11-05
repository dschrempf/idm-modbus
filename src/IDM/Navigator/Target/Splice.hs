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
  )
where

import qualified Data.Map.Strict as M
import IDM.Modbus.TCP (Address (..))
import IDM.Navigator.Register
import IDM.Navigator.Table (byAddress)
import Language.Haskell.TH.Syntax (Code, Q, liftTyped, unsafeCodeCoerce)

-- | The register at an address, as the table has it. The build fails where
-- the table has no register there, nothing may write it, or a write to it
-- costs other than the target's type says.
registerOf :: Cost -> Address -> Code Q Register
registerOf cost addr@(Address a) = case M.lookup addr byAddress of
  Nothing -> refuse "the table has no register there"
  Just r
    | registerAccess r == ReadOnly -> refuse "the register is read-only"
    | costOf (registerPersistence r) /= cost ->
        refuse ("a write costs " <> show (costOf (registerPersistence r)) <> ", not " <> show cost)
    | otherwise -> liftTyped r
  where
    refuse why = unsafeCodeCoerce (fail ("target " <> show a <> ": " <> why))
