# Known limitations

Written by the author, from iterations 11–14. Every entry says what happens,
how it was found, and what it means when you read a result. Line references
are to the engine in the commit that last changed this page; run counts are
real sessions against KeepTaste, not tests.

A reviewer's short version: the engine is good at catching a persona that
*gave up on work it actually finished*, and unproven at catching the opposite.
The measurement of how much it finds at all has not been made yet.

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
has flagged 0 of 20 real runs across iterations 12–14, and none of the 20
should have been flagged, so nothing yet shows it can fire when it should. Only
the selftest covers the positive case. The opposite direction has fired for
real: `underclaimed` caught Kuba twice in the 2026-11-14 session, where the
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

### The two state reads ran at different font scales — fixed, not yet confirmed on a device

Until this fix the app was read before the run under the device's own profile
and after it under the persona's, because the profile went on between the two
reads. `ui_collect` drops any line it already saw on an earlier screen
(`engine/lib/device.sh:297`), so whether a repeated heading survives depends on
the layout, which depends on the font scale. Result: a line in `state-new.md`
that the persona never wrote (`marek-60-sekund`, iteration 12, both runs).

Both reads now run under the persona's profile (`read_before`,
`engine/lib/persona-loop.sh:55`), at the price of one more cold start per run.
Nothing has checked that on a device yet: an untouched app read at font scale
1.0 and again at 1.3 must give an empty `state-new.md`. The two runs in
`sample/` were read before the fix. Kuba ran at the device's 1.0, so his are
unaffected; Sophie ran at 1.1, and every line in her `state-new.md` belongs to
the recipe and the cookbook she made.

### The device profile did not survive a killed session — fixed, not yet confirmed on a device

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
breaking the code it guards and watching it fail. The test the fix was written
for has not been run: `kill -9` in the middle of a run at 1.3 on the emulator,
then a new session whose demo reset passes.

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

### The synthesis does not mention skipped runs

A run that fails to start leaves no trace in the report. Nothing in a synthesis
tells you it covers 9 runs rather than 10 — check `summary.json`.

## What has not been measured

### No recall number

`--seeded` plants known defects and scores how many the personas find. It
exists, it has a selftest, and it has never been run on a real session, so
there is no answer to "what fraction of real problems does this find?" Every
finding in `sample/` is something the personas did notice; nothing here counts
what they walked past. *This entry is replaced by a number once a seeded session has been run.*

### No closed loop in the ledger

The ledger carries 35 findings, all `open`. The `fixed` → `verified` and
`fixed` → `regressed` transitions, which are the point of keeping it, are
covered by the selftest only. The one real signal so far is weaker: an open
finding (F-009, an ANR) came back in a later session in a new place.
*This entry is replaced once a fix has been confirmed by a later session.*

### No calibration against real users

`examples/keeptaste/config/calibration/real-testers.md` holds template lines. Simulated personas
are not users, and nothing here measures whether anyone wants the app. Findings
from a session are hypotheses about usability, at the resolution of what a
model can see in a screenshot.

## Coverage of the code itself

The selftest has 88 cases and needs no device and no model. Besides the
logic that decides, it runs whole persona runs end to end
(`engine/selftest.sh:400`): `run_persona` as a session calls it, with `adb` and
`sips` replaced on `PATH`, the CLI replaced by a script that answers each turn
from a queue, and the config's hooks as shell functions. That covers what the
loop itself enforces — the patience cap, refused gestures, coordinates off the
screen, invalid replies, a failed reset, the order of the state reads and the
profile, the evidence rule on the report — and each of those cases was checked
by breaking the code it guards.

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
it `video.webm`.

Wall-clock time is not the same as work. That session needed about 2 h of
model time and took 14.5 h, because the host's lid was closed for the night and
`caffeinate` does not hold a closed lid: one run alone recorded 12 h across ten
stalls. On the demo library the state reads dominate a healthy run — in the
`sample/` counter-example, setup and the first read took 460 s of a 996 s run.

macOS only for a session (`sips`, and `caffeinate` where present). Video needs
an emulator.
