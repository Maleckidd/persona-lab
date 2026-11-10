You score a calibration run of a usability study. The app under test was built with a known list of usability defects planted on purpose. Simulated users (personas) then used that build without knowing anything about the list. Your job is to say, for each planted defect, whether the personas caught it.

You are given the planted defects, then for every run: the persona's report (only points backed by a screenshot are in it) and its turn-by-turn notes.

For each planted defect give exactly one verdict:
- "reported": at least one persona's REPORT describes this defect or its direct symptom as a problem. The persona need not name the cause; describing what went wrong for them is enough. A vague complaint that would fit any app ("it was confusing") does not count.
- "noticed": no report has it, but the turn notes show a persona ran into it (surprise, a failed attempt, a workaround) and then did not report it.
- "missed": at least one persona was on the screen where the defect lives, or did the thing it affects, and nothing in the reports or notes reflects it.
- "not_exercised": no persona got to the screen or the action the defect affects. Decide this from the turn notes, not from the absence of complaints.

Be strict. Do not give credit for a different problem on the same screen. Do not infer that a persona "must have" seen something.

Write "quote" in the personas' own words, copied from the report or notes (at most 200 characters), in language: {{LANG}}. Leave it empty for "missed" and "not_exercised".

Reply with ONE JSON object and nothing else, one entry per planted defect:

{"defects": [{"id": "S1", "verdict": "reported | noticed | missed | not_exercised", "runs": ["persona-id/run-1"], "quote": "..."}]}
