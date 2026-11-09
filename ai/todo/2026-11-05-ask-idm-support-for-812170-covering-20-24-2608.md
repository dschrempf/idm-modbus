# Ask iDM support for 812170 covering 20.24-2608

The table is transcribed from revision 12 of 812170, the Navigator 2.0's
Modbus manual, which documents software 20.23-515; the machine is a
Navigator 10 and runs 20.24-2608. Nothing public is newer: the
Loxone mirror did not resolve, the forum copies are older, iDM's media
library lacks 812170, guessed URLs 404 (`doc/research.md`, "Finding documents
on the iDM site"), and the partner portal needs partner access
(`adapt-to-software-20-24-2608`, `beyond-this-update.md`). What remains is a
mail to iDM support. One mail can ask everything the notes leave to them:

- a revision of 812663, the Navigator 10's Modbus manual, newer than rev. 0
  (18 June 2025, software 20.23-903 and 20.23-1336), or of 812170 (812570
  in English), for 20.24-2608, or what changed since 20.23: the
  addresses `N2_GLTMON` lists and revision 12 does not, among them 500 to
  526, 1174, 1950 to 1958, the locks at 4110, 4113 and 4114, and 4126 and
  4128, which revision 12 dropped and the machine serves; 4112, which
  revision 12 prints as a `FLOAT` and 2608 does not serve; 1072, printed as a
  `UCHAR` and two registers wide (`doc/software-versions.md`,
  `doc/research.md`, "Revision drift");
- what -2 at 1714 and 1715 means
  (`uchar-254-at-1714-and-1715-may-be-minus-two`);
- the labels of 3 and -1 at 1005
  (`operating-mode-3-and-minus-1-at-1005-unlabeled`);
- what 4108 does at -1, and what the locks at 4110 to 4114 do
  (`power-limit-4108-semantics-unknown`). Support told another user 4108 is
  "for internal use"; ask by its use, capping a PV run's draw, instead.

An answer is a source for the table only as a document; a mail's prose goes
into `doc/research.md`.

## 2026-11-09: 812663 found

812663 rev. 0, "Modbus TCP Navigator 10", is shipped by
Xerolux/idm-heatpump-api and is in `manual/` as `812663-rev0.pdf`. Its
parameter list is revision 12's but for zone rooms 7 to 9 and a footnote
(`doc/research.md`, "The authoritative source"), so it answers none of the
questions above; the mail now asks for a newer revision of it.
