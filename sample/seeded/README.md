# A session on seeded defects

*Written on 2026-11-18, before the session ran. Everything below the line
"Result" is added afterwards; nothing above it is changed by the result.*

## What runs

- The app: KeepTaste at commit `08d9e4a` (the same app code as the 1.3.1 build
  the other sessions ran on), with `seeded.patch` applied. The patch plants six
  usability defects, listed in `seeded.json`
  ([`examples/keeptaste/config-seeded/`](../../examples/keeptaste/config-seeded/)).
  No persona, and no synthesis, is told the manifest exists.
- The study: `config-seeded`, which is the normal study with six generated
  personas and one run each.
- The engine at the commit recorded in `summary.json`, with the fixes of step 7
  of the publication plan (both state reads under one profile; the profile
  survives a killed session).
- One session. It is not re-run to improve the number.

## What gets published, whatever it says

- `seeded-score.md` and `seeded-score.json` as the engine wrote them, the
  manifest, `summary.json` and `personas.json`.
- Per defect: `reported` (in a persona's report), `noticed` (only in the turn
  notes), `missed`, or `not_exercised` (nobody reached that screen; left out of
  the denominator).
- The headline number is the engine's `recall`: reported over reached. Next to
  it, `recall_with_noticed`, and both denominators.
- The scorer is a model. Every `reported` and `noticed` verdict is checked by
  hand against the report or the turn note it rests on. Each disagreement is
  listed with the quote. The scorer's number stays the headline, and a
  hand-checked number is given beside it.
- A low number goes in the README the same way a high one would.
- A run lost to the rig (`skipped`, or `tainted`) is reported as such and stays
  in the session. If the whole session fails for a rig reason before scoring
  (the emulator dies, the host sleeps), it is run once more, and both are
  published with the reason.

## Known in advance

- **S1 overlaps with a problem the normal build already has.** S1 removes the
  confirmation after a recipe is saved. Without it, a recipe saved with no
  cookbook is still not visible on the home screen (F-010, in 6 of the 10 runs
  of the normal session in [`sample/`](../README.md)). A report saying "I could
  not tell whether it saved" fits both, and the scorer may credit S1 for it.
  The result gives recall with S1 and without it.
- Six defects make the number coarse: one defect moves it by about 17 points
  out of six reached. It says whether the personas catch planted problems at
  all, and it can be compared across engine versions, models and persona sets
  on the same manifest. It does not say what fraction of an app's real
  problems a session finds.
- It measures misses, not false alarms. A finding outside the manifest is not a
  false one.
