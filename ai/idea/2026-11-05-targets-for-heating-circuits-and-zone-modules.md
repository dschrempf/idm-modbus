# Targets for heating circuits and zone modules

`tools/transcribe.py` refuses a target that belongs to a family, i.e. whose
name carries a circuit letter A–G or starts with `Zonenmodul n`. That covers
404 of the 448 writable rows of the manual: 84 per circuit (12 registers × 7)
and 320 per zone module and room (4 × 10 × 8).

When the first of them is activated:

- Generate one constructor per family, taking a `Circuit` (A … G), or a
  `ZoneModule` (1–10) and a `Room` (1–8), from the vocabulary of
  `IDM.Navigator.Register`; `targetRegister` gets an equation per member.
- Only where every member is in the table. Otherwise each member is a
  constructor of its own, so the type admits no circuit the table lacks. The
  `gltmon` flow temperature rows at 1520–1540 exist for A, C and D only.
- Digits are not a family: `Bivalenzpunkt 1` and `2` are two parameters.
- The targets file names the family by the address of its first member.
