# Fachmann entry right after leaving is ignored

## What happened

During the watch of 2026-10-16 the level was renewed at 08:43 by
`--leave-fachmann` and then `--enter-fachmann` straight away
(`captures/navigator-2.0-level-2026-10-16-0748.log`):

    08:43:00
    {"notificationSave":{"note":{"text":"cancellation has been executed successfully!","type":"success"}}}
    user level  Fachmann (2) -> Kunde (0)
    {"settingSave":{"note":{"text":"action has been executed successfully!","type":"success"},...}}
    user level  Kunde (0) -> Kunde (0)
    08:43:06

The controller confirmed the code's `save` and stayed at Kunde. At 08:44:57
it still read Kunde, and `--enter-fachmann` with the same hour's code worked
at the first attempt. 12763 and 6245 answered `NoAnswer` in between, about
two minutes of the watch; 4782 kept answering.

Not the cause: the code. It changes on the hour, and both attempts were in
hour 8 by the controller's clock.

## What the code already does

`change` asks for the level a second after sending, and `idm-web` dies with
"the level did not change" when it is not the one wanted. So the failure is
seen. Nothing acts on it: a caller that renews the level for a long watch
has to wait and try again itself, and only a shell loop did that on
2026-10-16.

## The measurement

After a run, with the machine at rest: leave, then enter after a pause of 1,
5, 10, 30 and 60 s, a few times each, and note which entries take. The 09:40
renewal of 2026-10-16 waited 20 s and took at the first attempt: left at
09:40:00, Fachmann again at 09:40:23.

Also untested: whether sending the code at Fachmann restarts the sixty
minutes. `enterFachmann` sends nothing at Fachmann, `AlreadyFachmann`. If it
does, renewing needs no leaving at all and the gap disappears.

## Options

1. `enterFachmann` retries itself, a bounded number of times, when the level
   after is still Kunde, with the pause the measurement finds. `Sent` would
   then record each attempt.
2. A `renewFachmann`: leave, wait the measured pause, enter, confirm. The
   only reason to leave and enter back to back is renewal, so the pause lives
   in one place.
3. `idm-web --watch` keeps the level itself, renewing before the sixty
   minutes run out, and records each change in the watch's own lines rather
   than in a separate log.

Measure first; then 2, with 3 as a consumer of it if long watches stay
common. Either way the finding goes into `Level`'s haddock and
`CLAUDE.md`'s description of the module.
