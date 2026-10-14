# Info rows keep HTML entities

`infoRows` (`src/IDM/Navigator/Web.hs`) strips tags but decodes no entity.
`4775 N2_DIGITAL_INPUTS` gives the label `Taupunktwächter&nbsp;Heizkreis A`,
and the controller also emits a malformed `&nbsp1` (`Laufzeit Stufe&nbsp1`,
in a two-cell table). Decide which entities to decode, and whether `&nbsp`
becomes a space or U+00A0.

Fixed on 2026-10-14: a cell reads `&nbsp;` and the bare `&nbsp` as a plain
space, as the hand-written web TSV writes the same label, and decodes `&amp;
&lt; &gt; &quot; &apos;` and numeric references; any other entity stays
verbatim. `webprobe.py` captures verbatim, so only `infoRows` changed.
