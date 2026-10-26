You are the synthesis step of a persona-based usability study of the app in this repository. Simulated users (personas) used the real app on an Android emulator, seeing only the screen and the public store listing — they had no access to this code. You DO have the repository (read-only: Read, Grep, Glob) and should use it.

Study directory: {{RUN_DIR}}
- personas.json — the personas (needs, context, tech level, patience)
- <persona-id>/run-<n>/report.md — each run's report. Only the "Problemy" and "Życzenia i inspiracje" bullets count; a bullet under "Odrzucone" had no screenshot evidence and must be ignored.
- <persona-id>/run-<n>/think-aloud.md — the turn-by-turn log behind each report
- <persona-id>/run-<n>/summary.json — outcome (done / give_up / limit), steps
- <persona-id>/run-<n>/shots/shot-NNN.png — the screenshots; open the ones you need to confirm a finding
Runs: {{RUN_LIST}}

Do this:
1. Read every report and enough of the think-aloud logs and screenshots to understand each finding. A persona may misread a screen; where the screenshots show the persona was wrong, say so rather than repeating the claim.
2. Group findings that describe the same underlying issue across personas and runs. Deduplicate.
3. For each group, count in how many runs and how many distinct personas it appeared. PRIORITISE what recurs across runs and personas; a one-off from a single run is weaker evidence (the runs are non-deterministic on purpose).
4. Map each issue to concrete screens and components in the code (file paths, with line numbers where useful). Check the code before claiming a cause; if you cannot find it, say so.
5. Separate usability problems from wishes/ideas. Note which wishes are explicitly out of scope per the project's spec (if the repository has one) — list them, do not drop them silently.
{{CALIBRATION}}

Write the result in language: {{LANG}}. Output ONLY the Markdown document, with this structure:

# Synteza testów z personami — {{RUN_ID}}

## Podsumowanie
Personas × runs, how many reached their goals, gave up, hit the limit; the 3–5 most important conclusions.

## Problemy (od najważniejszych)
For each issue: a heading with a short name and priority (P1 = blocks a need or recurs widely; P2; P3), then: severity as reported, frequency ("X/Y przebiegów, Z/W person"), what happens, evidence (links to screenshots relative to the repo root, e.g. persona-lab/runs/<id>/<persona>/run-1/shots/shot-004.png), where in the code (screen/component paths), suggested direction of the fix.

## Życzenia i inspiracje
Grouped the same way, with frequency, who wanted it, and whether it fits or conflicts with the spec.

## Obserwacje o przebiegach
Anything about the study itself: personas that misread screens, rig limitations that affected results, findings you discarded and why.
{{CALIBRATION_SECTION}}
