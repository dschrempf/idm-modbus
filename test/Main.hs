-- |
-- Module      :  Main
-- Description :  Checks that do not need a heat pump
-- Copyright   :  2026 Dominik Schrempf
-- License     :  BSD-3-Clause
module Main (main) where

import Control.Monad (foldM)
import Control.Monad.Trans.State.Strict (State, modify, runState, state)
import qualified Data.Aeson as A
import qualified Data.Aeson.Key as K
import qualified Data.Aeson.KeyMap as KM
import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy.Char8 as BL
import Data.List (group, nub, sort)
import qualified Data.Map.Strict as M
import qualified Data.Text as T
import Data.Time (ZonedTime, defaultTimeLocale, parseTimeOrError)
import qualified Data.Text.IO as T
import GHC.Float (double2Float, float2Double)
import IDM.Modbus.TCP.Internal (Address (..), Ending (..), ExceptionCode (..), Failure (..), FunctionCode (..), Quantity, Registers (..), TransactionId (..), Write (..), parseResponse, parseWriteResponse, quantity, quantityCount, registerPair, singleRegister)
import IDM.Navigator.Capture (watchLineOn)
import IDM.Navigator.Client (Answer (..), Sample (..), sampleOf)
import IDM.Navigator.Register
import IDM.Navigator.Rounds
import IDM.Navigator.Schedule
import IDM.Navigator.Schedule.Parse (parseSchedule)
import IDM.Navigator.Schedule.Step
import IDM.Navigator.Software
import qualified IDM.Navigator.Table as Table
import IDM.Navigator.Target
import IDM.Navigator.Web
import IDM.Navigator.Web.Fachmann
import IDM.Navigator.Web.Level (Entry (..), fachmannCode)
import qualified IDM.Navigator.Web.Level as Level
import IDM.Navigator.Web.Session (softwareOf)
import qualified IDM.Navigator.Web.Session as Web
import IDM.Navigator.Write.Core
import System.Directory (listDirectory)
import System.Exit (exitFailure)
import System.FilePath (takeExtension, (</>))

main :: IO ()
main = do
  files <- scheduleFiles
  results <- mapM check (checks <> files)
  if and results then putStrLn "all checks passed" else exitFailure

-- | The checks that read the repository's files.
scheduleFiles :: IO [(String, Bool)]
scheduleFiles = do
  names <- filter ((== ".toml") . takeExtension) <$> listDirectory "schedules"
  texts <- mapM (T.readFile . ("schedules" </>)) names
  pure
    [ ( "every file in schedules/ parses",
        not (null names) && all (either (const False) (const True) . parseSchedule) texts
      )
    ]

check :: (String, Bool) -> IO Bool
check (name, ok) = do
  putStrLn $ (if ok then "ok    " else "FAIL  ") <> name
  pure ok

checks :: [(String, Bool)]
checks =
  [ ( "an answer is read only as the answer to its own request",
      -- transaction 7, unit 1, two bytes from function code 3
      let frame = B.pack [0, 7, 0, 0, 0, 5, 1, 3, 2, 0x12, 0x34]
       in parseResponse (TransactionId 7) ReadHoldingRegisters frame == Right (B.pack [0x12, 0x34])
            && parseResponse (TransactionId 8) ReadHoldingRegisters frame == Left (Ended (UnexpectedTransaction (TransactionId 7)))
    ),
    ( "a refusal is the device's, and leaves the connection open",
      parseResponse (TransactionId 7) ReadHoldingRegisters (B.pack [0, 7, 0, 0, 0, 3, 1, 0x83, 2])
        == Left (DeviceException IllegalDataAddress)
    ),
    ( "a frame whose length field disagrees with its length ends the connection",
      all
        (\frame -> parseResponse (TransactionId 7) ReadHoldingRegisters frame == Left (Ended (Malformed frame)))
        [ B.pack [0, 7, 0, 0, 0, 1, 1, 3],
          B.pack [0, 7, 0, 0, 0, 5, 1, 3, 2, 0x12],
          B.pack [0, 7, 0, 0]
        ]
    ),
    ( "the controller's register page adds to the manual, and states only what it states",
      length gltmon == 30
        && all
          ( \r ->
              registerPersistence r == UnknownPersistence
                && registerRange r == Nothing
                && registerDefault r == Nothing
          )
          gltmon
        && all ((/= UnknownPersistence) . registerPersistence) (filter ((== Manual) . registerSource) Table.navigator10)
    ),
    ( "the maximum flow temperature is a float the manual does not list",
      -- 45.0, as circuit A read on 2026-10-14
      registerSource (register 1534) == GltMonitor
        && decodeAt 1534 (B.pack [0x00, 0x00, 0x42, 0x34]) `approximately` 45
    ),
    ( "of the page's rows, only the flow temperatures a moved setting joined carry an identifier",
      [(registerAddress r, p) | r <- gltmon, Just p <- [registerParameter r]]
        == zip
          (map Address [1520, 1524, 1526, 1534, 1538, 1540])
          (map T.pack ["HSA05", "HSC05", "HSD05", "HSA04", "HSC04", "HSD04"])
    ),
    ( "a register of unstated encoding is read as it came, never as absence",
      decodeRaw 504 (B.pack [0xff, 0xff]) == Just (Measured (Count 65535))
        && registerWidth (registerDatatype (register 504)) == singleRegister
    ),
    ( "the page's row stands where the manual's datatype contradicts the width read",
      -- revision 12 prints the flow at 1072 as a UCHAR; it reads two registers
      registerSource (register 1072) == GltMonitor
        && registerDatatype (register 1072) == Float32
    ),
    ( "a manual row the width read contradicts goes, even where the page names nothing",
      -- revision 12 prints 4112 as a FLOAT; on 20.24-2608 4112 and 4113 each
      -- answer alone, and the page lists 4112 without a name
      M.notMember (Address 4112) Table.byAddress
        && registerSource (register 4113) == GltMonitor
        && registerWidth (registerDatatype (register 4113)) == singleRegister
    ),
    ( "a name the page prints without a unit keeps its parentheses",
      registerName (register 520) == T.pack "Softwaretype (bitcodiert)"
        && registerUnit (register 520) == Nothing
        && registerUnit (register 4126) == Just Kilowatt
    ),
    ( "addresses are unique",
      all ((== 1) . length) (group (sort (map registerAddress Table.navigator10)))
    ),
    ( "every register has a name",
      all (not . T.null . registerName) Table.navigator10
    ),
    ( "a name carries its sensor designator whole",
      all (balanced . registerName) Table.navigator10
    ),
    ( "a documented range is well ordered",
      all wellOrdered Table.navigator10
    ),
    ( "write-only registers are not offered for reading",
      all ((/= WriteOnly) . registerAccess) Table.readable
    ),
    ( "every unit the table states is known",
      null [u | r <- Table.navigator10, Just (UnknownUnit u) <- [registerUnit r]]
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
    ( "an enumeration printed for zone module 1 reaches the other nine",
      Table.enumLabel (Address 2072) 1 == Just (T.pack "Automatik")
        && Table.enumLabel (Address 2585) 1 == Just (T.pack "Heizen")
    ),
    ( "a float arrives low word first",
      -- 0x41ab4a89 is 21.41; the machine sends 4a89 41ab
      decodeAt 1000 (B.pack [0x4a, 0x89, 0x41, 0xab]) `approximately` 21.41
    ),
    ( "minus one degree is no value or a temperature",
      -- an unfitted sensor answers -1.0, and so does an outdoor temperature
      -- averaged to hundredths when it stands at -1 degree
      decodeRaw 1000 (B.pack [0x00, 0x00, 0xbf, 0x80]) == Just (NoValueOr (Real (-1)))
        && decodeRaw 1002 (B.pack [0x00, 0x00, 0xbf, 0x80]) == Just (NoValueOr (Real (-1)))
    ),
    ( "a float documented above minus one has no value at minus one",
      -- a room temperature supplied from 15 to 30 degrees, a humidity from 0
      decodeRaw 1650 (B.pack [0x00, 0x00, 0xbf, 0x80]) == Just NoValue
        && decodeRaw 1392 (B.pack [0x00, 0x00, 0xbf, 0x80]) == Just NoValue
    ),
    ( "a word documented below zero is signed",
      -- 65531 is the documented -5 degree bivalence point
      decodeRaw 1120 (B.pack [0xff, 0xfb]) == Just (Measured (Count (-5)))
    ),
    ( "a bivalence point may be set to minus one",
      -- documented down to -40, so all ones is in range and cannot be absence
      decodeRaw 1120 (B.pack [0xff, 0xff]) == Just (Measured (Count (-1)))
    ),
    ( "a capture records the number, not the reading",
      asWritten (register 1120) (B.pack [0xff, 0xfb]) == Just (Count 65531)
        && asWritten (register 1000) (B.pack [0x00, 0x00, 0xbf, 0x80]) == Just (Real (-1))
    ),
    ( "a pump that is not driven is not a pump that is missing",
      -- the list documents the control signal with a default of -1, so all
      -- ones is -1, at the charge pump's status and at its signal alike
      decodeRaw 1104 (B.pack [0xff, 0xff]) == Just (Measured (DriveSignal NotDriven))
        && decodeRaw 1074 (B.pack [0xff, 0xff]) == Just (Measured (DriveSignal NotDriven))
    ),
    ( "a pump at its minimum speed is not a pump at rest",
      decodeRaw 1104 (B.pack [0x00, 0x00]) == Just (Measured (DriveSignal (Driven 0)))
        && decodeRaw 1104 (B.pack [0x00, 0x64]) == Just (Measured (DriveSignal (Driven 100)))
    ),
    ( "a word documented from zero up keeps the sentinel",
      -- the circulation pump runs or does not; a percentage it is not
      decodeRaw 1118 (B.pack [0xff, 0xff]) == Just NoValue
        -- and a battery charge level is not a pump, for all it is in per cent
        && decodeRaw 86 (B.pack [0xff, 0xff]) == Just NoValue
    ),
    ( "a byte-sized register reads the whole word, signed",
      decodeRaw 1032 (B.pack [0x00, 0x2e]) == Just (Measured (Count 46))
        -- the controller's own page prints 1714's fffe as -2
        && asWritten (register 1714) (B.pack [0xff, 0xfe]) == Just (Count (-2))
        && asWritten (register 1006) (B.pack [0xff, 0xff]) == Just (Count (-1))
    ),
    ( "a byte-sized register answers -1 and -2 for no value",
      decodeRaw 1006 (B.pack [0xff, 0xff]) == Just NoValue
        && decodeRaw 1714 (B.pack [0xff, 0xfe]) == Just NoValue
    ),
    ( "a machine switched off holds a code, not no value",
      -- 1005 read ffff in "Aus" and 0003 in "Urlaub", which the manual does
      -- not print, so its range reaches down to the measured -1
      decodeRaw 1005 (B.pack [0xff, 0xff]) == Just (Measured (Code (-1)))
        && Table.enumLabel (Address 1005) (-1) == Just (T.pack "Aus")
        && decodeRaw 1005 (B.pack [0x00, 0x03]) == Just (Measured (Code 3))
        && Table.enumLabel (Address 1005) 3 == Just (T.pack "Urlaub")
    ),
    ( "a code is not a count, and a scale's labeled points are neither",
      decodeRaw 1110 (B.pack [0x00, 0x01]) == Just (Measured (Code 1))
        && decodeRaw 1032 (B.pack [0x00, 0x2e]) == Just (Measured (Count 46))
        && registerScale (register 1104) == Magnitude
        && registerScale (register 1712) == Magnitude
    ),
    ( "an enumeration is written from a code, and a count from a count",
      encode (register 1005) (Code (-1)) == Right (One 0xFFFF)
        && encode (register 1005) (Count 1) == Left (Mismatch UChar (Count 1))
        && encode (register 1032) (Code 46) == Left (Mismatch UChar (Code 46))
    ),
    ( "widths match the datatypes",
      registerWidth Float32 == registerPair && registerWidth UChar == singleRegister
    ),
    ( "presence was recorded for every register",
      null [r | r <- Table.navigator10, registerPresence r == Untested]
    ),
    ( "a setting is asked for by its id as a string",
      queryJSON (SettingDetail (SettingId (T.pack "4768")))
        == json "{\"controller\":\"setting\",\"command\":\"detail\",\"data\":{\"settingId\":\"4768\"}}"
        && queryJSON StatusOverview == json "{\"controller\":\"status\",\"command\":\"overview\"}"
    ),
    ( "an answer is found under its key",
      replyTo (SettingDetail settingsRoot) (json "{\"settingDetail\":{\"id\":\"-1\"}}") == Just (Answered (json "{\"id\":\"-1\"}"))
        && replyTo (SettingDetail settingsRoot) (json "{\"setting\":{\"id\":\"-1\"}}") == Nothing
        && replyTo StatusOverview (json "{\"status\":{}}") == Just (Answered (json "{}"))
    ),
    ( "a refusal replies to the setting it names, a detail or an overview",
      let refusal n =
            json $
              "{\"setting\":{\"note\":{\"text\":\"setting item ["
                <> n
                <> "] is not accessible!\",\"type\":\"danger\"},\"redirect\":{\"command\":\"overview\",\"controller\":\"setting\",\"data\":{\"settingId\":\"10508\"}}}}"
          gltmon = SettingId (T.pack "12763")
       in replyTo (SettingDetail gltmon) (refusal "12763") == Just (Inaccessible gltmon)
            && replyTo (SettingOverview gltmon) (refusal "12763") == Just (Inaccessible gltmon)
            && replyTo (SettingDetail gltmon) (refusal "10564") == Nothing
            && replyTo StatusOverview (refusal "12763") == Nothing
    ),
    ( "a graph's answer is its own only if it names the graph and the span",
      let detail name from to =
            json $
              "{\"graphDetail\":{\"name\":\""
                <> name
                <> "\",\"graphs\":[{\"id\":1,\"name\":\"System\"},{\"id\":100,\"name\":\"WW\"}],\"navigation\":{\"from\":"
                <> show (from :: Int)
                <> ",\"to\":"
                <> show (to :: Int)
                <> ",\"step\":0}}}"
          asked = GraphDetail (GraphId 1) (Span 108000 0)
       in replyTo asked (detail "System" 844063227 844171227) /= Nothing
            && replyTo asked (detail "WW" 844063227 844171227) == Nothing
            && replyTo asked (detail "System" 843480027 844171227) == Nothing
    ),
    ( "a setting's answer is its own only if it names the setting",
      replyTo (SettingDetail (SettingId (T.pack "4768"))) (json "{\"settingDetail\":{\"id\":\"5888\"}}") == Nothing
        && replyTo (SettingOverview settingsRoot) (json "{\"setting\":{}}") == Nothing
    ),
    ( "the status carries the level and the controller's clock",
      -- the controller sends its wall clock as if it were UTC
      fmap (\st -> (statusUserLevel st, show (statusClock st), statusProtocol st)) (status statusPayload)
        == Just (Fachmann, "2026-09-29 13:34:38", 11)
    ),
    ( "a status without a level is not read as one",
      status (json "{\"jsonVersion\":11,\"timestamp\":1790688878000}") == Nothing
    ),
    ( "the code is spelled from the controller's clock",
      -- the two examples of the house document, and the code of 2026-09-29 15:52
      map (fmap (fachmannCode . statusClock) . status . clockedAt) [1700832180000, 1790697120000] == [Just 31314, Just 51699]
        -- a number, as the web interface sends it: 01294
        && (fachmannCode . statusClock <$> status (clockedAt 1663150560000)) == Just 1294
    ),
    ( "the notice of an open level is found by its text",
      notifications (json "{\"current\":[{\"code\":\"20005\",\"dateTime\":\"2026-09-29 13:34:19\",\"index\":0,\"level\":1,\"quitType\":2,\"textEnum\":\"N2_USERLEVELACTIVE\",\"textEnum2\":\"\"}]}")
        == Just [Notification (NotificationCode (T.pack "20005")) userLevelNotice 2]
    ),
    ( "the system overview names a PV request, and keeps the bit it does not name",
      -- the heat pump of the system overview during the PV run of 2026-11-09
      let hp = "\"heatpump\":{\"active\":true,\"info\":33,\"operationMode\":1,\"systemMode\":1}"
       in fmap (replyTo SystemOverview) [json ("{\"system\":{" <> hp <> "}}")] == [Just (Answered (json ("{" <> hp <> "}")))]
            && operation (json ("{" <> hp <> "}")) == Just (Operation Heating [Unnamed 1, PV])
    ),
    ( "a heat pump at rest sends no reason, and a circuit's request is lettered",
      operation (json "{\"heatpump\":{\"active\":false,\"operationMode\":0,\"systemMode\":1}}") == Just (Operation Ready [])
        -- 2026-11-05 16:24
        && operation (json "{\"heatpump\":{\"active\":true,\"info\":513,\"operationMode\":1}}") == Just (Operation Heating [Unnamed 1, CircuitRequest CircuitC])
        && fmap (map reasonKey . operationReasons) (operation (json "{\"heatpump\":{\"info\":513,\"operationMode\":1}}")) == Just [Nothing, Just (T.pack "RD_REQ_HK_C")]
    ),
    ( "a bit names a reason by the mode, and none in a mode without a table",
      let reasons mode info = operationReasons <$> operation (json ("{\"heatpump\":{\"info\":" <> show (info :: Int) <> ",\"operationMode\":" <> show (mode :: Int) <> "}}"))
       in reasons 2 16 == Just [PV]
            && reasons 4 32 == Just [PV]
            && reasons 4 16 == Just [ExternalBus]
            && reasons 2 64 == Just [Unnamed 64]
            && reasons 8 32 == Just [Unnamed 32]
            && fmap operationMode (operation (json "{\"heatpump\":{\"operationMode\":3}}")) == Just (OtherMode 3)
    ),
    ( "each mode names a bit once, each a single bit, by a key of its own",
      let modes = [Ready, Heating, Cooling, HotWater, Defrost]
          single b = b > 0 && (b :: Int) `elem` takeWhile (<= b) (iterate (* 2) 1)
          keys = [reasonKey r | m <- modes, (_, r) <- reasonBits m]
       in and [all single bits && unique bits && unique (map snd (reasonBits m)) | m <- modes, let bits = map fst (reasonBits m)]
            && all (/= Nothing) keys
            && length (group (sort keys)) == length (group (sort [show r | m <- modes, (_, r) <- reasonBits m]))
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
    ),
    ( "redaction reaches keys, any depth, and hex in either case",
      redact (json "{\"a\":{\"remoteSessionId\":\"x\",\"00-1a-2b-3c-4d-5e\":\"m42@0A1B\"},\"b\":[\"ff:ee:dd:cc:bb:aa\",\"12:34\"]}")
        == json "{\"a\":{\"<redacted>\":\"<redacted>\"},\"b\":[\"<redacted>\",\"12:34\"]}"
    ),
    ( "the page of the GLT values loses the value of 500, and only that",
      let page v5000 v500 =
            json $
              "{\"value\":\"<table><tr><td>5000</td><td>a </td><td>RO</td><td align=\\\"center\\\">"
                <> v5000
                <> "</td><td></td></tr><tr><td>500</td><td>myiDM-ID </td><td>RO</td><td align=\\\"center\\\">"
                <> v500
                <> "</td><td align=\\\"right\\\"></td></tr></table>\"}"
       in redact (page "123456.0" "123456.0") == page "123456.0" "<redacted>"
    ),
    ( "a read takes in the myiDM identifier where it covers either of its two registers",
      Table.readsMyIdm (Address 500) singleRegister
        && Table.readsMyIdm (Address 501) singleRegister
        && Table.readsMyIdm (Address 499) registerPair
        && not (Table.readsMyIdm (Address 498) registerPair)
        && not (Table.readsMyIdm (Address 502) singleRegister)
    ),
    ( "an info cell decodes the entities the controller writes",
      infoRows (T.pack "<tr><td>B5</td><td>Taupunktwächter&nbsp;Heizkreis A</td><td>1</td><td></td></tr><tr><td>Laufzeit Stufe&nbsp1</td><td>39.9h</td></tr><tr><td>a &amp; b &#x41;&#66; &copy; &</td></tr>")
        == [ InfoReading (Just (T.pack "B5")) (T.pack "Taupunktwächter Heizkreis A") (InfoNumber 1) T.empty,
             InfoCells [T.pack "Laufzeit Stufe 1", T.pack "39.9h"],
             InfoCells [T.pack "a & b AB &copy; &"]
           ]
    ),
    ( "a write of one register is acknowledged by its echo, and only by it",
      let w = Write (Address 1710) (One 1)
       in parseWriteResponse (TransactionId 7) w (B.pack [0, 7, 0, 0, 0, 6, 1, 6, 0x06, 0xAE, 0, 1]) == Right ()
            && parseWriteResponse (TransactionId 7) w (B.pack [0, 7, 0, 0, 0, 6, 1, 6, 0x06, 0xAE, 0, 0])
              == Left (UnexpectedEcho (B.pack [0x06, 0xAE, 0, 0]))
            && parseWriteResponse (TransactionId 7) w (B.pack [0, 7, 0, 0, 0, 3, 1, 0x86, 2])
              == Left (DeviceException IllegalDataAddress)
    ),
    ( "a write of several registers is acknowledged by its address and quantity",
      let w = Write (Address 74) (Two 0 0x4040)
       in parseWriteResponse (TransactionId 7) w (B.pack [0, 7, 0, 0, 0, 6, 1, 16, 0, 74, 0, 2]) == Right ()
            && parseWriteResponse (TransactionId 7) w (B.pack [0, 7, 0, 0, 0, 6, 1, 16, 0, 74, 0, 1])
              == Left (UnexpectedEcho (B.pack [0, 74, 0, 1]))
    ),
    ( "a FLOAT is written low word first",
      encode (register 74) (Real 3.0) == Right (Two 0 0x4040)
    ),
    ( "every writable register reads back what encode writes",
      all roundTrips (filter ((/= ReadOnly) . registerAccess) Table.navigator10)
    ),
    ( "a write the register cannot hold is refused before anything is sent",
      encode (register 1694) (Count 70) == Left (OutOfRange (Range 20 65) 70)
        && encode (register 1694) (Real 40) == Left (Mismatch UChar (Real 40))
        && either isNotFinite (const False) (encode (register 74) (Real (0 / 0)))
        && encode (register 74) (Real 1e39) == Left (NotFinite 1e39)
        && encode (register 1000) (Real 1) == Left (NotWritable ReadOnly)
        && encode (register 1710) (Count 1) == Left (Mismatch Boolean (Count 1))
    ),
    ( "a target is the table's register, at the cost its persistence implies",
      all
        ( \(SomeTarget t) ->
            let r = targetRegister t
             in M.lookup (registerAddress r) Table.byAddress == Just r
                  && sameCost (targetCost t) (costOf (registerPersistence r))
        )
        targets
    ),
    ( "a read asks for 1 to 125 registers, as Modbus allows",
      quantity 0 == Nothing
        && fmap quantityCount (quantity 1) == Just 1
        && fmap quantityCount (quantity 125) == Just 125
        && quantity 126 == Nothing
    ),
    ( "an EEPROM write sends nothing to a register that holds the value already",
      writeAgainst [Right (B.pack [0, 46])] [] SEepromCycle (register 1032) (Count 46)
        == (Unchanged, [ReadOf (Address 1032) singleRegister])
    ),
    ( "an EEPROM write that changes the value reads, writes and reads back, pausing between",
      writeAgainst [Right (B.pack [0, 45]), Right (B.pack [0, 46])] [Right ()] SEepromCycle (register 1032) (Count 46)
        == ( Sent Confirmed,
             [ ReadOf (Address 1032) singleRegister,
               Pause,
               WriteOf (Write (Address 1032) (One 46)),
               Pause,
               ReadOf (Address 1032) singleRegister
             ]
           )
    ),
    ( "an EEPROM write whose check fails sends nothing",
      writeAgainst [Left (DeviceException ServerDeviceFailure)] [] SEepromCycle (register 1032) (Count 46)
        == (CheckFailed (DeviceException ServerDeviceFailure), [ReadOf (Address 1032) singleRegister])
    ),
    ( "a volatile write is sent without a check, and read back",
      writeAgainst [Right (B.pack [0, 0, 0x40, 0x40])] [Right ()] SFree (register 74) (Real 3.0)
        == ( Sent Confirmed,
             [WriteOf (Write (Address 74) (Two 0 0x4040)), Pause, ReadOf (Address 74) registerPair]
           )
    ),
    ( "a read-back tells another value from a failure",
      fst (writeAgainst [Right (B.pack [0, 0, 0x40, 0])] [Right ()] SFree (register 74) (Real 3.0))
        == Sent (DidNotStick (B.pack [0, 0, 0x40, 0]))
        && fst (writeAgainst [Left (Ended NoAnswer)] [Right ()] SFree (register 74) (Real 3.0))
          == Sent (ReadBackFailed (Ended NoAnswer))
    ),
    ( "a write that fails is not read back",
      writeAgainst [] [Left (Ended NoAnswer)] SFree (register 74) (Real 3.0)
        == (Failed (Ended NoAnswer), [WriteOf (Write (Address 74) (Two 0 0x4040))])
    ),
    ( "a write-only register is not read back",
      writeAgainst [] [Right ()] SFree (register 1650) (Real 21.5)
        == (Sent Unconfirmed, [WriteOf (Write (Address 1650) (Two 0 0x41AC))])
    ),
    ( "a value the register cannot hold sends nothing, not even a check",
      writeAgainst [] [] SEepromCycle (register 1032) (Count 20)
        == (Refused (OutOfRange (Range 35 95) 20), [])
    ),
    ( "the system page's version reads as series, major and minor",
      -- N2_SYSTEM_INFO as 20.24-2608 printed it on 2026-11-05, ASCII rows only
      let page =
            json
              "{\"id\":\"4754\",\"name\":\"N2_SYSTEM_INFO\",\"type\":\"info\",\"value\":\
              \\"<table id=\\\"idm_info\\\"><tr><td>Software Version</td><td>T_NAV10_20.24-2608-g0c686ed41</td></tr>\
              \<tr><td>myIDMID</td><td><redacted></td></tr><tr><td>Regler Online</td><td>3047.0h</td></tr></table>\"}"
          version = T.pack "T_NAV10_20.24-2608-g0c686ed41"
       in fmap softwareOf (setting page) == Just (Right (WebVersion version 20 24 2608))
            && webVersion (T.pack "T_NAV10_20.24") == Nothing
            && webVersion (T.pack "T_NAV10_20.x-2608-g0") == Nothing
    ),
    ( "over Modbus, a version agrees in major, minor and patch",
      let expected = Software 20 24 2608 (Patch 0)
       in modbusAgreement expected (ModbusVersion 24 2608 0) == Agrees
            && modbusAgreement expected (ModbusVersion 24 2608 1) == Disagrees
            && modbusAgreement expected (ModbusVersion 24 1574 0) == Disagrees
            && modbusAgreement expected (ModbusVersion 25 2608 0) == Disagrees
    ),
    ( "an unknown patch confirms no version, but refutes one of another minor",
      let expected = Software 20 24 1574 UnknownPatch
       in modbusAgreement expected (ModbusVersion 24 1574 0) == Undecided
            && modbusAgreement expected (ModbusVersion 24 2608 0) == Disagrees
            && checked modbusAgreement expected (Right (ModbusVersion 24 1574 0) :: Either () ModbusVersion)
              == Left (Unconfirmable (ModbusVersion 24 1574 0))
    ),
    ( "over the web, a version agrees in series, major and minor",
      let expected = Software 20 24 2608 UnknownPatch
          at s ma mi = WebVersion (T.pack "") s ma mi
       in webAgreement expected (at 20 24 2608) == Agrees
            && webAgreement expected (at 21 24 2608) == Disagrees
            && webAgreement expected (at 20 24 1574) == Disagrees
    ),
    ( "a version that could not be read refuses a write",
      checked modbusAgreement (Software 20 24 2608 (Patch 0)) (Left (Ended NoAnswer))
        == Left (NotRead (Ended NoAnswer) :: Mismatch Failure ModbusVersion)
    ),
    ( "a loss in mid-round closes the session and asks nothing more",
      let (rs, c) = roundsAgainst [] [Right (B.pack [0, 0, 0xbf, 0]), Left (Ended NoAnswer)] (Just (FakeSession 0)) [[register 74, register 88, register 4108]]
          s0 = Just (FakeSession 0)
       in seenOf c
            == [ SawRead (Address 74) s0 (Just (Right (B.pack [0, 0, 0xbf, 0]))),
                 SawRead (Address 88) s0 (Just (Left (Ended NoAnswer))),
                 SawDropped NoAnswer,
                 SawRead (Address 4108) Nothing Nothing
               ]
            && requestsOf c == [ReadOn (FakeSession 0) (Address 74), PauseOn (FakeSession 0), ReadOn (FakeSession 0) (Address 88), Closing (FakeSession 0)]
            && map roundSession rs == [Nothing]
            && map (map askedMonotonic . roundReads) rs == [[0, 0.25, 0.5]]
            && [fmap answerRaw . sampleResult <$> roundSample r (Address a) | r <- rs, a <- [88, 4108]]
              == [Just (Left (Ended NoAnswer)), Nothing]
    ),
    ( "a request left unsent ends the session as a loss does",
      let (_, c) = roundsAgainst [] [Left (Unsent ConnectionClosed)] (Just (FakeSession 0)) [[register 74, register 88]]
       in seenOf c
            == [ SawRead (Address 74) (Just (FakeSession 0)) (Just (Left (Unsent ConnectionClosed))),
                 SawDropped ConnectionClosed,
                 SawRead (Address 88) Nothing Nothing
               ]
            && requestsOf c == [ReadOn (FakeSession 0) (Address 74), Closing (FakeSession 0)]
    ),
    ( "the round after a loss opens a session anew, reports it, and reads on it",
      let (rs, c) = roundsAgainst [] [Left (Ended NoAnswer), Right (B.pack [0, 1])] (Just (FakeSession 0)) [[register 1100], [register 1100]]
       in seenOf c
            == [ SawRead (Address 1100) (Just (FakeSession 0)) (Just (Left (Ended NoAnswer))),
                 SawDropped NoAnswer,
                 SawOpened (FakeSession 1),
                 SawRead (Address 1100) (Just (FakeSession 1)) (Just (Right (B.pack [0, 1])))
               ]
            && requestsOf c == [ReadOn (FakeSession 0) (Address 1100), Closing (FakeSession 0), Opening, ReadOn (FakeSession 1) (Address 1100), PauseOn (FakeSession 1)]
            && map roundSession rs == [Nothing, Just (FakeSession 1)]
    ),
    ( "a session that does not open asks nothing, and the next round tries again",
      let (rs, c) = roundsAgainst [Left (T.pack "refused")] [Right (B.pack [0, 0, 0xbf, 0])] Nothing [[register 74, register 88], [register 74]]
       in seenOf c
            == [ SawNotOpened (T.pack "refused"),
                 SawRead (Address 74) Nothing Nothing,
                 SawRead (Address 88) Nothing Nothing,
                 SawOpened (FakeSession 1),
                 SawRead (Address 74) (Just (FakeSession 1)) (Just (Right (B.pack [0, 0, 0xbf, 0])))
               ]
            && requestsOf c == [Opening, Opening, ReadOn (FakeSession 1) (Address 74), PauseOn (FakeSession 1)]
            && map roundSession rs == [Nothing, Just (FakeSession 1)]
    ),
    ( "a round reads what every need names, each register once, in the order of first mention",
      let ignore = const (pure ())
       in map registerAddress (needed [need [register 74, register 88] ignore, need [register 4108, register 74] ignore, need [register 88, register 1100] ignore])
            == map Address [74, 88, 4108, 1100]
    ),
    ( "a watch line is the line of a capture, byte for byte",
      -- lines of captures/navigator-10-watch-20.24-2608-2026-11-09-1235.jsonl
      -- and -2026-11-07-2120.jsonl, which the watch wrote before it read in
      -- rounds
      let ok = Just (Right (ModbusVersion 24 2608 0))
          okText = "{\"status\": \"ok\", \"exception\": null, \"major\": 24, \"minor\": 2608, \"patch\": 0}"
       in watchLineAt "2026-11-09T12:38:34.026+01:00" ok 4122 (Just (Right (B.pack [0x3d, 0x65, 0x3e, 0x0a])))
            == "{\"time\": \"2026-11-09T12:38:34.026+01:00\", \"software\": " <> okText <> ", \"address\": 4122, \"status\": \"ok\", \"exception\": null, \"raw\": \"3d653e0a\", \"value\": 0.1349998265504837}"
            && watchLineAt "2026-11-09T12:38:33.709+01:00" ok 1100 (Just (Right (B.pack [0, 1])))
              == "{\"time\": \"2026-11-09T12:38:33.709+01:00\", \"software\": " <> okText <> ", \"address\": 1100, \"status\": \"ok\", \"exception\": null, \"raw\": \"0001\", \"value\": 1}"
            && watchLineAt "2026-11-07T21:20:51.605+01:00" ok 1074 (Just (Right (B.pack [0xff, 0xff])))
              == "{\"time\": \"2026-11-07T21:20:51.605+01:00\", \"software\": " <> okText <> ", \"address\": 1074, \"status\": \"ok\", \"exception\": null, \"raw\": \"ffff\", \"value\": 65535}"
            && watchLineAt "2026-11-07T21:39:39.960+01:00" ok 74 (Just (Left (Ended NoAnswer)))
              == "{\"time\": \"2026-11-07T21:39:39.960+01:00\", \"software\": " <> okText <> ", \"address\": 74, \"status\": \"error\", \"exception\": null, \"raw\": null, \"value\": null}"
            && watchLineAt "2026-11-07T21:39:41.735+01:00" Nothing 88 Nothing
              == "{\"time\": \"2026-11-07T21:39:41.735+01:00\", \"software\": null, \"address\": 88, \"status\": \"error\", \"exception\": null, \"raw\": null, \"value\": null}"
    ),
    ( "a watch line states a refusal's code, a software not read, and hides the myiDM identifier",
      watchLineAt "2026-10-15T14:18:57.571+02:00" (Just (Left (DeviceException IllegalDataAddress))) 1110 (Just (Left (DeviceException IllegalDataAddress)))
        == "{\"time\": \"2026-10-15T14:18:57.571+02:00\", \"software\": {\"status\": \"exception\", \"exception\": 2}, \"address\": 1110, \"status\": \"exception\", \"exception\": 2, \"raw\": null, \"value\": null}"
        && watchLineAt "2026-10-15T14:18:57.571+02:00" (Just (Left (Ended NoAnswer))) 500 (Just (Right (B.pack [0, 0, 0x42, 0x34])))
          == "{\"time\": \"2026-10-15T14:18:57.571+02:00\", \"software\": {\"status\": \"error\", \"exception\": null}, \"address\": 500, \"status\": \"ok\", \"exception\": null, \"raw\": \"<redacted>\", \"value\": \"<redacted>\"}"
    ),
    ( "the phases advance on each kind of end, and several in one round",
      let ends =
            stepping
              [ ["surplus = 1.0", "until = \"start\""],
                ["surplus = 2.0", "after-start = 30"],
                ["surplus = 3.0", "for = 20"],
                ["surplus = 4.0", "until = \"stop\""]
              ]
              [running t c | (t, c) <- [(0, Aus), (10, Ein), (20, Ein), (30, Ein), (40, Ein), (50, Ein), (60, Ein), (70, Aus)]]
          several =
            stepping
              [["surplus = 1.0", "until = \"start\""], ["surplus = 2.0", "until = \"start\""], ["surplus = 3.0", "for = 20"]]
              [running t Ein | t <- [0, 10, 20]]
       in map (began . fst) ends == [[0], [1], [], [], [2], [], [3], []]
            && map snd (drop 7 ends) == [Left Stopped]
            && map (began . fst) several == [[0, 1, 2], [], []]
            && map snd several == [Right [surplusOf 3], Right [surplusOf 3], Left ScheduleDone]
    ),
    ( "a span passes at a round that comes a moment early",
      let rs =
            stepping
              [["surplus = 1.0", "for = 30"], ["surplus = 2.0", "until = \"stop\""]]
              [running t Ein | t <- [0.3, 10.2, 19.9, 30.1, 39.8]]
       in map snd rs == map (Right . pure . surplusOf) [1, 1, 1, 2, 2]
            && map (began . fst) rs == [[0], [], [], [1], []]
    ),
    ( "the start in a first round that reads Ein; a round without 1100 changes nothing",
      let first' = stepping [["surplus = 1.0", "until = \"start\""], ["surplus = 2.0", "until = \"stop\""]] [running 0 Ein]
          without =
            stepping
              [["surplus = 1.0", "until = \"start\""], ["surplus = 2.0", "until = \"stop\""]]
              [Observation (Instant t) c Nothing | (t, c) <- [(0, Nothing), (10, Just Ein), (20, Nothing), (30, Just Aus)]]
       in map fst first' == [[CompressorStarted, BeganPhase 0 constantUntilStart, BeganPhase 1 constantUntilStop]]
            && map (filter (`elem` [CompressorStarted, CompressorStopped]) . fst) without == [[], [CompressorStarted], [], [CompressorStopped]]
            && map (began . fst) without == [[0], [1], [], []]
            && map snd without == [Right [surplusOf 1], Right [surplusOf 2], Right [surplusOf 2], Left Stopped]
    ),
    ( "88 goes before the phase's first 74, only once, and also when that 74 is skipped",
      let pv = ["pv = 2.0", "target = 0.5", "until = \"stop\""]
          skipped = stepping [pv] [drawing 0 Nothing, drawing 10 (Just 1.5), drawing 20 (Just 1.5)]
          written = stepping [pv] [drawing 0 (Just 1.5), drawing 10 (Just 1.5)]
       in map snd skipped == [Right [targetOf 0.5], Right [surplusOf 0.5], Right [surplusOf 0.5]]
            && map (elem (NoDraw PvSurplus) . fst) skipped == [True, False, False]
            && map snd written == [Right [targetOf 0.5, surplusOf 0.5], Right [surplusOf 0.5]]
    ),
    ( "4108 goes before each 74, and not with a skipped one",
      map snd (stepping [["pv = 2.0", "limit = 1.0", "until = \"stop\""]] [drawing 0 (Just 1.0), drawing 10 Nothing, drawing 20 (Just 1.5)])
        == [Right [limitOf 1, surplusOf 1], Right [], Right [limitOf 1, surplusOf 0.5]]
    ),
    ( "the bounds clamp the export, after it is rounded to 0.01 kW",
      let rs =
            stepping
              [["pv = 2.0", "min = -0.1", "max = 0.105", "until = \"stop\""]]
              [drawing 0 (Just 1.88), drawing 10 (Just 2.5), drawing 20 (Just 1.9667)]
       in map snd rs == map (Right . pure . surplusOf) [0.105, -0.1, 0.03]
            && [computationWritten e | (es, _) <- rs, Exported e <- es] == [0.105, -0.1, 0.03]
    ),
    ( "a round without 4122, or with -1.0 there, writes no 74 in a pv phase, and the write stays due",
      let sentinel = drawOf =<< decodeRaw 4122 (B.pack [0x00, 0x00, 0xbf, 0x80])
          rs =
            stepping
              [["pv = 2.0", "every = 30", "until = \"stop\""]]
              [drawing 0 Nothing, drawing 10 sentinel, drawing 20 (Just 1.0), drawing 30 (Just 1.0), drawing 50 (Just 1.0)]
       in decodeRaw 4122 (B.pack [0x00, 0x00, 0xbf, 0x80]) == Just (NoValueOr (Real (-1)))
            && map snd rs == [Right [], Right [], Right [surplusOf 1], Right [], Right [surplusOf 1]]
            && map (elem (NoDraw PvSurplus) . fst) rs == [True, True, False, False, False]
    ),
    ( "an Aus after an Ein ends the drive, and one before an Ein does not",
      map snd (stepping [["surplus = 1.0", "until = \"stop\""]] [running t c | (t, c) <- [(0, Aus), (10, Aus), (20, Ein), (30, Aus)]])
        == [Right [surplusOf 1], Right [surplusOf 1], Right [surplusOf 1], Left Stopped]
    ),
    ( "the parser refuses an unknown key, two ends, a bound beside surplus, min above max, every below round, and a phase after until = \"stop\"",
      let stop = ["surplus = 1.0", "until = \"stop\""]
          refused = either (const True) (const False) . parseSchedule . T.pack
       in not (refused (withPhases [stop]))
            && all
              refused
              [ "colour = 1\n" <> withPhases [stop],
                withPhases [stop <> ["colour = 1"]],
                withPhases [["surplus = 1.0", "for = 60", "until = \"stop\""]],
                withPhases [["surplus = 1.0", "min = 0", "until = \"stop\""]],
                withPhases [["pv = 2.0", "min = 0.2", "max = 0.1", "until = \"stop\""]],
                withPhases [["surplus = 1.0", "every = 5", "until = \"stop\""]],
                withPhases [stop, ["surplus = 2.0", "for = 60"]]
              ]
    ),
    ( "a schedule watches only readable addresses of the parameter list",
      let watching w = parseSchedule (T.pack ("watch = " <> w <> "\n" <> withPhases [["surplus = 1.0", "until = \"stop\""]]))
       in fmap (map registerAddress . scheduleWatch) (watching "[74, 1100]") == Right [Address 74, Address 1100]
            && all (either (const True) (const False) . watching) ["[1]", "[70000]", "[-74]"]
            && Table.readableAt 1 == Left Table.Unlisted
            && Table.readableAt 65536 == Left Table.Unlisted
    ),
    ( "a web watch renews the level 55 minutes from its entry, entering 30 s after the leave",
      let at level = decide CanWrite (Just level) . Holding (Tries 0)
       in at Fachmann (Entered (55 * 60 - 1)) == Hold
            && at Fachmann (Entered (55 * 60)) == Renew
            && at Customer (Paused 29) == Hold
            && at Customer (Paused 30) == Try
            -- a Fachmann level the watch did not enter, as at its beginning
            && at Fachmann Unentered == Renew
    ),
    ( "a level that fell back is entered again at the next round",
      decide CanWrite (Just Customer) (Holding (Tries 0) (Entered 600)) == FellBack
        && decide CanWrite (Just Customer) (Holding (Tries 0) Unentered) == Try
    ),
    ( "an entry that answered but left the level at Kunde is a failed try, as one declined or failed",
      -- the answer of 2026-11-10 20:56, seconds after a leave
      let ignored =
            EntrySent
              ( Level.Sent
                  Customer
                  Customer
                  [json "{\"settingSave\":{\"note\":{\"text\":\"action has been executed successfully!\",\"type\":\"success\"}}}"]
              )
          untaken = [Right ignored, Right (EntryDeclined 4), Left Web.NoAnswer]
       in all (\r -> afterTry (60 :: Int) (Tries 1) (attempt r) == Holding (Tries 2) (Tried 60)) untaken
            && attempt (Right ignored) == Untaken (AnsweredAt Customer)
            && afterTry (60 :: Int) (Tries 2) (attempt (Right (EntrySent (Level.Sent Customer Fachmann []))))
              == Holding (Tries 0) (Entered 60)
    ),
    ( "a web watch tries 30 s apart, gives up after three, and tries no more",
      let failed = Untaken (AnsweredAt Customer)
          third = foldl (\h t -> afterTry t (holdingTries h) failed) (Holding (Tries 0) Unentered) [0, 30, 60 :: Double]
          sinces = [Unentered, Entered 0, Entered 4000, Paused 0, Paused 40, Tried 0, Tried 40, Barred]
          levels = [Nothing, Just Customer, Just Fachmann, Just (OtherLevel 4)]
       in decide CanWrite (Just Customer) (Holding (Tries 2) (Tried 29)) == Hold
            && decide CanWrite (Just Customer) (Holding (Tries 2) (Tried 30)) == Try
            && holdingTries third == maxTries
            && and [decide w l (Holding (Tries n) s) == GiveUp | w <- [CanWrite, CannotWrite], l <- levels, s <- sinces, n <- [3, 4]]
    ),
    ( "a web watch tries nothing without a Writable, and says so once",
      let sinces = [Unentered, Entered 0, Entered 4000, Paused 0, Paused 40, Tried 0, Tried 40]
          levels = [Nothing, Just Customer, Just Fachmann, Just (OtherLevel 4)]
       in and [decide CannotWrite l (Holding (Tries n) s) == Unwritable | l <- levels, s <- sinces, n <- [0, 2]]
            && and [decide CannotWrite l (Holding (Tries 0) Barred) == Hold | l <- levels]
    )
  ]

-- | A session of the fake controller: the how-manyth opening made it. A
-- round given a session at the start is given the 0th.
newtype FakeSession = FakeSession Int
  deriving (Show, Eq)

-- | A request a round made of the fake controller.
data RoundRequest
  = Opening
  | ReadOn FakeSession Address
  | Closing FakeSession
  | PauseOn FakeSession
  deriving (Show, Eq)

-- | What a round reported, as far as the checks look.
data Seen
  = SawRead Address (Maybe FakeSession) (Maybe (Either Failure B.ByteString))
  | SawOpened FakeSession
  | SawNotOpened T.Text
  | SawDropped Ending
  deriving (Show, Eq)

-- | A controller that answers each opening and each read with the next of
-- its answers: once they run out, an opening succeeds and a read is not
-- answered.
data Controller = Controller
  { controllerOpenings :: [Either T.Text ()],
    controllerAnswers :: [Either Failure B.ByteString],
    controllerSessions :: Int,
    -- | seconds; a quarter more at every look
    controllerClock :: Double,
    -- | latest first
    controllerRequests :: [RoundRequest],
    -- | latest first
    controllerSeen :: [Seen]
  }

-- | Rounds read one after another off the fake controller, each from the
-- session the one before it ended with.
roundsAgainst :: [Either T.Text ()] -> [Either Failure B.ByteString] -> Maybe FakeSession -> [[Register]] -> ([RoundOn FakeSession], Controller)
roundsAgainst openings answers held regss =
  let ((done, _), c) = runState (foldM next ([], held) regss) (Controller openings answers 0 0 [] [])
   in (reverse done, c)
  where
    next (done, session) regs = do
      r <- readRound fake report session regs
      pure (r : done, roundSession r)
    fake :: RoundRequests (State Controller) FakeSession
    fake =
      RoundRequests
        { openSession = logged Opening >> state opening,
          readSample = \s r -> logged (ReadOn s (registerAddress r)) >> sampleOf r <$> state answer,
          closeSession = logged . Closing,
          pauseAfter = logged . PauseOn,
          localClock = pure (zoned "2026-11-10T12:00:00.000+01:00"),
          monotonicClock = state (\c -> (controllerClock c, c {controllerClock = controllerClock c + 0.25}))
        }
    logged q = modify (\c -> c {controllerRequests = q : controllerRequests c})
    report e = modify (\c -> c {controllerSeen = seen e : controllerSeen c})
    opening c = case controllerOpenings c of
      Left why : rest -> (Left why, c {controllerOpenings = rest})
      rest -> let n = controllerSessions c + 1 in (Right (FakeSession n), c {controllerOpenings = drop 1 rest, controllerSessions = n})
    answer c = case controllerAnswers c of
      a : rest -> (a, c {controllerAnswers = rest})
      [] -> (Left (Ended NoAnswer), c)
    seen e = case e of
      ReadDone a -> SawRead (registerAddress (askedRegister a)) (askedSession a) (fmap answerRaw . sampleResult <$> askedSample a)
      Opened s -> SawOpened s
      NotOpened why -> SawNotOpened why
      Dropped why -> SawDropped why

requestsOf :: Controller -> [RoundRequest]
requestsOf = reverse . controllerRequests

seenOf :: Controller -> [Seen]
seenOf = reverse . controllerSeen

-- | The watch line of a read at the stamp given, on a session that read the
-- software given, of the register at the address given: its bytes or its
-- failure, or 'Nothing' where it was not asked.
watchLineAt :: String -> Maybe (Either Failure ModbusVersion) -> Int -> Maybe (Either Failure B.ByteString) -> String
watchLineAt t version a result =
  watchLineOn
    id
    Asked
      { askedRegister = register a,
        askedAt = zoned t,
        askedMonotonic = 0,
        askedSession = version,
        askedSample = sampleOf (register a) <$> result
      }

zoned :: String -> ZonedTime
zoned = parseTimeOrError False defaultTimeLocale "%Y-%m-%dT%H:%M:%S%Q%Ez"

-- | A schedule of these phases, each given by its lines, at a round of 10 s.
withPhases :: [[String]] -> String
withPhases ps =
  unlines $
    ["round = 10", "[final]", "surplus = -0.5", "target = 0.0", "limit = -1.0"]
      <> concatMap ("[[phase]]" :) ps

-- | What each round of a schedule of these phases did, up to its end.
stepping :: [[String]] -> [Observation] -> [([Event], Either Done [Command])]
stepping ps = go notBegun
  where
    s = either (error . unlines) id (parseSchedule (T.pack (withPhases ps)))
    go _ [] = []
    go p (o : os) =
      let (p', es, r) = step s p o
       in (es, r) : either (const []) (const (go p' os)) r

-- | A round in which 1100 read this, and 4122 nothing.
running :: Double -> Compressor -> Observation
running t c = Observation (Instant t) (Just c) Nothing

-- | A round in which the compressor ran and drew this.
drawing :: Double -> Maybe Double -> Observation
drawing t = Observation (Instant t) (Just Ein)

began :: [Event] -> [Int]
began es = [i | BeganPhase i _ <- es]

surplusOf, targetOf, limitOf :: Double -> Command
surplusOf = Command PvSurplus . Real
targetOf = Command PvTarget . Real
limitOf = Command HeatPumpPowerLimit . Real

constantUntilStart, constantUntilStop :: Phase
constantUntilStart = Phase (Constant 1) Nothing Nothing Nothing AtStart
constantUntilStop = Phase (Constant 2) Nothing Nothing Nothing AtStop

-- | A request a write made of the fake controller.
data Request
  = ReadOf Address Quantity
  | WriteOf Write
  | Pause
  deriving (Show, Eq)

-- | A controller that answers each read and each write with the next of its
-- answers, and does not answer once they run out.
data Fake = Fake
  { fakeReads :: [Either Failure B.ByteString],
    fakeWrites :: [Either Failure ()],
    -- | latest first
    fakeLog :: [Request]
  }

-- | What a write came to against the fake, and the requests it made.
writeAgainst :: [Either Failure B.ByteString] -> [Either Failure ()] -> SCost c -> Register -> Value -> (Outcome c, [Request])
writeAgainst reads writes cost reg v =
  reverse . fakeLog <$> runState (writeWith fake cost reg v) (Fake reads writes [])
  where
    fake :: Requests (State Fake)
    fake =
      Requests
        { requestRead = \a q -> logged (ReadOf a q) >> state (next fakeReads (\rs f -> f {fakeReads = rs})),
          requestWrite = \w -> logged (WriteOf w) >> state (next fakeWrites (\ws f -> f {fakeWrites = ws})),
          requestPause = logged Pause
        }
    logged r = modify (\f -> f {fakeLog = r : fakeLog f})
    next :: (Fake -> [Either Failure a]) -> ([Either Failure a] -> Fake -> Fake) -> Fake -> (Either Failure a, Fake)
    next answers rest f = case answers f of
      a : as -> (a, rest as f)
      [] -> (Left (Ended NoAnswer), f)

-- | 'encode' then 'decode' gives the value back, for a value the register's
-- range allows: its maximum, or a value of the datatype where none is
-- documented.
roundTrips :: Register -> Bool
roundTrips r = case registerDatatype r of
  Float32 ->
    let x = maybe 21.5 rangeMaximum (registerRange r)
     in back (Real x) == Right (Just (Measured (Real (float2Double (double2Float x)))))
  Boolean -> back (Flag True) == Right (Just (Measured (Flag True)))
  _ ->
    let n = maybe 1 (round . rangeMaximum) (registerRange r)
        v
          | registerUnit r == Just Percent && maybe False ((< 0) . rangeMinimum) (registerRange r) = DriveSignal (Driven n)
          | registerScale r == Enumeration = Code n
          | otherwise = Count n
     in back v == Right (Just (Measured v))
  where
    back v = decode r . wire <$> encode r v

isNotFinite :: Refusal -> Bool
isNotFinite (NotFinite _) = True
isNotFinite _ = False

sameCost :: SCost c -> Cost -> Bool
sameCost SFree c = c == Free
sameCost SEepromCycle c = c == EepromCycle

json :: String -> A.Value
json s = case A.decode (BL.pack s) of
  Just v -> v
  Nothing -> error ("not JSON: " <> s)

-- | A status at the given controller clock.
clockedAt :: Integer -> A.Value
clockedAt millis = json ("{\"userlevel\":0,\"jsonVersion\":11,\"timestamp\":" <> show millis <> "}")

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

gltmon :: [Register]
gltmon = filter ((== GltMonitor) . registerSource) Table.navigator10

register :: Int -> Register
register a = case filter ((== Address (fromIntegral a)) . registerAddress) Table.navigator10 of
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

unique :: (Eq a) => [a] -> Bool
unique xs = length (nub xs) == length xs
