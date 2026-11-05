# WriteMultiple and Quantity admit counts Modbus forbids

`IDM.Modbus.TCP` exports `WriteMultiple Address (NonEmpty Word16)`, and
Modbus allows at most 123 registers in one function code 16. `writePdu`
narrows the count to a `Word16` and the byte count to a `Word8` without a
check. With 128 registers the byte count wraps to 0 and the request is
malformed. `Quantity`, for a read, has the same gap at 125. The constructor's
comment now says so.

`write` sends one or two registers, and every read in the package asks for
one or two, so nothing in the package reaches the limit. A consumer building a
`Write` by hand could.

## Options

1. A smart constructor and an abstract type, e.g. `Registers` with
   `registers :: NonEmpty Word16 -> Maybe Registers`, and `Quantity` made
   abstract with a `quantity :: Word16 -> Maybe Quantity`. This is "parse,
   don't validate", but it changes the module's exports, and
   `IDM.Navigator.Register` builds `Quantity 1` and `Quantity 2`
   literally.
2. A `Failure` constructor that `writeRegisters` and `readRegisters`
   return, unsent, for a count out of bounds. The exports stay the same,
   but the check moves to run time.
3. Leave it, documented.
