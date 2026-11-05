# Give the alarm codes at 1950 to 1958 a type

Since 20.24-2608, `N2_GLTMON` lists `Alarm Code 1` to `5` at 1950 to 1958,
one register each. On 2026-11-05 they read 20016 and 20005, the numbers the
web backend reports with the notices it names `N2_…`. The table rebuild for
2608 (`adapt-to-software-20-24-2608`, `table-rebuild.md`) adds them as plain
one-register rows, decoded as counts.

- A type of their own would join a code to its notice name. That needs a
  source mapping one to the other: the notices of a webapi capture pair a
  number with a name only for the notices that were active, and the
  controller's log (`N2_LOG_HISTORY`) pairs them for the past ones. Check
  whether the web interface's JavaScript holds the whole list.
- 0 reads where no alarm is held; whether that is a code or no value is part
  of the type.
