# The outcome check

Moved out of the README, where it was a subsection of "What the engine
does not take on trust". The rig and gesture controls are in
[how-it-works.md](how-it-works.md). What this check does *not* yet do is in
[limitations.md](limitations.md), and the sample session shows it on two
real runs ([../sample/](../sample/)).

**The outcome.** `done` is what the persona believes. With a `capture_state`
hook in the config the engine reads what is actually stored in the app, after
the reset and again after the run, both times after a restart so an unsaved
form doesn't count. The lines the second read adds are what the persona did.
Two checks use them:

- the persona's own `expect` patterns (hand-written personas only):
  `{"need": 1, "label": "the cake is saved", "matches": "piernik"}`,
  `{"need": 3, "label": "no private notes left", "lacks": "buziaki"}`. They
  are regular expressions and involve no model;
- a judge: one tool-free model call, isolated like a persona, that gets the
  needs, the materials and both states and answers per need `met`, `partly`,
  `not_met` or `unverifiable`, and, from the persona's closing words alone,
  whether the persona believes that need was achieved (`claimed`).

`summary.json` then has `verified` (`met` / `partly` / `not_met` /
`unverifiable`, or `none` when nothing was checked) and `self_report`.
`overclaimed` means the persona left with a belief the end state contradicts:
it stopped with `done`, and a need it does not itself call a failure has
nothing in the app, or one of the owner's patterns for such a need fails. That
is the most expensive kind of usability problem (the user leaves believing it
worked), and no report written by the persona can contain it. The synthesis
reports each one. The judge is a model reading a screen capture, so the
synthesis is told to open `state.md` itself before repeating a verdict.

Two things are deliberately not an overclaim. `done` with a reason that says
"I only got the eggs onto the list" claims nothing about the rest: the action
means "I am finished, successfully or not". And `partly` alone lowers
`verified` without flagging the run, because the judge gives it for an
inference it could not confirm as readily as for a missing step. The first
session with the check (iteration 11) flagged both of its runs under the older
rule, "done and not fully met", and neither persona had believed anything
false.

The check sees only what `capture_state` reads. A part of the app the hook
does not visit comes out as `not_met` for every need that lives there, so when
a verdict looks wrong, look at what the hook covers before blaming the judge.
