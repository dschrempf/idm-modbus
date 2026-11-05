# UCHAR 254 at 1714 and 1715 may be -2

## The question

1714 and 1715, `Externe Anforderung Grundwasserpumpe …`, are `UCHAR`, `RW`,
volatile, with no range or default printed. Every other `UCHAR` that answers a
sentinel reads 255; these two read 254. `decode` treats both as `NoValue`
(`doc/verification-2026-09-19.md`, `doc/research.md` "`UCHAR` value 254").
Is 254 a second sentinel or a value?

The manual's footnote under them: the Navigator requests these pumps itself,
and a request over the building management system "ist somit nicht sinnvoll".

## New evidence, found while writing this note

- **The wire sends the whole word.** In the scan of 2026-10-14 12:11, all 15
  `UCHAR` sentinels arrive as `ffff`, and 1714 and 1715 as `fffe`. None
  arrives as `00ff` or `00fe`. `asWritten` keeps only the low byte, so it
  turns these into 255 and 254.
- **The controller prints -2.** `N2_GLTMON` in
  `captures/navigator-2.0-webapi-20.24-1574-2026-10-01-1158.json` prints 1714
  (`externe Anforderung Sole-/Zwischenkreispumpe`) and 1715 (`externe
  Anforderung Grundwasserpumpe`) as `-2`. In the same capture it prints 86, a
  `WORD` reading `ffff`, as `-1`.

So the controller treats these words as 16-bit two's complement: `fffe` is
its -2, not a byte of 254. That leaves open what -2 means. It could be "no
external request, the controller decides", which fits the footnote, or the
absence of a pump. This machine has neither pump, so it can't tell those
apart.

## Done on 2026-10-15

Steps 1 and 2: `doc/verification-2026-10-15-web-app.md` records the facts,
`doc/research.md` has the open question as "-2 at 1714 and 1715", and
`asWritten` reads a `UCHAR` as a signed word, `decode` taking every negative
one for no value. Of step 3, the web app was searched: it names the
registers, `N2_ERBP` and `N2_ERGP`, and says nothing of -2; no settings tree
holds the pumps, at Fachmann level either. Left: asking iDM support
(`ask-idm-support-for-812170-covering-20-24-2608`).

## How we might solve it

1. Record the two facts above in a dated `doc/`, and correct the open
   question in `doc/research.md`.
2. Decide whether `UCHAR` decoding should look at the whole word. `ffff` as
   -1 and `fffe` as -2 would match what the controller prints, and a `UCHAR`
   whose high byte is set would stop being silently truncated. That is a
   change to `asWritten` and `navigator` in `Register.hs`.
3. Find out what -2 means:
   - Search the controller's web JavaScript and translations for how it labels
     the two settings. That costs nothing.
   - Ask iDM support.
   - Read the Fachmann settings of these pumps in a webapi capture, if the
     tree has them.

   Writing 0 or 1 to the registers would also answer it, but the manual
   advises against requesting these pumps from outside, and writing is not
   implemented.
