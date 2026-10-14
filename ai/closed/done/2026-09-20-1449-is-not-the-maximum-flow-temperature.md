# 1449 is not the maximum flow temperature

Moving that setting to 42, 43 and 44 on circuits A, C and D changed no register
at all. The conclusion rests on the change having taken while it was made,
which was never confirmed on the display.

Redoing it means writing a setting, so it is a decision for Dominik, not
something to run unasked. The web backend can now confirm the other half
cheaply: `tools/webprobe.py` reads the settings tree, so a capture before and
after the change says whether the controller took it, without trusting the
display.
