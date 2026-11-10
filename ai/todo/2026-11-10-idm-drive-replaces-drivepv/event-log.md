# The event log

`idm-drive` writes one JSONL stream to stdout:

- **Reads:** a line per read, exactly the line `idm-dump --watch` writes,
  from `IDM.Navigator.Capture`, printed as the read is made.
- **Events:** a line with `time`, in the watch's stamp format, `event`, and
  the fields below. A reader of a watch skips these lines, since they have
  no `status`.

Sessions 3 and 4 build against this table at once, so it is complete: a
field not listed is not written. Numbers are JSON numbers, in kW, seconds
or addresses; `why` and `detail` are strings; a missing value is `null`.

| `event`    | fields                                                                   |
| ---------- | ------------------------------------------------------------------------ |
| `begin`    | `pid`; `schedule`, the path; `text`, the file as read, comments included |
| `session`  | `software`, as a read line writes it; `writable`, a bool                 |
| `unopened` | `why`: no session could be opened                                        |
| `lost`     | `why`: the session ended                                                 |
| `phase`    | `index`, from 0 in the file's order; `phase`, its keys as in the file    |
| `start`    | none; `time` is that of the 1100 read                                    |
| `stop`     | none; `time` is that of the 1100 read                                    |
| `export`   | `pv`; `draw`; `export`, `pv` less `draw`; `written`, rounded and bounded |
| `skip`     | `address`; `why`: `no-draw`, `no-session` or `not-writable`; see below   |
| `write`    | `address`, `value`, `outcome`, `detail`                                  |
| `signal`   | `name`: `SIGINT` or `SIGTERM`                                            |
| `final`    | none; the finals follow, as `write` events                               |
| `end`      | `why`: `schedule`, `stop`, `signal` or `error`; `detail`, for an error   |

Outside the finals, a `skip` with `no-session` follows only a write that
lost the session, and one with `not-writable` does not occur: `idm-drive`
steps the schedule only in a round with a writable session, so a round
that cannot write leaves no line for what it held back
(`IDM.Navigator.Schedule.Log`).

`begin` holds the schedule's text, not only its path: `schedules/` is
tracked and will change, and the capture, which git does not hold, is the
evidence of what ran. `pid` is the process to send SIGTERM to, as the
first line of `drivepv.py`'s log names it now.

A `write`'s `outcome` names the case of `Outcome 'Free`, and `detail` is
`null` but where the table says:

| `outcome`          | case                      | `detail`                      |
| ------------------ | ------------------------- | ----------------------------- |
| `confirmed`        | `Sent Confirmed`          |                               |
| `did-not-stick`    | `Sent (DidNotStick b)`    | the bytes read back, in hex   |
| `unconfirmed`      | `Sent Unconfirmed`        |                               |
| `read-back-failed` | `Sent (ReadBackFailed f)` | the failure                   |
| `refused`          | `Refused r`               | why the value does not encode |
| `failed`           | `Failed f`                | the failure                   |

The first four were acknowledged. A `failed` write whose failure is not
`Unsent` went out and may have taken effect; its `detail` says which.
None of the three targets is write-only, so `unconfirmed` does not occur,
but the mapping is total.

## `runtable.py` (session 3)

- Given a drive file as WATCH, it takes the reads as now, and the writes of
  74 from the `write` events whose outcome was acknowledged, the first four
  above. That is what `--writes` takes from a `drivepv.py` log now, every
  line with `wrote`. Their times are exact, so the mean of 74 is as good as
  with `--writes`.
- It adds an `export` column next to the written value of a `pv` phase, so
  a table shows how often the bounds acted.
- Given a webwatch with level lines (`fachmann-in-the-web-watch.md`), it
  marks the rounds in which the level was not Fachmann, where 5888 and
  6245 have no answer.
- `--writes LOG` stays for the old text logs of `drivepv.py` that
  `captures/` holds.

The capture's name is `navigator-10-drive-SOFTWARE-YYYY-MM-DD-HHMM.jsonl`,
in `captures/README.md`. Each run until now made two files, a watch and a
write log, and it now makes one.
