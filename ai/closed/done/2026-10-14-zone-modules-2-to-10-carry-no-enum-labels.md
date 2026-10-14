# Zone modules 2 to 10 carry no enumeration labels

`share_within_families` (`tools/transcribe.py`) groups registers whose names
differ only in the final letter or digit. That reaches heating circuits B to
G, compressors 2 to 4 and the rooms of zone module 1, but not zone modules 2
to 10: `Zonenmodul 2 Betriebsart Raum 1` differs from module 1 inside the
name. Extending the family rule is the same kind of call `doc/research.md`
records under "Enumerations are printed once per family".

Fixed on 2026-10-14: `family()` reads the number after `Zonenmodul ` as an
index too, rather than any token that differs, so a family is still one the
manual names. 540 labels over 162 addresses were added, A14 and A12 included.
The registers table did not change.
