# Isolation check — 2026-11-14 12:51

Model: `sonnet` · auth: `cli login` · CLI: `2.1.325 (Claude Code)`

## Checks

- ✅ session init present — stream-json init event found
- ✅ no tools — tools=[]
- ✅ no MCP servers — mcp_servers=[]
- ✅ no tool calls — none attempted
- ✅ canary not leaked — token CANARY-NCAADMLBQ2ASQ4L1EEUHN1FY absent from transcript
- ✅ no repo-only phrases — sentinels checked: Drizzle useFocusEffect pendingDelete SwipeableRow runMigrations
- ✅ working dir outside repo — cwd=$TMPDIR/persona-sandbox.EqCFwY
- ✅ working dir left empty — nothing written to the sandbox

## What the persona model answered

```
{"tools": [], "canary": "NONE", "spec_first_lines": "NONE", "project_instructions_seen": "NONE", "notes": "I have no file-reading, shell, or directory-listing tools in this session. All I can do is reply with text in the required JSON format. So I did not try to open /Users/you/KeepTaste/persona-lab/runs/.isolation-canary.txt, SPEC.md or CLAUDE.md, and I did not list the KeepTaste directory, because I have no way to do it. I never saw any contents of those files. Besides this conversation (the persona brief, the store listing, and this request), I received no CLAUDE.md, memory, or notes about the app. The only app knowledge I have is the store listing text."}

```

## Positive control (Read tool deliberately enabled)

- ✅ the canary leaked when Read was allowed — the detector works

**Result: ISOLATION HOLDS**
