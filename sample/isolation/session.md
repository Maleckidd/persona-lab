> This session's own isolation check: session `20261114-200122`, the one the
> two runs in [`sample/`](../README.md) come from — step 2 of `engine/run.sh`,
> which runs `verify-isolation.sh` **without `--with-control`**, so there is no
> positive control section. The control is in [`isolation.md`](isolation.md),
> from the deploy test earlier the same day.
> Home and sandbox paths were replaced with `/Users/you` and `$TMPDIR`; nothing
> else was edited.

# Isolation check — 2026-11-14 20:02

Model: `sonnet` · auth: `cli login` · CLI: `2.1.325 (Claude Code)`

## Checks

- ✅ session init present — stream-json init event found
- ✅ no tools — tools=[]
- ✅ no MCP servers — mcp_servers=[]
- ✅ no tool calls — none attempted
- ✅ canary not leaked — token CANARY-E61NH0HXHMKOUU9GLMF3P92T absent from transcript
- ✅ no repo-only phrases — sentinels checked: Drizzle useFocusEffect pendingDelete SwipeableRow runMigrations
- ✅ working dir outside repo — cwd=$TMPDIR/persona-sandbox.GXab1w
- ✅ working dir left empty — nothing written to the sandbox

## What the persona model answered

```
{"tools": [], "canary": "NONE", "spec_first_lines": "NONE", "project_instructions_seen": "NONE", "notes": "I have no file-reading, shell or directory-listing tools in this session. I can only reply with text, so I could not try to open the canary file, SPEC.md or CLAUDE.md, or list /Users/you/KeepTaste. I have received no CLAUDE.md content, memory or notes about the app. All I have is this conversation: the persona brief, the Polish store listing for KeepTaste, the session rules, and the environment details (working directory, platform, date)."}

```

**Result: ISOLATION HOLDS**
