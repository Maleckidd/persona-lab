# Calibration on seeded defects

Never run on a real session yet; see [limitations.md](limitations.md).

How much of what is wrong do the personas catch? Plant a handful of usability
defects in a build, list them in a manifest (`engine/templates/seeded.json`),
run a normal session with `--seeded <manifest>`, and the engine reports recall:
the mutation-testing idea applied to a usability test.

- The personas can't see any file, and the synthesis is written before the
  scoring. Recall is measured on the personas' reports, never on the synthesis,
  because the synthesis reads the repository and could come across the manifest.
- Per defect: `reported` (in a report), `noticed` (only in the turn notes: the
  persona ran into it and didn't report it), `missed`, or `not_exercised`
  (nobody got there; left out of the denominator).
- A seeded session is archived in `history/` but stays out of the ledger.
- It measures misses, not false alarms: on a real app nobody knows the full
  list of true problems, so a finding outside the manifest is not a false one.
- With six defects the number is coarse. Use it to compare engine versions,
  models and persona sets against each other, on the same manifest.

For KeepTaste this is `examples/keeptaste/config-seeded/`.

