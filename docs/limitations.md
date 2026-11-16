# Known limitations

Written by the author, from iterations 11–14. Every entry says what happens,
how it was found, and what it means when you read a result. Line references
are to the engine at `beddf90`; run counts are real sessions against KeepTaste,
not tests.

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
has flagged 0 of 20 real runs across iterations 13–14, and none of the 20
should have been flagged, so nothing yet shows it can fire when it should. Only
the selftest covers the positive case. The opposite direction has fired for
real: `underclaimed` caught Kuba twice in the 2026-11-14 session, where the
recipe was saved correctly and he left certain it had not been. Until an
overclaim is caught in a real session, treat "no overclaim" as "not detected",
not as "did not happen".

### An underclaim on one need is not flagged

`underclaimed` requires the whole run to be `met` (`verify.sh:268`). A run
where one need is `met` with `claimed: false` and another is `partly` comes out
`consistent`. Per-need underclaims are therefore invisible in `summary.json`
and have to be read out of `outcome.json`.

## The rig

### The two state reads can run at different font scales

The app is read before the run under the device's own profile
(`engine/lib/persona-loop.sh:85`) and after it under the persona's
(`:240`), because `device_profile_apply` runs between them (`:86`).
`ui_collect` drops any line it already saw on an earlier screen
(`engine/lib/device.sh:251`), so whether a repeated heading survives depends on
the layout, which depends on the font scale. Result: a line in `state-new.md`
that the persona never wrote (`marek-60-sekund`, iteration 12, both runs).
*A fix is planned: read both states under the same profile.*

### The device profile does not survive a killed session

The restore runs on INT/TERM only (`persona-loop.sh:79`), and the "previous"
value is read off the device at the start of each run
(`device.sh:126`). Kill the session another way and the persona's font scale
becomes the next run's "previous". A leftover scale of 1.3 cost 6 of 10 runs in
iteration 12, because the example's demo reset taps fixed coordinates.
*A fix is planned: restore on EXIT, not on INT/TERM alone.*

### Corrupted typing is only partly caught

Two mechanisms produced corrupted text. One is fixed: `adb shell` drained the
text itself from stdin, so everything after the first line vanished, and a
persona gave up over "the app cuts my text off" (`device.sh:282-284`, now
`</dev/null` on every call). The other is mitigated, not removed: injected at
full speed, a loaded emulator drops characters inside a React Native
`TextInput` while the keyboard composes, so the engine types one word per
device call with a pause (`device.sh:291-313`) and flags a turn that averages
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

`config/calibration/real-testers.md` holds template lines. Simulated personas
are not users, and nothing here measures whether anyone wants the app. Findings
from a session are hypotheses about usability, at the resolution of what a
model can see in a screenshot.

## Coverage of the code itself

The selftest covers the logic that decides — 57 cases, no device and no model,
the CLI stubbed (`engine/selftest.sh:283`). It does not cover the two layers
that touch the world: `engine/lib/device.sh` (432 lines) and the run loop in
`persona-loop.sh` are exercised only by real sessions, which cost money and
need an emulator. *A loop test that needs no device is planned.*

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
