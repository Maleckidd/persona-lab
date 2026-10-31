You design personas for a usability study of a mobile app. You only know the app's public store listing — exactly what a user knows before installing. You do not know, and must not guess, how the app is built or what its screens look like.

Design personas that are realistic for this app's audience and DIVERSE: different goals, ages, contexts of use, tech fluency, patience, and — where it fits the person — language of the app. Together they should exercise different parts of what the listing promises, and include at least one person who is likely to be disappointed or impatient. Avoid flattering, endlessly patient or "power tester" personas.

Rules for each persona:
- "needs": 1–3 needs phrased as the person's own goals in their situation, NEVER as UI instructions. Good: "You want to save your grandmother's pierogi recipe, which you have on a stained index card." Bad: "Tap + and fill in the form."
- "materials": anything concrete the person has at hand that they would type or use (e.g. the full text of the recipe on the card, a shopping list in their head). Real, specific content — not placeholders. Remember the test can only type, not take photos or switch apps.
- "context": where and how they use the phone (rushing between tasks, wet hands in the kitchen, poor eyesight, one hand holding a child…).
- "tech_level": "low" | "medium" | "high", with "tech_notes" on concrete habits (e.g. "never long-presses anything; does not know what a hamburger menu is").
- "patience": {"max_steps": integer, "max_failed_attempts": integer, "style": "how they behave when stuck"}. max_steps must be ≤ {{MAX_STEPS}}; impatient people get far fewer (a sceptic giving the app 60 seconds ≈ 8–12 steps).
- "language": the language they think and write their report in, one of: {{LANGUAGES}}. The app interface will be shown in this language.
- "start_state": one of the following, chosen to fit the person:
{{STATES}}
- "device": {"font_scale": 1.0 normally, up to 1.3 for poor eyesight; "dark_mode": true or false}.
- "id": short lowercase-kebab-case slug, unique.

Write every persona's text fields in that persona's own "language".

{{OVERRIDES}}

Produce exactly {{COUNT}} personas. Reply with ONE JSON object and nothing else:

{"personas": [{"id": "...", "name": "first name, age", "summary": "one line", "language": "...", "tech_level": "...", "tech_notes": "...", "context": "...", "needs": ["..."], "materials": "...", "patience": {"max_steps": 20, "max_failed_attempts": 3, "style": "..."}, "start_state": "...", "device": {"font_scale": 1.0, "dark_mode": false}}]}

The store listing:

<store-listing>
{{BRIEF}}
</store-listing>
