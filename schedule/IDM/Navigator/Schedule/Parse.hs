-- |
-- Module      :  IDM.Navigator.Schedule.Parse
-- Description :  A schedule from its TOML file
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
--
-- The parser refuses rather than ignores, as the table's does: a key the
-- format does not name, a phase with two ends or two values for 74, a bound
-- beside a constant, @min@ above @max@, @every@ below @round@, a phase after
-- @until = "stop"@, and a number that is not finite.
--
-- @toml-parser@ 2.0.2.0 reports a key that no matcher took as a warning in
-- a successful result, @Success [\"2:1: unexpected key: b in \<top-level\>\"] x@,
-- for a nested table too (@in phase[0]@), so 'parseSchedule' fails on any
-- warning. A key given twice in one table is an error of TOML itself, and
-- fails before any matcher runs.
module IDM.Navigator.Schedule.Parse
  ( parseSchedule,
  )
where

import Control.Monad (when)
import Data.Foldable (for_)
import qualified Data.List.NonEmpty as NE
import Data.Maybe (catMaybes, fromMaybe, isJust)
import Data.Text (Text)
import qualified Data.Text as T
import IDM.Navigator.Register (Register)
import IDM.Navigator.Schedule
import qualified IDM.Navigator.Table as Table
import Toml (Result (..), decode, valueAnn)
import Toml.Schema (FromValue (..), Matcher, ParseTable, Value', failAt, listOf, optKeyOf, parseTableFromValue, reqKeyOf)

-- | The schedule a file states, or every message of why it states none.
parseSchedule :: Text -> Either [String] Schedule
parseSchedule src = case decode src of
  Success [] (Parsed s) -> Right s
  Success warnings _ -> Left warnings
  Failure errors -> Left errors

newtype Parsed = Parsed Schedule

instance FromValue Parsed where
  fromValue = parseTableFromValue (Parsed <$> schedule)

schedule :: ParseTable l Schedule
schedule = do
  r <- reqKeyOf (T.pack "round") (fmap (\(Seconds n) -> Period n) . seconds)
  w <- fromMaybe [] <$> optKeyOf (T.pack "watch") (listOf (const watched))
  f <- reqKeyOf (T.pack "final") (parseTableFromValue finals)
  ps <- reqKeyOf (T.pack "phase") (phases r)
  pure (Schedule r w f ps)

-- | A readable address of the parameter list.
watched :: Value' l -> Matcher l Register
watched v = do
  n <- fromValue v
  case Table.readableAt n of
    Right reg -> pure reg
    Left Table.Unlisted -> failAt (valueAnn v) (show n <> ": not an address in the parameter list")
    Left Table.WriteOnlyRegister -> failAt (valueAnn v) (show n <> ": write-only")

finals :: ParseTable l Finals
finals =
  Finals
    <$> reqKeyOf (T.pack "surplus") finite
    <*> reqKeyOf (T.pack "target") finite
    <*> reqKeyOf (T.pack "limit") finite

phases :: Period -> Value' l -> Matcher l (NE.NonEmpty Phase)
phases r v = do
  ps <- listOf (const (parseTableFromValue (phase r))) v
  case NE.nonEmpty ps of
    Nothing -> failAt (valueAnn v) "no phase"
    Just ne -> do
      for_ (zip [0 :: Int ..] (NE.init ne)) $ \(i, p) ->
        when (phaseEnd p == AtStop) $
          failAt (valueAnn v) ("phase " <> show i <> ": until = \"stop\" ends the run, so no phase may follow it")
      pure ne

phase :: Period -> ParseTable l Phase
phase (Period r) = do
  constant <- opt "surplus" finite
  pv <- opt "pv" finite
  lo <- opt "min" finite
  hi <- opt "max" finite
  every <- opt "every" seconds
  target <- opt "target" finite
  limit <- opt "limit" finite
  untilEnd <- opt "until" startOrStop
  afterStart <- opt "after-start" seconds
  for' <- opt "for" seconds
  surplus <- case (constant, pv) of
    (Just x, Nothing)
      | isJust lo || isJust hi -> fail "min and max bound the export of pv, not a constant surplus"
      | otherwise -> pure (Constant x)
    (Nothing, Just x)
      | Just l <- lo, Just h <- hi, l > h -> fail "min is above max"
      | otherwise -> pure (Export x (Bounds lo hi))
    (Nothing, Nothing) -> fail "a phase needs surplus or pv"
    (Just _, Just _) -> fail "a phase takes one of surplus and pv"
  end <- case catMaybes [untilEnd, AfterStart <$> afterStart, For <$> for'] of
    [e] -> pure e
    [] -> fail "a phase needs one end: until, after-start or for"
    _ -> fail "a phase takes one end of until, after-start and for"
  for_ every $ \(Seconds e) ->
    when (e < r) $ fail ("every = " <> show e <> " is below round = " <> show r)
  pure (Phase surplus every target limit end)
  where
    opt = optKeyOf . T.pack

startOrStop :: Value' l -> Matcher l End
startOrStop v = do
  t <- fromValue v
  case T.unpack t of
    "start" -> pure AtStart
    "stop" -> pure AtStop
    s -> failAt (valueAnn v) ("until is \"start\" or \"stop\", not " <> show s)

-- | A positive whole number.
seconds :: Value' l -> Matcher l Seconds
seconds v = do
  n <- integer v
  if n > 0 && n <= toInteger (maxBound :: Int)
    then pure (Seconds (fromInteger n))
    else failAt (valueAnn v) (show n <> " is not a positive whole number of seconds")

integer :: Value' l -> Matcher l Integer
integer = fromValue

-- | A finite number; TOML has @inf@ and @nan@.
finite :: Value' l -> Matcher l Double
finite v = do
  x <- fromValue v
  if isNaN x || isInfinite x
    then failAt (valueAnn v) (show x <> " is not a finite number")
    else pure x
