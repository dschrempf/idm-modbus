# The decision logic of write is untested

`write` decides between `Unchanged`, `CheckFailed`, `Sent Confirmed`,
`DidNotStick`, `Unconfirmed`, `ReadBackFailed` and `Failed`. That is the
part that guards the EEPROM, and no check covers it: `test/Main.hs` checks
`encode` and the framing, but `write` needs a `Connection`, and the suite
needs no heat pump.

Each of these changes either the package's interface or the shape of the
suite, so it is not chosen here:

1. **Abstract the two requests.** An exported
   `writeVia :: IO (Either Failure ByteString) -> (Write -> IO (Either Failure ())) -> IO () -> Target c -> Value -> IO (Outcome c)`.
   It takes the read, the write and the pause, and `write` is it applied to a
   connection. The test passes a fake that records what was sent. This adds
   to the public interface a function only tests call, unless an
   `IDM.Navigator.Write.Internal` is exposed for it.
2. **A fake Modbus server on localhost.** The test runs the real `write`
   over `withConnection` against a socket answering canned frames. It
   needs no change to the library, and covers the framing too. It does need
   `network` in the test suite, a thread, and checks in `IO`: today `checks`
   is `[(String, Bool)]`, and CLAUDE.md says an invariant is a new entry
   there.
3. **A pure plan.** Split `write` into a pure step from "what the pre-read
   returned" to "send this" or "stop with this outcome", plus the IO around
   it, and check the pure step. The smallest change to the suite; it still
   exports the plan, and leaves the IO glue unchecked.
