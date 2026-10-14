# Register table drops unparseable rows silently

`navigator20 = mapMaybe parseRegister …` and `navigator20Enums` likewise
(`src/IDM/Navigator/Table.hs`) discard a row that does not parse. The only
guard is the literal `682` in `test/Main.hs`; `ParseError` is exported and
never constructed. `tools/transcribe.py`'s `ROW` accepts `CHAR` and `INT`,
which `parseDatatype` rejects, so a revision of the manual that uses either
would lose those rows from a consumer without a word.

Options: parse in the Template Haskell splice, so a bad row fails the build;
or expose `Either ParseError [Register]` and keep the test, comparing the
count with the embedded file's line count rather than a literal. Either way
`ParseError` gets used or goes.

Fixed on 2026-10-14: both TSVs are parsed in a typed Template Haskell splice
(`IDM.Navigator.Table.Parse`, internal), so a row that does not parse fails
the build and names its line. A stated cell is read or refused, the header
must match, and `ParseError` is gone. The literal `682` went with it: the
build already guarantees that every row parses.
