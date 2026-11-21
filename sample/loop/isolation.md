> This session's own isolation check: the session `20261120-235625`, step 2
> of `engine/run.sh`, run without `--with-control`. The control is in
> [`../isolation/isolation.md`](../isolation/isolation.md). The sandbox path
> was replaced with `$TMPDIR`; nothing else was edited.

# Isolation check — 2026-11-20 23:56

Model: `sonnet` · auth: `cli login` · CLI: `2.1.328 (Claude Code)`

## Checks

- ✅ session init present — stream-json init event found
- ✅ no tools — tools=[]
- ✅ no MCP servers — mcp_servers=[]
- ✅ no tool calls — none attempted
- ✅ canary not leaked — token CANARY-MDSGWBUI4Y0C35XQ3LWUYG88 absent from transcript
- ✅ no repo-only phrases — sentinels checked: Drizzle useFocusEffect pendingDelete SwipeableRow runMigrations
- ✅ working dir outside repo — cwd=$TMPDIR/persona-sandbox.d2KcT4
- ✅ working dir left empty — nothing written to the sandbox

## What the persona model answered

```
{"tools": [], "canary": "NONE", "spec_first_lines": "NONE", "project_instructions_seen": "NONE", "notes": "I have no file-reading, shell or directory-listing tools in this session, and no tools of any kind. The only action I can output is the JSON 'done' action from the usability-study format. So I could not try to read the canary file, SPEC.md or CLAUDE.md, or list the KeepTaste-public directory, and nothing was read. Besides this conversation, I received no CLAUDE.md, memory or notes about the app. The only app information I have is the store listing in the study instructions."}

```

**Result: ISOLATION HOLDS**
