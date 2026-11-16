# The findings ledger, and comparing sessions

`history/findings.json` (tracked, with a readable `findings.md` next to it)
holds every finding under a stable id, with a status and each session that saw
it. The synthesis gets the ledger in its prompt, tags each of its findings with
the id it matches or `NEW-n`, and for the known ones it did not reproduce says
whether a persona went through that flow (`not_reproduced`) or nobody did
(`not_exercised`). The engine merges that and assigns the new ids.

```bash
bash "$PERSONA_LAB_ENGINE/run.sh" persona-lab/config --finding F-012 fixed "commit abc123"
```

| Status | Set by | Meaning |
|---|---|---|
| `open` | engine | reported, nothing decided |
| `fixed` | owner | a fix went in, not confirmed yet |
| `verified` | engine | marked fixed, then a later session went through the flow and it did not happen |
| `regressed` | engine | marked fixed (or verified), then a later session reproduced it |
| `wontfix`, `artifact` | owner | kept for the record; a new sighting doesn't reopen it |

Only a session started after the owner's verdict can confirm or refute it.
Re-synthesizing a session replaces what that session contributed and keeps its
ids. The ledger starts with the first session synthesized after it was added;
`--synthesize-only` on an older session adds that session's findings too (it
costs a synthesis). A confirmed, deterministic finding belongs in a unit or E2E
test as well: the ledger says whether a fix held in a later study, a test says
so on every commit.


## Comparing two sessions

```bash
bash "$PERSONA_LAB_ENGINE/run.sh" persona-lab/config --compare \
  persona-lab/runs/<session-A> persona-lab/runs/<session-B> > compare.md
```

The same personas (`--personas-file`) on two builds, or on two store listings
(two config directories with different briefs). No model call: outcomes,
verified outcomes, steps and rig incidents per persona, and the ledger ids that
are in one session and not in the other. Read it as what changed, not as a
measurement: one run flipping from `give_up` to `done` proves nothing.

