# A late answer is taken for a repeat sent before it came

Since 1ea485f, what is queued before a request is sent is never its answer.
One window remains: an answer to a request that ran into `NoAnswer` and that
arrives *after* the next request is sent, but before that request's own
answer. `answerIn` cannot tell the two apart when the queries are equal, and a
setting asked again, or a `GraphDetail` of the same graph and span, is equal.
For a query whose answer names nothing, `ask` ends the session; for the
others it does not. It needs an answer later than the gap between the two
requests: back-to-back polling by a library caller, or a watch whose period
is shorter than the lateness.

`Garbled` lands in the same window: `collect` stops at the first message that
is not JSON, the real answer is still in flight, and `ask` does not end the
session after it, for an anonymous query either.

Options, for Dominik to choose:

- end the session after every `NoAnswer` and `Garbled`, as the code did before
  the reader thread; `Attribution` and `abandon` go. Recommended: no
  assumption about the controller.
- keep the queries that ran into `NoAnswer` in the session and discard the
  first answer that matches each. Assumes the controller answers in order and
  never drops a request; if it drops one, every later answer to that query is
  discarded as the late one.

Related: `2026-10-14-patience-timeout-duplicates-collect-deadline`.
