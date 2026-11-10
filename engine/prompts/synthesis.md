You are the synthesis step of a persona-based usability study of the app in this repository. Simulated users (personas) used the real app on an Android emulator, seeing only the screen and the public store listing — they had no access to this code. You DO have the repository (read-only: Read, Grep, Glob) and should use it.

Study directory: {{RUN_DIR}}
- personas.json — the personas (needs, context, tech level, patience)
- <persona-id>/run-<n>/report.md — each run's report. Only the "Problemy" and "Życzenia i inspiracje" bullets count; a bullet under "Odrzucone" had no screenshot evidence and must be ignored.
- <persona-id>/run-<n>/think-aloud.md — the turn-by-turn log behind each report
- <persona-id>/run-<n>/summary.json — outcome as the persona declared it (done / give_up / limit), steps, and the engine's own checks: "verified", "self_report", "tainted", "taint"
- <persona-id>/run-<n>/outcome.json — the outcome check: per need, whether the app's real end state shows it achieved ("needs"), and the study owner's patterns ("expect"). Present only when the study reads the end state.
- <persona-id>/run-<n>/state-before.md, state.md — what was stored in the app before and after the run, read from its screens after a restart
- <persona-id>/run-<n>/shots/shot-NNN.png — the screenshots; open the ones you need to confirm a finding
Runs: {{RUN_LIST}}

Do this:
1. Read every report and enough of the think-aloud logs and screenshots to understand each finding. A persona may misread a screen; where the screenshots show the persona was wrong, say so rather than repeating the claim.
2. Group findings that describe the same underlying issue across personas and runs. Deduplicate.
3. For each group, count distinct personas first and runs second. Two runs of one persona are not independent, and the personas are a small hand-picked set, not a sample of users: a count says how robustly an issue reproduces in this study, never how many real users it would affect. Do not write percentages and do not word a count as prevalence. PRIORITISE what recurs across personas; a one-off from a single run is weaker evidence (the runs are non-deterministic on purpose).
4. Map each issue to concrete screens and components in the code (file paths, with line numbers where useful). Check the code before claiming a cause; if you cannot find it, say so.
5. Separate usability problems from wishes/ideas. Note which wishes are explicitly out of scope per the project's spec (if the repository has one) — list them, do not drop them silently.
6. OUTCOME CHECK. A persona's "done" is its belief. Where a run has "verified", count goals as achieved by it, not by the declared outcome. Every run with "self_report": "overclaimed" is a finding of its own kind: the person left believing it worked and the app's end state says it did not. Report each as a problem (what the person believed, what outcome.json and state.md show, what on the screen produced the false belief). "underclaimed" (gave up although the state shows the need met) is worth a line too: the app did the job and failed to say so. Open state.md yourself before repeating a verdict; the check is a model reading a screen capture and can be wrong, and "unverifiable" means nothing either way.
7. RIG INCIDENTS. A run with "tainted": true had a rig incident (the host slept, a call hung); "taint[].suspect_steps" are the turns right after it. A failure that appears only in suspect steps — a network error, a timeout, a blank or stale screen — is an artifact of the test rig, not of the app: do not report it as a problem unless an untainted run shows the same. List every such case under "Obserwacje o przebiegach".
8. STORE LISTING. {{BRIEF_PATH}} is the text the personas read before installing. For each concrete promise in it that at least one persona put to the test, judge it against what happened: kept / partly / not kept, with the evidence. List the promises nobody exercised separately, without a verdict.
9. KNOWN FINDINGS. Findings from earlier sessions of this app are tracked in a ledger with stable ids:

<ledger>
{{LEDGER}}
</ledger>

For every finding of THIS session decide whether it is one of them (same underlying issue, even if worded differently or seen on another persona) and tag it with that id; otherwise give it a temporary key NEW-1, NEW-2, … For every ledger entry whose status is "open", "fixed" or "regressed" and that this session did not reproduce, decide between "not_reproduced" (a persona went through the screen or flow where it occurs and it did not happen) and "not_exercised" (nobody went there). Decide from the think-aloud logs, not from the absence of complaints; when in doubt it is "not_exercised". A "fixed" entry that happens again matters most: say so at the top of the summary.
{{CALIBRATION}}
{{FOCUS}}

Write the result in language: {{LANG}}. Output the Markdown document with this structure, then the findings block described at the end:

# Synteza testów z personami — {{RUN_ID}}

## Podsumowanie
Personas × runs; how many reached their goals according to the outcome check (and, separately, how many only declared it), gave up, hit the limit; how many runs were tainted; the 3–5 most important conclusions.

## Problemy (od najważniejszych)
For each issue: a heading that starts with its id in square brackets ([F-012] or [NEW-1]), then a short name and priority (P1 = blocks a need or recurs across personas; P2; P3), then: severity as reported, frequency ("Z/W person, X/Y przebiegów"), what happens, evidence (links to screenshots relative to the repo root, e.g. persona-lab/runs/<id>/<persona>/run-1/shots/shot-004.png), where in the code (screen/component paths), suggested direction of the fix.

## Życzenia i inspiracje
Grouped the same way, each heading starting with its id ([F-…] or [NEW-…]), with frequency, who wanted it, and whether it fits or conflicts with the spec.

## Obietnice opisu ze sklepu
A table: promise (quoted) | verdict | evidence. Then the promises nobody exercised.

## Znane znaleziska
A table of the ledger entries this session says something about: id | status in the ledger | this session (reproduced / not_reproduced / not_exercised) | one line of evidence. Leave the section out when the ledger is empty.

## Obserwacje o przebiegach
Anything about the study itself: personas that misread screens, rig incidents and what was discarded because of them, outcome-check verdicts you disagree with and why, findings you discarded and why.
{{CALIBRATION_SECTION}}

After the document, end your output with this block, exactly once. A program reads it: it must be valid JSON (double quotes, no comments, no trailing commas), inside the HTML comment exactly as shown.

<!-- persona-lab-findings
[
  {"id": "F-012", "status": "reproduced", "kind": "problem", "title": "short name, as in the heading", "priority": "P1", "personas": ["persona-id"], "runs": 3, "where": ["path/to/file.tsx:42"]},
  {"id": "NEW-1", "status": "reproduced", "kind": "wish", "title": "short name", "personas": ["persona-id"], "runs": 1, "where": []},
  {"id": "F-003", "status": "not_reproduced"},
  {"id": "F-007", "status": "not_exercised"}
]
-->

One entry per finding of this session (problems and wishes, "status": "reproduced", "kind": "problem" or "wish", "priority" for problems only, "runs" = number of runs it appeared in, "personas" = their ids), plus one entry per ledger finding with status "open", "fixed" or "regressed" that this session did not reproduce. Rig artifacts and findings you discarded do not go into the block.
