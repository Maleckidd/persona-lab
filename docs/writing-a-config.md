# Writing a config for your own app

Start by copying `engine/templates/` to `<your-repo>/persona-lab/config/`.
The engine never names an app: everything below lives in your config.

## Where things live

The engine is a clone anywhere on the machine and holds no state. The config,
`runs/` and `history/` stay in the app's repository: the synthesis runs there,
read-only, and cites the session by a path relative to it.

This repository:

| Path | What |
|---|---|
| `engine/` | the tool: `run.sh`, `verify-isolation.sh`, `selftest.sh`, `lib/`, `prompts/`, `templates/`. It never names an app |
| `examples/keeptaste/` | the configs of the app it was built on, as a snapshot (below) |
| `integrations/claude-code/` | the `/persona-test` command for Claude Code |

The app's repository, by the convention the defaults follow:

| Path | What |
|---|---|
| `persona-lab/config/` | the app's setup: `config.sh`, `brief*.md`, `personas.override.md`, `calibration/`. Start from `engine/templates/` |
| `persona-lab/config-<study>/` | focused studies built on `config/` (below) |
| `persona-lab/history/` | one file per session, plus the findings ledger (`findings.json`, `findings.md`); tracked |
| `persona-lab/runs/` | session output, git-ignored |

`runs/` and `history/` are the config's siblings unless `RUNS_DIR` and
`HISTORY_DIR` say otherwise. Nothing depends on the folder being called
`persona-lab`.

The app's repository does not pin a version of the engine. Each session writes
the engine commit it ran on into its `summary.json` and its history entry, with
a `+` when the engine had uncommitted changes.

An app detail goes in the app's `config/config.sh` (or a hook there), never in
the engine.

`bash engine/selftest.sh` checks the engine's own logic (rig incidents, outcome
verdicts, the evidence rule, the ledger, the comparison, the seeded score, the
history links, the isolation check against a stand-in CLI) in a few seconds,
with no device and no model. Run it after any change under `engine/`.

## What the app already has on the phone

What a persona already has on the phone is set up by the config, not typed:
`clipboard_set <file>` (full Unicode, through a one-button page in Chrome on
the emulator; it also turns off Chrome's first-run screens) and
`gallery_add <image>`. Photos stay in the gallery after the study that added
them, so `gallery_clear` removes them where another study's photo would steer
this one. The optional `state_ready` hook runs after the last cold
restart, for anything that restart would lose, like a share intent.


## Replacing the engine's prompts

A study of another *kind* can replace the instructions too. A file in
`<config>/prompts/` wins over the engine's prompt of the same name (`persona.md`,
`report.md`, `synthesis.md`, `generator.md`), and `EVIDENCE_SECTIONS` names the
report headings whose bullets need a screenshot.

