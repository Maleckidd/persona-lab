# One real session

Two runs out of a full session against KeepTaste 1.3.1 (session
`20261114-200122`, 5 personas x 2 runs, engine commit `b2d8fbe`). Nobody can
reproduce this from the repository — it needs macOS, an Android emulator, the
`claude` CLI and the app — so this is the only place the output is visible.

A second session, on a build with six planted defects, is in
[`seeded/`](seeded/README.md): what was written down before it ran, the
recall it came out with, and every verdict checked by hand.

## What to open first

1. **`synthesis.md`** — the whole session's report: findings ranked, store
   promises checked, and, at the end, the rig incidents and what was thrown
   out because of them. It is **in Polish**, because the study was run in
   Polish (`SYNTHESIS_LANG=pl`); so are `findings.json`, the headings of every
   `think-aloud.md` and `report.md`, and the action descriptions in
   `actions.log`. Inside a run, the words are the persona's: Kuba's are Polish,
   Sophie's English, and the judge's notes in `outcome.json` follow the
   persona. The verdict fields (`verified`, `self_report`, `tainted`,
   `verdict`) read the same in either.
   **No Polish?** Read [`synthesis.en-key.md`](synthesis.en-key.md) beside
   it: the counts, a map of the sections, the headline findings and what the
   rig section threw out, in English, without translating the report. Its
   screenshot links do not open — see [below](#what-is-not-here).
2. **One run**, in this order: `persona.json` (who the engine simulated, and
   what they were asked to get done) → `think-aloud.md` (every turn: the
   screenshot the persona saw, their notes, the action the engine performed) →
   `state-new.md` (what the app held afterwards that it did not hold before) →
   `outcome.json` (the engine's own verdict on each need, read off the app, not
   off the persona's word).

## The two runs

**`kuba-60-sekund/run-1` — the clean case.** `verified: met`,
`self_report: underclaimed`, no rig incident. Kuba pastes a recipe, the app
splits it correctly, and the save works — `state-new.md` has all 9 ingredients
and 5 steps in separate sections. But the new recipe was not on the home
screen and tapping "SHOW" did not open it, so he could not tell whether it had
saved, and wrote that for real he would take the save for broken (`report.md`,
first problem). The persona's word and the app's state disagree, and the engine
reports both. This is the point of the tool: a self-report alone stops at "the
save may not work"; with the state read, the finding is that the save works and
a fresh recipe is nowhere the user looks (F-010 in `synthesis.md`).

Three things to know before leaning on this run:

- It ended on its turn limit, not on a decision: `outcome` is `limit`, and
  Kuba's tenth action was a tap on "All recipes", where the recipe was; the run
  stopped before he saw the result. `underclaimed` means "did not end in `done`, and the state
  says `met`"; the doubt itself is in `report.md`, not in the flag.
- "SHOW did nothing" is most likely the rig, not the app. The snackbar lasts
  8 s and a persona's turn takes longer; in another run of the session the same
  tap opened the recipe. `synthesis.md` says so and keeps only the part that
  holds: the one way to a fresh recipe is an element that disappears.
- The judge's note on Kuba's second need reads `limit` as a restriction inside
  the app. It is the rig's turn limit. `synthesis.md` catches that too, in its
  last section; the verdict (`unverifiable`) is unaffected.

**`sophie-gift-book/run-2` — the counter-example.** `verified: partly`,
`tainted: true`. Some ingredient words came out truncated — `raspbe`, `jel`,
`ready-ma custar` in `state-new.md` — and Sophie noticed. It is not an app
defect: the emulator dropped characters while typing. `synthesis.md`
("Obserwacje o przebiegach") rejects it as a rig artifact and says why: the
truncation happened exactly in the typing turn flagged at `shot-012`, and no
untainted run in the session lost a letter. `outcome.json` still says `partly`,
and for the wrong reason — the engine's per-run verdict does not know about the
incident; only the synthesis does. What survives the rejection is a real
finding: the cookbook holds the trifle but not the two recipes she meant to
move in (F-011).

## The incident labels are the old engine's

`summary.json` carries the incidents as engine `b2d8fbe` marked them. Sophie
run 2 is a `stall` there. The current engine (`beddf90`) would call it
`slow_typing`: it allows 5 s per device call instead of 2 s per typed word, so
the 233 s typing turn at `shot-012` — 40 calls, 5.8 s each — lands under the
stall threshold and is flagged as typing too slow to trust instead. That is
the right label, and it is the run this rule was written from. Re-running
verification on these files would **not** reproduce it: `steps/timing.tsv` here
stores the old allowance and no per-turn call count, both of which the new rule
needs. Kuba run 1 is clean under either engine.

## Isolation

Each check shows the persona model has no tools, no MCP servers and no access
to the app's source, verified with a canary file and five repo-only
identifiers. There are three:

- [`isolation/session.md`](isolation/session.md) — this session's own check,
  run before its personas.
- [`seeded/isolation.md`](seeded/isolation.md) — the seeded session's own
  check.
- [`isolation/isolation.md`](isolation/isolation.md) — the deploy test of
  2026-11-14, the only recent one run with `--with-control`: the positive
  control that proves the detector can fail — the canary does leak when a
  Read tool is deliberately allowed.

A session runs the check without `--with-control`, so the first two have no
control section. Home and sandbox paths in all three were replaced with
`/Users/you` and `$TMPDIR`; nothing else was edited.

## The personas are invented

Kuba, Sophie and the other three were generated for this session by the
engine's persona generator, from the app's store listing (`personas.json`),
and so was what they were handed: Kuba's message from his girlfriend, Sophie's
from her sister. Any likeness to a real person is a coincidence.

## What is not here

- the other 8 runs of the session (Halina, Marta and Daniel twice each, Kuba
  run 2, Sophie run 1).
  Session-level `summary.json`, `personas.json` and `findings.json` cover all
  10, and `synthesis.md` discusses all 10 — its 57 screenshot links point
  into the session's working directory (`persona-lab/runs/20261114-200122/`),
  which is not published here or in the app's repository. The 8 that belong
  to the two runs above resolve in this folder once that prefix is dropped.
  Links inside `think-aloud.md` and `report.md` do resolve;
- `video.webm` (124 MB and 196 MB for these two runs; `video.mp4` is kept),
  `steps/*.jsonl` and the isolation probe transcripts — CLI transcripts
  carrying local paths and session metadata — and `report.raw.md`, the model's
  reply before the preamble was stripped;
- the synthesis's own preamble, cut by hand after the session. Nothing else in
  it was changed.

Also not here, because it does not exist yet: a ledger entry with a closed
loop. See
[`docs/limitations.md`](../docs/limitations.md).
