# A session on seeded defects

*Written on 2026-11-18, before the session ran. Everything below the line
"Result" is added afterwards; nothing above it is changed by the result.*

## What runs

- The app: KeepTaste at commit
  [`e394933`](https://github.com/Maleckidd/KeepTaste/commit/e394933), the 1.3.0
  release, with `seeded.patch` applied. The 1.3.1 build the other sessions ran
  on differs from it only in import's text clean-up (`utils/ocrText.ts`,
  `utils/recipeImport.ts`), none of it in the three files the patch touches;
  the build reports itself as 1.3.3 because Gradle ran on the untracked
  `android/` project last generated for the 1.3.3 release. The patch plants six
  usability defects, listed in `seeded.json`
  ([`examples/keeptaste/config-seeded/`](../../examples/keeptaste/config-seeded/)).
  No persona, and no synthesis, is told the manifest exists.
  *(Corrected on 2026-11-20: this line first named a commit from the app's
  history before it was rebuilt for publication, and called the code 1.3.1.)*
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

---

## Result

*Added after the session, on 2026-11-18.*

Session `20261118-141442`, engine `ddb4ab8`, the seeded build reporting itself
as 1.3.3. Six runs, none skipped, none tainted. 1 h 35 min wall clock; $2.20
for the runs, about $5.50 with the persona generator, the synthesis and the
scoring. The session's isolation check passed: [`isolation.md`](isolation.md)
(linked on 2026-11-20, when it was published).

**Recall: 3 of 4 reached defects reported, 0.75.** `recall_with_noticed` is
the same, 0.75: nothing was seen in the turn notes and left out of a report.
Two of the six defects were never reached. Without S1: 2 of 3.

| Defect | Scorer | By hand | What it rests on |
|---|---|---|---|
| S1 no confirmation after saving | reported | agree | Grażyna, who saved into a cookbook she had just made, so F-010 does not apply to her: *"wróciłam na sam początek, bez żadnego komunikatu"* ([report](grazyna-przepis-od-corki/run-1/report.md), [shot-016](grazyna-przepis-od-corki/run-1/shots/shot-016.png)). Kasia reports the same, but she saved with no cookbook, so her line fits F-010 as well. |
| S2 "Eksport" in the cookbook menu | not exercised | agree | nobody opened a cookbook's menu |
| S3 "Błąd." under an empty title | not exercised | agree | every title was filled in before saving |
| S4 no add button inside a cookbook | missed | agree, with a caveat | Grażyna, Marta and Tomek were inside cookbooks with recipes, which is the rule for `missed`. None of them wanted to add a recipe from there; Grażyna added hers from the home screen before her cookbook had anything in it. The defect had no chance to get in anyone's way. Counted as not exercised, recall would be 3 of 3; the rule is the rule, and the headline stays 3 of 4. |
| S5 empty search says the library is empty | reported | agree | three of three who searched: Tomek, Marta, Oliver (*"No recipes yet. Add your first one!"*, [shot-003](oliver-cooking-wifes-pierogi/run-1/shots/shot-003.png)) |
| S6 the import button says "Więcej" | reported | agree | Emily went looking for import and found it behind "More" ([shot-002](emily-sceptic-link-import/run-1/shots/shot-002.png)); Grażyna named the button as one she did not understand and left alone |

The hand check found no verdict to overturn. Each `reported` quote is in the
report it is attributed to, and each `not_exercised` holds against the turn
notes.

### What the number does not show

- **S5 was reached through a false premise.** All three personas who started
  on the demo library were given a need about a recipe "you already have" —
  goulash, gingerbread, pierogi — and the demo library holds none of them. The
  generator knows the library only from a one-line description, so it made the
  recipes up. Searching for something that is not there is what shows S5, so
  the defect was found partly because the personas were wrong about the
  library. A real user searches for missing things too, but here it happened
  to all three. See [limitations](../../docs/limitations.md#a-persona-can-be-told-it-has-a-recipe-the-library-does-not-hold).
- Four defects reached is a small denominator. One defect either way moves the
  number by 25 points.
- Findings outside the manifest are not scored. Two of them are large enough
  to name: Emily's link import failed with a network error, and Tomek was sent
  to Google Play while pasting a shopping list. Neither was looked into, and
  either could be the emulator rather than the app.

### Files

- `seeded-score.md`, `seeded-score.json` — as the engine wrote them.
- `summary.json`, `personas.json` — the session.
- `<persona>/run-1/` — each report, its `outcome.json`, and the screenshots the
  report cites. The turn notes and the other screenshots are not published.
- The manifest is
  [`examples/keeptaste/config-seeded/seeded.json`](../../examples/keeptaste/config-seeded/seeded.json),
  identical to the one the session ran on.
