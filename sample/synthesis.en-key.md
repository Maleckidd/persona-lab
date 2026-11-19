# English key to `synthesis.md`

[`synthesis.md`](synthesis.md) is the combined report of session
`20261114-200122`: KeepTaste 1.3.1, 5 personas x 2 runs = 10 runs, engine
commit `b2d8fbe`. The study ran in Polish, so the engine wrote the report in
Polish, and it is published as written: the only edit is its preamble, cut by
hand (see [`README.md`](README.md#what-is-not-here)). This page does not
translate it. It says
what is in each section and states the counts and findings in English, so a
reader who has no Polish can find the right part and check it against the
source. Every number below comes from `synthesis.md`,
[`summary.json`](summary.json) (per-run verdicts) or
[`findings.json`](findings.json) (the finding ledger for this session).

The five personas (from `summary.json`): Daniel, 45 (English); Halina, 71
(Polish); Kuba, 29 (Polish); Marta, 38 (Polish); Sophie, 34 (English).

**The screenshot links in `synthesis.md` do not open.** All 57 point into
the session's working directory (`persona-lab/runs/20261114-200122/…`), which
is not published here or anywhere else. The 8 that belong to the two runs
published in full do exist in this folder: drop the
`persona-lab/runs/20261114-200122/` prefix and the path resolves under
[`kuba-60-sekund/run-1/shots/`](kuba-60-sekund/run-1/shots/) or
[`sophie-gift-book/run-2/shots/`](sophie-gift-book/run-2/shots/). The other
49 belong to the eight runs that are not published.

## Verdict counts

`synthesis.md`, section "Podsumowanie" (Summary), lines starting
"Przebiegi" to "Tainted". All of these match `summary.json`.

| What is counted | Value | Runs |
|---|---|---|
| `verified: met` (the app's stored state shows the need met) | 2 | Kuba r1, Kuba r2 |
| `verified: partly` | 7 | Daniel r1, r2; Halina r1, r2; Marta r1, r2; Sophie r2 |
| `verified: not_met` | 1 | Sophie r1 |
| `self_report: overclaimed` (persona claimed more than the state shows) | 0 | |
| `self_report: underclaimed` (state shows more than the persona claimed) | 2 | Kuba r1, Kuba r2 |
| `tainted` (a rig incident during the run; suspect steps recorded) | 3 | Daniel r1, Daniel r2, Sophie r2 |

What the personas themselves declared at the end of a run (`outcome`):

| Declared | Count | Note in `synthesis.md` |
|---|---|---|
| `done` | 1 | Marta r1. Her own reason starts "Skończyły mi się kroki" ("I ran out of steps"); the state says `partly`. |
| `give_up` | 8 | |
| `limit` | 1 | Kuba r1. This is the rig's turn limit, not a restriction in the app. |

The tainted runs in `summary.json`: Daniel r1 has 1 stall (292 s, suspect
steps shot-005 to shot-008); Daniel r2 has 10 stalls (24,684 s in total, in a
run of 43,019 s); Sophie r2 has 1 stall (240 s at shot-012, suspect steps
shot-012 to shot-015).

## Section map

| Heading in `synthesis.md` | In English | What it contains |
|---|---|---|
| `# Synteza testów z personami — 20261114-200122` | Persona test synthesis | Title. |
| [`## Podsumowanie`](synthesis.md#podsumowanie) | Summary | Regression check against the ledger, the counts above, and five numbered headline conclusions ("Najważniejsze wnioski"). |
| [`## Problemy (od najważniejszych)`](synthesis.md#problemy-od-najważniejszych) | Problems, most important first | 12 problem findings. P1: F-010, F-024, F-011, F-025, F-009. P2: F-001, F-013, F-021. P3: F-020, F-014, F-019, F-026. |
| [`## Życzenia i inspiracje`](synthesis.md#życzenia-i-inspiracje) | Wishes and ideas | 14 feature requests (F-006, F-007, F-008, F-016, F-022, F-027 to F-035), each checked against the app's spec. F-022 (ingredient scaling) is marked out of scope. |
| [`## Obietnice opisu ze sklepu`](synthesis.md#obietnice-opisu-ze-sklepu) | Store-listing promises | A table of 13 claims from the app's store description, each with a verdict and evidence, then a list of 17 claims no persona exercised ("Obietnice, których nikt nie sprawdził"). |
| [`## Znane znaleziska`](synthesis.md#znane-znaleziska) | Known findings | The existing ledger, F-001 to F-023, all `open`, with what this session did to each: 14 `reproduced`, 1 `not_reproduced` (F-005), 8 `not_exercised`. |
| [`## Obserwacje o przebiegach`](synthesis.md#obserwacje-o-przebiegach) | Observations about the runs | Rig incidents and what was thrown out because of them; rig pacing against timed UI; the rig's ASCII-only typing; personas who misread the screen; judge verdicts the synthesis disagrees with. |

Labels that repeat inside each finding under "Problemy":

| Polish label | Meaning |
|---|---|
| Waga zgłoszona | Severity as the personas reported it: krytyczny (critical), poważny (major), drobny (minor) |
| Częstość | Frequency: personas out of 5, runs out of 10 |
| Co się dzieje | What happens |
| Dowody | Evidence (screenshot links) |
| Gdzie | Where in the app's code |
| Kierunek | Suggested direction for a fix |
| Gdzie persona się myli | Where the persona is wrong |

Verdict words in the store-promise table: "dotrzymana" (kept), "częściowo"
(partly), "niedotrzymana w praktyce" (not kept in practice), "brak
rozstrzygnięcia" (undecided). The tally is 10 kept (two of them qualified: "w
zakresie sprawdzonym", within what was tested, and "po stronie aplikacji", on
the app's side), 1 partly, 1 not kept in practice, 1 undecided.

## Headline findings

These are the summary's numbered conclusions 1 to 5. Persona and run counts
are from "Częstość" under each finding and agree with `findings.json`.

The summary also opens with a regression check: no finding marked fixed came
back, because the ledger has no fixed entries; the open F-009 (the app stops
responding, an Android ANR) recurred once, in Sophie r1, this time while
saving a cookbook rather than a recipe.

**F-010 (P1): a new recipe saved without a cookbook disappears from view.**
3 of 5 personas, 6 of 10 runs (Halina, Kuba, Daniel, both runs each). After
saving from the + button, the form closes onto a home screen that shows only
cookbook tiles; the recipe is listed only under "Wszystkie przepisy" (All
recipes), and the only cue is an 8-second snackbar "Przepis zapisany · POKAŻ"
("Recipe saved · SHOW"). Kuba saved a complete recipe in both runs and left
believing the save had failed, which is where the two `underclaimed` verdicts
come from. The report treats "SHOW does nothing" as most likely the rig's
pacing (an agent turn is longer than 8 s; in Halina r2 the same tap opened the
recipe) and keeps only this: the one route to a fresh recipe is an element
that disappears.

**F-024 (P1): timer chips break the text on first render.** 3 of 5 personas,
4 of 10 runs (Halina r1, Daniel r1, Daniel r2, Sophie r2). A cooking time in
the method text is shown as an inline timer chip; on its first frame the chip
has no size, the time is missing from the sentence and a horizontal line is
drawn through other words of the paragraph. The saved content is correct; the
chip is present in the state read. Halina r2 noticed the same thing but did
not report it, so it is not counted. Sophie's "box symbol" is the
object-replacement character in the accessibility text dump, not what the
screen shows.

**F-011 (P1): putting an existing recipe into a cookbook cannot be found.**
2 of 5 personas, 3 of 10 runs (Halina r1 and r2, Sophie r2). Halina created
her cookbook after saving the recipe; the cookbook field in the form did not
read to her as a place to create one, and in the recipe view the only way is
the ··· menu, which her persona avoids. Reported as critical by Halina in
both runs. Sophie r2 could not move two existing recipes into her new book.
The report confirms both personas are right: the ··· menu holds only Share,
Edit and Delete.

**F-025 (P1): the "Do wypróbowania" ("To try") toggle exists but nobody found
it.** 1 of 5 personas, 2 of 10 runs (Daniel r1 and r2). Daniel looked in the
new-recipe form, the edit form, the cookbook picker, the ··· menu and the
swipe actions. The toggle sits at the bottom of the form, below "Prywatne
notatki" (Private notes), and he never scrolled that far. His report says the
feature does not exist; the synthesis marks that as the persona being wrong
and files the finding as discoverability. It is P1 with one persona because
it blocks the need and the store listing promises the feature; that promise is
rated "niedotrzymana w praktyce" (not kept in practice).

**Strengths ("Mocne strony").** The summary lists five. Each of the first four
is one persona in both of their runs:

- importing pasted text: Kuba 2/2 (title, 9 ingredients and 5 steps split
  apart; `verified: met` x2);
- headings, bold and grams kept as typed: Daniel 2/2;
- A+/A− text size: Halina 2/2;
- "Wklej całą listę" ("Paste whole list") on the shopping list: Marta 2/2,
  so ledger finding F-005 did not recur;
- no account and no ads: the line gives no count; the store-promise table
  says no persona met an account, a consent screen or an ad.

## What the rig-incident section threw out

The first part of "Obserwacje o przebiegach", "Incydenty stanowiska (tainted)
i co z nich odrzuciłem" (rig incidents and what I rejected because of them):

- **Sophie r2.** Some ingredient words in her trifle came out truncated —
  "raspbe thawed", "jel", "ready-ma custar" — and they are stored that way in
  [`state-new.md`](sophie-gift-book/run-2/state-new.md). They were typed at
  shot-012, the step where the stall happened. Characters dropped in the
  middle of words, which fits `adb input` losing key events under load, and no
  untainted run lost a letter. The report rejects them as a rig artifact, and
  rejects them as the reason Sophie gave up. The judge's `partly` stands, but
  the report says it was reached for the wrong reason. What survives: Sophie's
  two existing family recipes are still not in the book (F-011). Her other
  evidence sits outside the suspect steps: the F-021 screenshots (shot-009,
  shot-010; the report says so) and the F-024 screenshot (shot-018, outside
  shot-012 to shot-015 in `summary.json`).
- **Daniel r2.** His complaint that the "SHOW" snackbar vanished and his tap
  landed on "+" (shot-010, shot-011) falls in a step with a 520-second stall
  and is rejected. The report keeps the mechanism as a note for the F-010 fix:
  the + button floats above the snackbar and slides into its place when it
  expires, so a late tap opens an empty form. His "to try" finding (F-025,
  shot-018 to shot-025) is kept, because it rests on valid screenshots and the
  same thing happened in Daniel r1.
- **Daniel r1.** The stall covers shot-005 to shot-008, and no finding comes
  from those steps.

The rest of that section: the 8-second snackbar against slow agent turns
(handled inside F-010, not as a separate defect); the rig cannot type
non-ASCII, so missing Polish letters, "26C" for "26°C" and "4-5 h" for
"4–5 h" are rig artifacts, and the synthesis disagrees with the judge counting
"°C → C" as a content change; six screen misreadings by personas (Daniel's
"to try does not exist", Sophie's box symbol, Kuba's dashes, Marta's search
result and failed send, Daniel on A+); and five judge verdicts it disagrees
with or refines, among them Kuba r1's `limit` being the rig's turn limit.

## The runs published in full

Two of the ten runs are in this folder with screenshots, think-aloud and state
reads: Kuba r1 (`kuba-60-sekund/run-1/`, the F-010 case) and Sophie r2
(`sophie-gift-book/run-2/`, the rig incident above). [`README.md`](README.md)
walks through both.
