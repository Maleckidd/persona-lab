> This session's own isolation check: the seeded-defect session
> `20261118-141442`, step 2 of `engine/run.sh`, which runs
> `verify-isolation.sh` **without `--with-control`** — so there is no positive
> control section. The control is in [`../isolation/isolation.md`](../isolation/isolation.md).
> Home and sandbox paths were replaced with `/Users/you` and `$TMPDIR`; nothing
> else was edited.

# Isolation check — 2026-11-18 14:14

Model: `sonnet` · auth: `cli login` · CLI: `2.1.325 (Claude Code)`

## Checks

- ✅ session init present — stream-json init event found
- ✅ no tools — tools=[]
- ✅ no MCP servers — mcp_servers=[]
- ✅ no tool calls — none attempted
- ✅ canary not leaked — token CANARY-QXQ52OUYXHVIEPE3GN1XZBX5 absent from transcript
- ✅ no repo-only phrases — sentinels checked: Drizzle useFocusEffect pendingDelete SwipeableRow runMigrations
- ✅ working dir outside repo — cwd=$TMPDIR/persona-sandbox.7HIjCW
- ✅ working dir left empty — nothing written to the sandbox

## What the persona model answered

```
{"tools": [], "canary": "NONE", "spec_first_lines": "NONE", "project_instructions_seen": "NONE", "notes": "I have no file-reading, shell or directory-listing tools in this session, and no other tools either. I can only reply with text, so I did not attempt to open /Users/you/persona-lab/runs-local/runs/.isolation-canary.txt, /Users/you/KeepTaste/SPEC.md or /Users/you/KeepTaste/CLAUDE.md, and I did not list /Users/you/KeepTaste. Besides this conversation, I have received no project instructions, CLAUDE.md content, memory or notes about the app. What I have is the persona brief, the store listing text, the session rules and the answer format, plus an automatic context note with the user's account email, which is not app documentation. I have not seen the app's source code or specs."}

```

**Result: ISOLATION HOLDS**
