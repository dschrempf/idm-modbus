-- |
-- Module      :  Main
-- Description :  Checks that do not need a heat pump
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
module Main (main) where

import qualified Data.Aeson as A
import qualified Data.Aeson.Key as K
import qualified Data.Aeson.KeyMap as KM
import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy.Char8 as BL
import Data.List (group, sort)
import qualified Data.Text as T
import IDM.Modbus.TCP (Address (..), Quantity (..))
import IDM.Navigator.Register
import qualified IDM.Navigator.Table as Table
import IDM.Navigator.Web
import IDM.Navigator.Web.Level (fachmannCode)
import System.Exit (exitFailure)

main :: IO ()
main = do
  results <- mapM check checks
  if and results then putStrLn "all checks passed" else exitFailure

check :: (String, Bool) -> IO Bool
check (name, ok) = do
  putStrLn $ (if ok then "ok    " else "FAIL  ") <> name
  pure ok

checks :: [(String, Bool)]
checks =
  [ ( "the table parses to the number of rows in the file",
      length Table.navigator20 == 663
    ),
    ( "addresses are unique",
      all ((== 1) . length) (group (sort (map registerAddress Table.navigator20)))
    ),
    ( "every register has a name",
      all (not . T.null . registerName) Table.navigator20
    ),
    ( "a name carries its sensor designator whole",
      all (balanced . registerName) Table.navigator20
    ),
    ( "a documented range is well ordered",
      all wellOrdered Table.navigator20
    ),
    ( "write-only registers are not offered for reading",
      all ((/= WriteOnly) . registerAccess) Table.readable
    ),
    ( "enumerations resolve",
      Table.enumLabel (Address 1005) 4 == Just (T.pack "Nur Warmwasser")
    ),
    ( "an enumeration printed once reaches every circuit it describes",
      -- the list prints the operating modes beside heating circuit A only
      Table.enumLabel (Address 1395) 1 == Just (T.pack "Zeitprogramm")
        && Table.enumLabel (Address 1504) 0 == Just (T.pack "Aus")
        && Table.enumLabel (Address 1103) 1 == Just (T.pack "Ein")
    ),
    ( "a float arrives low word first",
      -- 0x41ab4a89 is 21.41; the machine sends 4a89 41ab
      decodeAt 1000 (B.pack [0x4a, 0x89, 0x41, 0xab]) `approximately` 21.41
    ),
    ( "minus one is not a temperature",
      -- the documented sentinel for an unfitted sensor
      decodeRaw 1000 (B.pack [0x00, 0x00, 0xbf, 0x80]) == Just NotFitted
    ),
    ( "a word documented below zero is signed",
      -- 65531 is the documented -5 degree bivalence point
      decodeRaw 1120 (B.pack [0xff, 0xfb]) == Just (Measured (Count (-5)))
    ),
    ( "a bivalence point may be set to minus one",
      -- documented down to -90, so all ones is in range and cannot be absence
      decodeRaw 1120 (B.pack [0xff, 0xff]) == Just (Measured (Count (-1)))
    ),
    ( "a capture records the number, not the reading",
      asWritten (register 1120) (B.pack [0xff, 0xfb]) == Just (Count 65531)
        && asWritten (register 1000) (B.pack [0x00, 0x00, 0xbf, 0x80]) == Just (Real (-1))
    ),
    ( "a pump that is not driven is not a pump that is missing",
      -- the list documents the control signal from -1, so all ones is -1
      decodeRaw 1104 (B.pack [0xff, 0xff]) == Just (Measured (DriveSignal NotDriven))
    ),
    ( "a pump at its minimum speed is not a pump at rest",
      decodeRaw 1104 (B.pack [0x00, 0x00]) == Just (Measured (DriveSignal (Driven 0)))
        && decodeRaw 1104 (B.pack [0x00, 0x64]) == Just (Measured (DriveSignal (Driven 100)))
    ),
    ( "a word documented from zero up keeps the sentinel",
      -- the circulation pump runs or does not; a percentage it is not
      decodeRaw 1118 (B.pack [0xff, 0xff]) == Just NotFitted
        -- and a battery charge level is not a pump, for all it is in per cent
        && decodeRaw 86 (B.pack [0xff, 0xff]) == Just NotFitted
    ),
    ( "a byte-sized register reads only its low byte",
      decodeRaw 1032 (B.pack [0x00, 0x2e]) == Just (Measured (Count 46))
    ),
    ( "widths match the datatypes",
      registerWidth Float32 == Quantity 2 && registerWidth UChar == Quantity 1
    ),
    ( "presence was recorded for every register",
      all ((/= Untested) . registerPresence) Table.navigator20
    ),
    ( "a setting is asked for by its id as a string",
      queryJSON (SettingDetail (SettingId (T.pack "4768")))
        == json "{\"controller\":\"setting\",\"command\":\"detail\",\"data\":{\"settingId\":\"4768\"}}"
        && queryJSON StatusOverview == json "{\"controller\":\"status\",\"command\":\"overview\"}"
    ),
    ( "an answer is found under its key",
      (answerIn (SettingDetail settingsRoot) =<< Just (json "{\"settingDetail\":{}}")) == Just (json "{}")
        && answerIn (SettingDetail settingsRoot) (json "{\"setting\":{}}") == Nothing
    ),
    ( "the status carries the level and the controller's clock",
      -- the controller sends its wall clock as if it were UTC
      fmap (\st -> (statusUserLevel st, show (statusClock st), statusProtocol st)) (status statusPayload)
        == Just (Fachmann, "2026-09-29 13:34:38", 11)
    ),
    ( "a status without a level is not read as one",
      status (json "{\"jsonVersion\":11,\"timestamp\":1790688878000}") == Nothing
    ),
    ( "the code of the day is day and month",
      fmap (fachmannCode . statusClock) (status statusPayload) == Just 2909
        -- a number, as the web interface sends it
        && fmap (fachmannCode . statusClock) (status (json "{\"userlevel\":0,\"timestamp\":1788566400000,\"jsonVersion\":11}"))
          == Just 509
    ),
    ( "the notice of an open level is found by its text",
      notifications (json "{\"current\":[{\"code\":\"20005\",\"dateTime\":\"2026-09-29 13:34:19\",\"index\":0,\"level\":1,\"quitType\":2,\"textEnum\":\"N2_USERLEVELACTIVE\",\"textEnum2\":\"\"}]}")
        == Just [Notification (NotificationCode (T.pack "20005")) userLevelNotice 2]
    ),
    ( "a setting carries the parameter identifier and the double as sent",
      fmap (\st -> (settingParameter st, settingValue st)) (setting (json "{\"id\":\"6784\",\"name\":\"N2_HEATCURVE\",\"param\":\"HKA10\",\"type\":\"float\",\"value\":0.4000000059604645}"))
        == Just (Just (ParameterId (T.pack "HKA10")), SettingFloat 0.4000000059604645)
    ),
    ( "a choice is a number or, for the language, a key",
      fmap settingValue (setting (json "{\"id\":\"1\",\"name\":\"N2_X\",\"type\":\"chooselist\",\"value\":3}")) == Just (SettingChoice (ChoiceIndex 3))
        && fmap settingValue (setting (json "{\"id\":\"4530\",\"name\":\"N2_LANGUAGE\",\"type\":\"chooselist\",\"value\":\"de\"}")) == Just (SettingChoice (ChoiceKey (T.pack "de")))
    ),
    ( "a setting of a type not known keeps the whole detail",
      case setting (json "{\"id\":\"4537\",\"name\":\"N2_SETDATETIME\",\"type\":\"setdt\",\"value\":\"2026-09-29 13:35:36\"}") of
        Just st | SettingOther kind (A.Object o) <- settingValue st -> kind == T.pack "setdt" && KM.member (K.fromString "value") o
        _ -> False
    ),
    ( "an info table reads a sensor per row",
      infoRows sensorTable
        == [ InfoCells [T.pack "K1:"],
             InfoReading Nothing (T.pack "Überhitzung 1") (InfoNumber 20.7) (T.pack "K"),
             InfoReading (Just (T.pack "B86v")) (T.pack "Kondensationstemp. 1") (InfoNumber 22.8) (T.pack "°C"),
             InfoCells [T.pack ""]
           ]
    ),
    ( "what names the machine is redacted, and nothing else",
      redact (json "{\"remoteSessionId\":\"x\",\"a\":{\"param\":\"SSYSLPIN\",\"value\":\"1234\"},\"b\":\"MAC 00:1A:2B:3C:4D:5E, m42@0a1b idm\",\"myidmInfo\":{\"k\":1},\"c\":\"B32 21.5\"}")
        == json "{\"a\":{\"param\":\"SSYSLPIN\",\"value\":\"<redacted>\"},\"b\":\"MAC <redacted>, <redacted> idm\",\"myidmInfo\":\"<redacted>\",\"c\":\"B32 21.5\"}"
    )
  ]

json :: String -> A.Value
json s = case A.decode (BL.pack s) of
  Just v -> v
  Nothing -> error ("not JSON: " <> s)

statusPayload :: A.Value
statusPayload = json "{\"authenticationEnabled\":true,\"jsonVersion\":11,\"language\":\"de\",\"notificationCount\":2,\"timestamp\":1790688878000,\"userlevel\":2}"

-- | The shape of @N2_EVR_OVERVIEW@: a heading, readings with and without a
-- designator, an empty spacer row.
sensorTable :: T.Text
sensorTable =
  T.pack
    "<table id=\"idm_info\"> <tr><td colspan = \"4\" style=\"height:20px;\"><b>K1: </b></td></tr> \
    \<tr><td> </td><td>Überhitzung 1</td><td>20.7</td><td>K</td></tr> \
    \<tr><td>B86v</td><td>Kondensationstemp. 1</td><td>22.8</td><td>°C</td></tr> <tr><td></td></tr> </table>"

register :: Int -> Register
register a = case filter ((== Address (fromIntegral a)) . registerAddress) Table.navigator20 of
  (r : _) -> r
  [] -> error ("no register " <> show a)

decodeRaw :: Int -> B.ByteString -> Maybe (Reading Value)
decodeRaw a = decode (register a)

decodeAt :: Int -> B.ByteString -> Maybe Double
decodeAt a bs = case decodeRaw a bs of
  Just (Measured (Real x)) -> Just x
  _ -> Nothing

approximately :: Maybe Double -> Double -> Bool
approximately (Just x) y = abs (x - y) < 0.01
approximately Nothing _ = False

-- | The parameter list prints a footnote marker exactly like the tail of a
-- sensor designator, so a transcription that confuses the two leaves
-- @Außentemperatur (B32)@ as @Außentemperatur (B3@.
balanced :: T.Text -> Bool
balanced t = T.count (T.pack "(") t == T.count (T.pack ")") t

wellOrdered :: Register -> Bool
wellOrdered r = case registerRange r of
  Just (Range lo hi) -> lo <= hi
  Nothing -> True
