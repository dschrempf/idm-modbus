# The event log

`idm-drive` writes one JSONL stream to stdout:

- **Reads:** a line per read, exactly the line `idm-dump --watch` writes,
  from `IDM.Navigator.Capture`.
- **Events:** a line with `time`, in the watch's stamp format, and `event`.
  A reader of a watch skips these lines, since they have no `status`.

The events:

| `event`      | fields                                                                     |
| ------------ | -------------------------------------------------------------------------- |
| `begin`      | `pid`, `schedule` (path), `final` (surplus, target, limit), `round`         |
| `session`    | `software`, `writable` (bool); a session opened                             |
| `lost`       | `why`; the session ended                                                    |
| `phase`      | `index`, `phase` (the phase as parsed, its keys as in the file)             |
| `start`      | 1100 read Ein for the first time                                            |
| `stop`       | 1100 read Aus after Ein                                                     |
| `export`     | `pv`, `draw`, `export` (pv less draw), `written` (after the bounds)         |
| `skip`       | `why`: no 4122 this round, no writable session                              |
| `write`      | `address`, `value`, `outcome` (`confirmed`, `did-not-stick`, `failed`, …), `detail` |
| `signal`     | `name`                                                                      |
| `final`      | the finals follow, as `write` events                                        |
| `end`        | `why`: `schedule`, `stop`, `signal`, `error`                                |

`pid` is the process to send SIGTERM to, as the first line of
`drivepv.py`'s log names it now.

## `runtable.py` (session 3)

- Given a drive file as WATCH, it takes the reads as now, and the writes of
  74 from the `write` events. Their times are exact, so the mean of 74 is
  as good as with `--writes` now.
- It adds an `export` column next to the written value of a `pv` phase, so
  a table shows how often the bounds acted.
- `--writes LOG` stays for the old text logs of `drivepv.py` that
  `captures/` holds.

The capture's name is `navigator-10-drive-SOFTWARE-YYYY-MM-DD-HHMM.jsonl`,
in `captures/README.md`. Each run until now made two files, a watch and a
write log, and it now makes one.
