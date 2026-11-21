# The ledger loop, closed once

Two findings from the session in [`sample/`](../README.md) were fixed in the
app and marked `fixed` in its ledger. A later session, with the same five
personas, went through both flows. The engine moved both entries to
`verified`, and the evidence below was checked by hand.

## What ran

- The app: KeepTaste built from `main` at
  [`6bfdd2c`](https://github.com/Maleckidd/KeepTaste/commit/6bfdd2c). It
  carries both fixes:
  [Maleckidd/KeepTaste#29](https://github.com/Maleckidd/KeepTaste/pull/29)
  for F-010 and [Maleckidd/KeepTaste#28](https://github.com/Maleckidd/KeepTaste/pull/28)
  for F-025. The ledger was marked in
  [Maleckidd/KeepTaste#30](https://github.com/Maleckidd/KeepTaste/pull/30),
  which changes nothing in the app. The build reports itself as 1.3.3, for the
  reason given in [`../seeded/README.md`](../seeded/README.md).
- Session `20261120-235625`, engine `e967b2c`, 5 personas × 2 runs. The
  personas are the ones from session `20261114-200122` (`personas.json` is
  identical), so the comparison is persona for persona.
- The session's isolation check passed: [`isolation.md`](isolation.md).
- Cost: $3.74 for the runs and $2.94 for the synthesis, $6.68 in all. No
  persona generator ran. Wall clock: 2 h 58 min with the host awake, of which
  the runs themselves took 2 h 3 min.

## The two entries

| | F-010: a recipe saved with no cookbook could not be found | F-025: the "to try" switch sat at the bottom of the form, with no menu entry |
|---|---|---|
| Before | P1; reproduced in three sessions, last in 6 of 10 runs on 2026-11-14 | P1; Daniel, in both runs on 2026-11-14 |
| Fix | after saving, a new recipe opens on its own view (`d4fd23c`) | the switch sits under Cookbook; Mark/Unmark to try in the recipe's menu (`c86c460`) |
| This session | `not_reproduced` → **`verified`** | `not_reproduced` → **`verified`** |
| What it rests on | Three runs saved a new recipe without choosing a cookbook: Kuba run 1 and Daniel runs 1 and 2. Each landed on the recipe's own view with "Recipe saved" ([Kuba, shot-009](kuba-60-sekund/run-1/shots/shot-009.png); Daniel [run 1](daniel-sourdough/run-1/shots/shot-011.png), [run 2](daniel-sourdough/run-2/shots/shot-011.png)). Kuba's stored state has the recipe and his run is `met`. | Both of Daniel's runs show the switch on the form's first screen ([shot-002](daniel-sourdough/run-2/shots/shot-002.png)). In run 2 he marked the loaf from the menu ([shot-018](daniel-sourdough/run-2/shots/shot-018.png)), got "Marked to try" ([shot-019](daniel-sourdough/run-2/shots/shot-019.png)) and found it under the To try filter ([shot-022](daniel-sourdough/run-2/shots/shot-022.png)). His note on the menu: *"Pleased that the option is right here in the menu and easy to find."* |

Both entries rest on something the fix changed showing up on screen, not only
on the problem being absent. That matters for the first caveat below.

The ledger entries as the engine left them, with every sighting, are in
[`ledger.json`](ledger.json). F-036 is included too, for the second caveat.

## What this does not show

- **Absence alone proves little.** In the same session four findings nobody
  had fixed did not come back either: F-009 (an ANR), F-024, F-014 and F-008
  ([`compare.md`](compare.md)). The ledger promotes only an entry the owner
  marked `fixed`, but `not_reproduced` is the same weak signal for both kinds.
  Here the screenshots show the fixed behaviour. Without that, one session's
  silence would say little.
- **F-025 is closed on placement only.** A new P2, F-036, is about the same
  switch. In dark mode its knob is dark, and on the recipe view a dim "To try"
  chip sits next to a filled "Tried it ✓", so the lit chip looks like the
  selected one. Daniel, run 1, left the switch off without meaning to. The fix
  put the control where people find it. It did not make its state readable.
- **`not_reproduced` is the synthesis's call.** A model decides whether a
  persona went through the flow. Here every run it rests on was checked by
  hand against the screenshots and turn notes.
- **The first `overclaimed` on a real run was a false alarm.** Daniel, run 2,
  saved the loaf and marked it "to try", and the engine flagged him for
  claiming it. The config's state read takes the first screen of All recipes,
  ordered by last change, and a recipe marked "to try" sorts after the rest.
  In [shot-021](daniel-sourdough/run-2/shots/shot-021.png) Spaghetti Carbonara
  is first even though the loaf is the newest. The read missed the recipe:
  `state.md` is byte for byte `state-before.md`. Checked by hand against
  [shot-022](daniel-sourdough/run-2/shots/shot-022.png). The fix belongs in
  the example config's `capture_state`, and it has not been made. See
  [limitations](../../docs/limitations.md#overclaimed-has-never-fired-on-a-real-contradiction).
- **Two other `not_met` runs say nothing about the app.** Halina, run 2, is
  `tainted`: one turn of typing took 397 s, then a Google Play sign-in screen
  came up and the app was gone. Kuba, run 2, was told the recipe was on his clipboard, and
  in this study nothing puts it there; he tried to paste and gave up. That run
  is not flagged. See
  [limitations](../../docs/limitations.md#a-persona-can-be-told-something-is-on-the-clipboard-when-it-is-not).
- One session, one build, five personas. That a fix held for them on this
  path is all this shows.

## Before and after, in numbers

From [`compare.md`](compare.md), the engine's own comparison, in Polish like
the rest of the study's output. Read it as what changed, not as a
measurement.

| | 2026-11-14 (1.3.1) | 2026-11-20 (1.3.3) |
|---|---|---|
| Persona says done | 1 | 5 |
| Gave up | 8 | 5 |
| `met` from the stored state | 2 | 1 |
| `overclaimed` | 0 | 1 (false, above) |
| `tainted` | 3 | 1 |

The fall in `met` is the two rig runs and the false alarm above, not the app.

## Files

- `summary.json`, `personas.json`: the session, as the engine wrote them.
- `compare.md`: `run.sh --compare` on the two sessions.
- `ledger.json`: F-010, F-025 and F-036 from the app's `history/findings.json`
  after this session.
- `isolation.md`: the session's isolation check.
- `kuba-60-sekund/run-1/`, `daniel-sourdough/run-1/`, `daniel-sourdough/run-2/`:
  the three runs the two entries rest on. Each has its report, its
  `outcome.json`, the screenshots the report cites and the ones quoted above.
  The turn notes, the state reads and the other seven runs are not published.
  Neither is this session's synthesis; what it found is in the app's ledger.
