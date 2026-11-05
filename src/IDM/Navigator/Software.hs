{-# LANGUAGE DeriveLift #-}
{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module      :  IDM.Navigator.Software
-- Description :  The controller's software, as the table states it and as a session reads it
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- An update changes the register layout without notice: on 20.24-2608, 4112
-- is no longer a @FLOAT@ over 4112 and 4113. So a session reads the version
-- when it opens, a write goes ahead only on the version the table describes,
-- and a read says which version it was made on. See
-- @doc\/software-versions.md@.
--
-- Each channel reads part of the version. Modbus reads major, minor and
-- patch, the web page series, major and minor; each is compared on what it
-- reads.
module IDM.Navigator.Software
  ( Software (..),
    Patch (..),
    softwareText,
    ModbusVersion (..),
    modbusVersionText,
    WebVersion (..),
    webVersion,
    Agreement (..),
    modbusAgreement,
    webAgreement,
    Mismatch (..),
    mismatchText,
    checked,
  )
where

import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Read as TR
import Language.Haskell.TH.Syntax (Lift)

-- | A software version, as far as it is known. The web page spells
-- 20.24-2608 as @T_NAV10_20.24-2608-g0c686ed41@.
data Software = Software
  { -- | the 20 of 20.24-2608, which no register holds
    softwareSeries :: Int,
    softwareMajor :: Int,
    softwareMinor :: Int,
    softwarePatch :: Patch
  }
  deriving (Show, Eq, Lift)

-- | The patch, which only a register states, and 20.24-1574 lists no such
-- register.
data Patch
  = Patch Int
  | UnknownPatch
  deriving (Show, Eq, Lift)

-- | As @doc\/@ spells it, e.g. @20.24-2608, patch 0@.
softwareText :: Software -> Text
softwareText (Software s ma mi p) =
  T.pack (show s <> "." <> show ma <> "-" <> show mi <> ", patch ")
    <> case p of
      Patch n -> T.pack (show n)
      UnknownPatch -> "unknown"

-- | The version as registers 522, 524 and 526 read.
data ModbusVersion = ModbusVersion
  { modbusMajor :: Int,
    modbusMinor :: Int,
    modbusPatch :: Int
  }
  deriving (Show, Eq)

modbusVersionText :: ModbusVersion -> Text
modbusVersionText (ModbusVersion ma mi p) =
  T.pack ("major " <> show ma <> ", minor " <> show mi <> ", patch " <> show p)

-- | The version as the page @N2_SYSTEM_INFO@ prints it.
data WebVersion = WebVersion
  { -- | verbatim, e.g. @T_NAV10_20.24-2608-g0c686ed41@
    webVersionText :: Text,
    webSeries :: Int,
    webMajor :: Int,
    webMinor :: Int
  }
  deriving (Show, Eq)

-- | Read the page's version string: series, major and minor after the last
-- underscore, then a build the comparison ignores.
webVersion :: Text -> Maybe WebVersion
webVersion t = case T.splitOn "-" (snd (T.breakOnEnd "_" t)) of
  (seriesMajor : minor : _) -> case T.splitOn "." seriesMajor of
    [series, major] -> WebVersion t <$> number series <*> number major <*> number minor
    _ -> Nothing
  _ -> Nothing
  where
    number n = case TR.decimal n of
      Right (v, "") -> Just v
      _ -> Nothing

-- | What a version read says about the software expected.
data Agreement
  = Agrees
  | Disagrees
  | -- | every part both state agrees, but the version read states one the
    -- expected software leaves unknown
    Undecided
  deriving (Show, Eq)

modbusAgreement :: Software -> ModbusVersion -> Agreement
modbusAgreement s v
  | softwareMajor s /= modbusMajor v || softwareMinor s /= modbusMinor v = Disagrees
  | otherwise = case softwarePatch s of
      Patch p
        | p == modbusPatch v -> Agrees
        | otherwise -> Disagrees
      UnknownPatch -> Undecided

webAgreement :: Software -> WebVersion -> Agreement
webAgreement s v
  | (softwareSeries s, softwareMajor s, softwareMinor s) == (webSeries v, webMajor v, webMinor v) = Agrees
  | otherwise = Disagrees

-- | Why a write may not go ahead, by what the session read: @e@ why the
-- version could not be read, @v@ the version read.
data Mismatch e v
  = NotRead e
  | OtherSoftware v
  | -- | see 'Undecided'
    Unconfirmable v
  deriving (Show, Eq)

-- | Both versions, for a person, given how to spell why a version could not
-- be read and the version read.
mismatchText :: (e -> Text) -> (v -> Text) -> Software -> Mismatch e v -> Text
mismatchText unread version expected m =
  ( case m of
      NotRead e -> "the controller's software could not be read (" <> unread e <> ")"
      OtherSoftware v -> "the controller runs " <> version v
      Unconfirmable v -> "the controller runs " <> version v <> ", which the table cannot confirm"
  )
    <> "; the table describes "
    <> softwareText expected

-- | Nothing, if the version read is the software expected.
checked :: (Software -> v -> Agreement) -> Software -> Either e v -> Either (Mismatch e v) ()
checked agreement expected = either (Left . NotRead) $ \v -> case agreement expected v of
  Agrees -> Right ()
  Disagrees -> Left (OtherSoftware v)
  Undecided -> Left (Unconfirmable v)
