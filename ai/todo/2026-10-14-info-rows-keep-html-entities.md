# Info rows keep HTML entities

`infoRows` (`src/IDM/Navigator/Web.hs`) strips tags but decodes no entity.
`4775 N2_DIGITAL_INPUTS` gives the label `Taupunktwächter&nbsp;Heizkreis A`,
and the controller also emits a malformed `&nbsp1` (`Laufzeit Stufe&nbsp1`,
in a two-cell table). Decide which entities to decode, and whether `&nbsp`
becomes a space or U+00A0.
