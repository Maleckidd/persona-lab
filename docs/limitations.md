# Known limitations

Written by the author, from iterations 11–14. Every entry says what happens,
how it was found, and what it means when you read a result. Line references
are to the engine in the commit that last changed this page; run counts are
real sessions against KeepTaste, not tests.

A reviewer's short version: the engine is good at catching a persona that
*gave up on work it actually finished*, and unproven at catching the opposite.
How much it finds at all has been measured once, on six planted defects:
3 of the 4 that somebody reached. The ledger has closed once: two fixes
confirmed by a later session.

## The outcome check

### `verified` barely discriminates

Across iterations 11–14, 2 of 22 checked runs came out `met`, and both are the
same persona in the same session (Kuba, 2026-11-14). 7 of the 10 runs in that
session are `partly`. The judge reaches for `partly` whenever a need needs an
inference, including runs where everything the persona was asked for is in the
app. Read `partly` as "not obviously missing", not as "half done", and read
`outcome.json`'s per-need notes rather than the single word.

### `met` can rest on one need while the others are never checked

The verdict counts only needs the judge could decide. Needs it marks
`unverifiable` — anything the app's end state cannot show — drop out of the
arithmetic entirely: `met` is "nothing came out `not_met`, `partly` or failed"
(`engine/lib/verify.sh:262`). The clean run in
`sample/` is exactly this case: Kuba's first need is `met`, his second ("see
straight away whether the app wants an account") is `unverifiable`, and the run
is `met`. That is defensible but easy to over-read. A `met` run is a claim
about the needs in `outcome.json` with a verdict, and about nothing else.

### The judge is unstable at the `partly` / `not_met` edge

Two runs with identical `state-new.md` — an empty shopping list named
"Tomorrow" — came out `not_met` and `partly` (`jamal-fridge-rush`, iteration
13). The `overclaimed` flag is defined across that edge, so the instability is
not cosmetic: the same end state can flag a persona as wrong or not.

### `overclaimed` has never fired on a real contradiction

The first rule flagged 2 of 2 runs falsely (iteration 11). The rule since then
flagged 0 of 20 real runs across iterations 12–14, and none of the 20 should
have been flagged. In the session of 2026-11-20 it fired once, and that was
false too ([`sample/loop/`](../sample/loop/README.md)). Daniel saved his loaf
and marked it "to try". The example config's state read takes the first screen
of All recipes, ordered by last change, and a recipe marked "to try" sorts
after the rest, so the read never reached it. His `state.md` is identical to
`state-before.md`, and the judge saw no recipe. A screenshot shows it under
the To try filter. The rule did what it should with what it was given. The
state read is what failed, and the fix belongs in the config's
`capture_state`; it has not been made. So nothing yet shows the rule can fire
on a real contradiction, and the one real alarm had to be overturned by
hand. Only the selftest covers the positive case. The opposite direction has
fired for real: `underclaimed` caught Kuba twice in the 2026-11-14 session, where the
recipe was saved correctly and he left unable to confirm it. Until an
overclaim is caught in a real session, treat "no overclaim" as "not detected",
not as "did not happen".

### An underclaim on one need is not flagged

`underclaimed` requires the whole run to be `met` (`verify.sh:268`). A run
where one need is `met` with `claimed: false` and another is `partly` comes out
`consistent`. Per-need underclaims are therefore invisible in `summary.json`
and have to be read out of `outcome.json`.

### `underclaimed` is read off how the run ended, not off what the persona believed

The rule is "the run did not end in `done`, and the state says `met`"
(`verify.sh:268`). It does not read the report. A persona that runs out of
turns with everything in place is flagged exactly like one that gives up in
doubt. The clean run in `sample/` ended on its turn limit (`outcome: limit`):
his tenth and last action was a tap on the list that held the recipe, and the
run stopped before he saw it. His report does say he could not tell whether the
save had worked, so the flag is right there, but on the report's evidence, not
the rule's. The judge is no help on this point: it is given how the run ended
and not the report, and in that run it marked the need `claimed: true`. Read
`underclaimed` as "stopped short of saying done", and open `report.md` for
whether the persona doubted the result.

## The rig

### The two state reads ran at different font scales — fixed

Until this fix the app was read before the run under the device's own profile
and after it under the persona's, because the profile went on between the two
reads. `ui_collect` drops any line it already saw on an earlier screen
(`engine/lib/device.sh:297`), so whether a repeated heading survives depends on
the layout, which depends on the font scale. Result: a line in `state-new.md`
that the persona never wrote (`marek-60-sekund`, iteration 12, both runs).

Both reads now run under the persona's profile (`read_before`,
`engine/lib/persona-loop.sh:55`), at the price of one more cold start per run.
Checked on the emulator on 2026-11-18, on the demo library, with the model
replaced by a stand-in that ends each run on its first turn, so that nothing
but the two reads can put a line in `state-new.md`. At font scale 1.3 both
runs gave an empty `state-new.md`; at 1.0, two of three did. The third lost
its first read to the problem in
[the entry below](#a-state-read-can-tap-the-wrong-thing), not to the font
scale: 134 lines came out as new. The two runs in
`sample/` were read before the fix. Kuba ran at the device's 1.0, so his are
unaffected; Sophie ran at 1.1, and every line in her `state-new.md` belongs to
the recipe and the cookbook she made.

### The device profile did not survive a killed session — fixed

Until this fix the restore ran on INT and TERM only, and the "previous" value
was read off the device at the start of each run. A session killed another way
left the persona's font scale on the device, and the next run took it for the
device's own. A leftover scale of 1.3 cost 6 of 10 runs in iteration 12,
because the example's demo reset taps fixed coordinates.

The device's own values are now kept in a file, `runs/.device-profile-<serial>`,
while a persona's are on. They are put back after each run, on any exit a
shell can trap (`device_exit_traps`, `engine/lib/device.sh:179`), and, after a
`kill -9` or a host that went down, at the start of the next session before
anything touches the app (`engine/run.sh:208`). A run never overwrites a file it
finds, because what the device shows at that point is a persona's.

The selftest covers the file rule and the traps against a stand-in `adb`,
including a TERM in the middle of a run, and each of its 8 cases was checked by
breaking the code it guards and watching it fail. On the emulator on
2026-11-18, a run at 1.3 was killed in the middle of a turn with `kill -9` on
its whole process group, so no trap ran. The device stayed at 1.3 and the file
held the device's own `1.0 no`. The next session reported the leftover, put
1.0 back before it touched the app, removed the file, passed the demo reset,
and read an empty `state-new.md`.

### Corrupted typing is only partly caught

Two mechanisms produced corrupted text. One is fixed: `adb shell` drained the
text itself from stdin, so everything after the first line vanished, and a
persona gave up over "the app cuts my text off" (`device.sh:328-330`, now
`</dev/null` on every call). The other is mitigated, not removed: injected at
full speed, a loaded emulator drops characters inside a React Native
`TextInput` while the keyboard composes, so the engine types one word per
device call with a pause (`device.sh:337-363`) and flags a turn that averages
more than `TYPE_CALL_SECONDS` a call as `slow_typing` (`verify.sh:30`).

Three caveats on that flag. The threshold sits between two observations — ten
long texts at up to 4.6 s a call arrived whole, one at 5.8 s did not — and is
not calibrated. Corruption from any other cause is still unflagged. And it
cannot be applied to old runs: `steps/timing.tsv` written before `beddf90`
holds no per-turn call count, so re-verifying such a run reports the turn as a
`stall` instead. The counter-example in `sample/` is one of those runs; its
`README.md` works the case through.

### A state read can tap the wrong thing

The example config reads the app the way a user would: it taps recipe cards,
cookbook tiles, list rows and Back, and never a control that changes data. One
of the eleven reads taken on 2026-11-18 came back with a recipe's action menu
(Edit, Delete, Cancel) and the system share sheet in it instead of the recipe.
It ran while another job on the same host was copying 14 GB, and the ten
taken on an idle host were clean, so load is the likely cause; a tap that
registers late can land as a long press. Nothing was deleted, but a read that
can open a menu with Delete in it could change what it reads. Nothing flags it:
it shows up only as a burst of lines in `state-new.md` that nobody wrote. Keep
the host otherwise idle during a session, and when `state-new.md` is longer
than what the persona did, read it against `state-before.md`.

### The synthesis does not mention skipped runs

A run that fails to start leaves no trace in the report. Nothing in a synthesis
tells you it covers 9 runs rather than 10 — check `summary.json`.

## The personas

### A persona can be told it has a recipe the library does not hold

The generator knows a start state only from the config's one-line description
(`STATE_DESC_demo`: "several cookbooks with a dozen or so recipes"), not what
is in it. In the seeded session of 2026-11-18 all three personas who started on
the demo library were given a need about a recipe they "already have" —
goulash, gingerbread, pierogi — and the library holds none of them (checked
against each run's `state-before.md`). All three spent turns searching for
it; for Oliver it was the whole run.

A run like that measures how the app handles a missing recipe, not the task the
persona was written for, and its `not_met` says nothing about the task. Read a
`demo` persona's needs against `state-before.md` before you read its outcome.
The fix is in the config, not the engine: a state description that names what
the library holds. KeepTaste's config has had one since 2026-11-20 (four
cookbooks, 14 recipes, which of them have photos;
[Maleckidd/KeepTaste#27](https://github.com/Maleckidd/KeepTaste/pull/27)). The
one session since reused the personas of 2026-11-14 (`--personas-file`), so
the generator has not been run with the list, and whether it keeps to it is
unmeasured. The engine still cannot check a need against the start state; a
config without such a list has the same problem.

### Under a CLI login, the persona also gets the CLI's own context

With no `ANTHROPIC_API_KEY`, persona calls run on the CLI's login, and the CLI
adds its own context note to the call even with `--tools ""`,
`--setting-sources ""` and a replaced system prompt: the account's e-mail
address, the working directory and its git status, the platform, the shell,
the OS version, the model name and the date. The seeded session's isolation
probe mentions it in its own answer ([`isolation.md`](../sample/seeded/isolation.md),
"an automatic context note with the user's account email"), and a direct probe
with the engine's persona flags on 2026-11-20 (CLI 2.1.326) listed those
kinds of item. Found by reading that answer and re-asking; the values were
not printed.

None of it is the app's source, so the isolation check passes and the canary
stays unread. But the persona is not given the brief alone: it knows it runs
in a temporary directory on a Mac, and the operator's e-mail address reaches
the model on every persona turn. Whether `--bare`, used when
`ANTHROPIC_API_KEY` is set, drops this note has not been checked.

### A persona can be told something is on the clipboard when it is not

The generator writes each persona's materials, and it can say where they are:
Kuba's recipe comes as a message "copied to the clipboard". The engine can
fill the clipboard (`clipboard_set`, `engine/lib/device.sh:63`), but only a
config's setup calls it, and the example's normal study does not. In the
session of 2026-11-20, Kuba's second run tried to paste, found the field
empty and gave up (`not_met`). On 2026-11-14 he hit the same empty field and
typed the recipe instead. Nothing flags it: the run is not `tainted`. Found by
reading the run against `persona.json`.

Read a `not_met` run that involves pasting against the persona's
`materials`. Either the config puts on the clipboard what the materials say,
or the materials must not claim it.

## What has not been measured

### Recall rests on one session and four defects

One seeded session has been run (2026-11-18, six personas, one run each). Of
six planted defects, two were never reached, three of the remaining four were
reported, and one was walked past: recall 0.75, every verdict checked by hand
([`sample/seeded/`](../sample/seeded/README.md)). Without the defect that
overlaps a problem the normal build already has, 2 of 3.

That is a small number on a small base. One defect either way moves it by 25
points, and the one `missed` is a defect nobody had a reason to run into: the
personas were inside a cookbook, but none wanted to add a recipe from there.
One of the three hits was found partly because the personas were wrong about
the library ([the entry above](#a-persona-can-be-told-it-has-a-recipe-the-library-does-not-hold)).
It answers "do the personas catch planted problems at all" with a yes. It does
not answer what fraction of an app's real problems a session finds, and it
says nothing about false alarms.

### The ledger has closed once

Two P1 findings from the session of 2026-11-14 were fixed in the app and
marked `fixed`. The session of 2026-11-20 ran the same five personas on the
fixed build, and the engine moved both to `verified`
([`sample/loop/`](../sample/loop/README.md)). Each verdict was checked by hand
against the screenshots: the fixed behaviour is on screen in three runs for
F-010 and in two for F-025. `fixed` → `regressed` has not happened on a real
session, and is covered by the selftest only.

Two things weaken the transition as a signal. First, `not_reproduced` is the
synthesis's judgment, a model's. Second, in the same session four findings
nobody had fixed (F-009, F-024, F-014, F-008) did not come back either. One
session's silence is the same weak signal whether or not a fix went in. What
makes these two stronger is that the screenshots show the new behaviour, not
only the old problem missing. And a fix can hold and still leave a problem:
F-036, new in that session, is about the same switch F-025 moved.

### No calibration against real users

`examples/keeptaste/config/calibration/real-testers.md` holds template lines. Simulated personas
are not users, and nothing here measures whether anyone wants the app. Findings
from a session are hypotheses about usability, at the resolution of what a
model can see in a screenshot.

## What a session records

### A session records the model alias, not the model

The config names models by alias: `MODEL_PERSONA=sonnet`,
`MODEL_GENERATOR=opus`, `MODEL_SYNTHESIS=opus`
(`engine/templates/config.sh:77-79`), and by default the judge and the scorer
inherit them. The CLI resolves an alias to whatever model it points at that day, and
the CLI is whichever `claude` is on `PATH`, else the newest copy bundled with
the desktop app (`engine/lib/common.sh:142`). The session's `summary.json`
records `session`, `app`, `version`, `engine` and `runs`
(`engine/run.sh:322`): the engine commit, but no model and no CLI version.
`isolation.md` names the persona alias and the CLI version, and the raw
transcripts a session keeps (`*.jsonl`) open with the resolved model, but the
engine reads neither back, and `sample/` publishes no transcripts. Found by
reading the code against a kept session.

A published number cannot be tied to the model that produced it, and two
sessions months apart may be comparing two models, not two builds.

### Nothing records whether the isolation check ran

`engine/run.sh --skip-isolation` skips step 2 (`engine/run.sh:85`, `:246`),
and `summary.json` has no field for it. The engine logs to the terminal only,
so the one trace of the check is the session's `isolation/` directory. Found
by reading the code.

"Isolation passed" can be shown only for a session that kept `isolation/`. A
session published without it cannot be told apart from one that never ran
the check; read the claim against that session's own `isolation/isolation.md`.

## Coverage of the code itself

The selftest has 90 cases and needs no device and no model. Besides the
logic that decides, it runs whole persona runs end to end
(`engine/selftest.sh:432`): `run_persona` as a session calls it, with `adb` and
`sips` replaced on `PATH`, the CLI replaced by a script that answers each turn
from a queue, and the config's hooks as shell functions. That covers what the
loop itself enforces — the patience cap, refused gestures, coordinates off the
screen, invalid replies, a failed reset, the order of the state reads and the
profile, the evidence rule on the report — and each of those cases was checked
by breaking the code it guards. Two more cases check that the four model-call
paths in `engine/lib/common.sh`, the synthesis included, start with
`CLAUDE_CODE_DISABLE_CLAUDE_MDS=1`, `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` and
`--setting-sources ""`; they show that a stand-in CLI is handed them, not that
the real CLI honours them.

What it cannot cover is what a real device does: how fast `adb input` really
types, a UI dump that fails mid-transition, the screen recorder, the emulator
dropping characters under load. The stand-in answers the same way every time.
Those, and every config's own hooks, are exercised only by real sessions,
which cost money and need an emulator. The selftest is written against the
system bash 3.2 on macOS; CI also runs it on Linux (bash 5, GNU tools), where
it passed on the first run and now fails the build like the macOS job.

Two import fixtures fetch live third-party pages
(`examples/keeptaste/config-import/clipboard/url-ok.txt`,
`url-microdata.txt`). When a site changes or goes away, the case changes with
it.

## Cost, time and platform

The 10-run session of 2026-11-14 cost **$6.61**: $4.10 the runs themselves,
$2.51 the persona generator and the synthesis. It wrote 1.6 GB, almost all of
it `video.webm`. The 10-run session of 2026-11-20 reused those personas and
cost **$6.68**: $3.74 the runs, $2.94 the synthesis. It took 2 h 58 min of
wall clock with the host awake, 2 h 3 min of it in the runs.

Wall-clock time is not the same as work. That session needed about 2 h of
model time and took 14.5 h, because the host's lid was closed for the night and
`caffeinate` does not hold a closed lid: one run alone recorded 12 h across ten
stalls. On the demo library the state reads dominate a healthy run — in the
`sample/` counter-example, setup and the first read took 460 s of a 996 s run.

macOS only for a session (`sips`, and `caffeinate` where present). Video needs
an emulator.

### Runs are sequential, on one device

A session drives one device (`ANDROID_SERIAL`) and runs one persona run at a
time, each persona's runs in turn (`engine/run.sh:315-320`); nothing in
`engine/` runs two at once, and a second emulator does not help. Wall-clock
time grows linearly with personas × runs: the defaults (`PERSONA_COUNT=5`,
`RUNS_PER_PERSONA=2`) are ten runs back to back, and a single run in the
`sample/` counter-example took 996 s.

### Every model call goes through one vendor's CLI

All model calls go through Anthropic's `claude` CLI, in one wrapper
(`claude_cli`, `engine/lib/common.sh:161`), and lean on its flags:
`--tools ""`, `--setting-sources ""`, `--max-budget-usd`, stream-json in and
out. The isolation is built from those flags. There is no other provider and
no API client. The CLI has to be authenticated for a non-interactive process
(`ANTHROPIC_API_KEY`, or a `claude setup-token` login; see
[Requirements](how-it-works.md#requirements)), and the copy bundled with the
desktop app is not logged in on its own. A change in the CLI's flags or in how
it logs in can stop a session or change what a call sees.
