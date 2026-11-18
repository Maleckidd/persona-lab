# Where this fits

persona-lab answers one question: can a person with these needs get this done
in the app, and does the app's stored state agree with what they believe
happened? It is for the problems nobody wrote a test for, because nobody knew
to expect them. It is not a replacement for any test that can be written.

## What it is for

**Flows that work and still fail the person.** In the [clean run in
`sample/`](../sample/README.md#the-two-runs) the save works: all nine
ingredients and five steps are stored in the right sections. Every assertion a
developer would write about saving passes. The person still left unable to tell
whether the recipe had saved, because a fresh recipe with no cookbook is
nowhere he looked (F-010, hit by 3 of the 5 personas in 6 of the 10 runs). A
test checks what its author expected to happen. A persona brings someone else's
expectations, and the state read makes sure the difference is reported as a
finding about the app, not as a complaint.

**What a person can find.** Several of the session's findings are about
something that exists but is not discoverable. A cookbook field in the recipe
form that no one noticed, with moving a recipe possible only through ··· → Edit
(F-011), and a "to try" toggle below the private notes at the very bottom of
the form (F-025): both work. A test that taps the right element passes, because
it already knows where the element is.

**Promises and builds side by side.** The synthesis checks the store listing's
promises against what the personas met. The "to try" list is one of them, and
with the toggle where it is, the synthesis calls that promise unkept in
practice. `--compare` lines up two sessions on two builds or two listings
([ledger.md](ledger.md#comparing-two-sessions)).

## What it is not for

**Anything a deterministic test can assert.** Parsing, storage, a crash on a
given input, a layout at a given font scale: if a finding can be written as an
assertion, write the assertion. A test is free, runs on every commit, takes
seconds and needs no judge. A session costs about $7 and 2 h, and its verdicts
are a model's ([limitations](limitations.md#the-outcome-check)).

**A regression gate.** The same end state can come out `partly` or `not_met`
([limitations](limitations.md#the-judge-is-unstable-at-the-partly--not_met-edge)),
and one run flipping from `give_up` to `done` proves nothing. A session says
what changed and where to look, not whether a build may ship.

**Demand, or real users.** Simulated personas are not users. Nothing here says
whether anyone wants the app, and a finding is a hypothesis at the resolution
of what a model can see in a screenshot.

## From a persona's report to a test

The path a finding is meant to take:

1. A persona's `report.md` and `think-aloud.md` describe what went wrong, in
   that persona's words.
2. The synthesis groups what several personas hit into one finding, maps it to
   screens and code, and gives it a ledger id.
3. The owner triages it. Some findings are the rig, not the app: the truncated
   ingredients in the [counter-example](../sample/README.md#the-two-runs) were
   the emulator dropping characters, and the synthesis threw them out. Those
   are marked `artifact`. The rest are `wontfix` or get a fix.
4. A deterministic finding gets a test in the app's own suite alongside its
   fix, so it is checked on every commit. The owner marks it `fixed`.
5. A later session with the same personas goes through the flow again. The
   ledger moves the finding to `verified` or `regressed`. The test says whether
   the code still does what was fixed, and the ledger says whether the fix
   helped the person it was made for.

No finding has gone the whole way yet: the ledger holds only `open` findings
([limitations](limitations.md#no-closed-loop-in-the-ledger)). This section gets
a worked example once one has.

## Next to the other tests

| Layer | Checks | Written by | Runs |
|---|---|---|---|
| unit tests | logic, parsers, the data layer | the developer | every commit |
| end-to-end tests | flows the developer knows, scripted step by step | the developer | every commit or nightly |
| persona-lab | flows nobody scripted, against someone else's expectations, with the stored state as the referee | the engine, from the app's public description | per study |

The engine's own logic is covered by the first kind: `engine/selftest.sh`, in
CI on every push. The app's unit and end-to-end tests live in the app's
repository, which is not public yet.
