# Research team

`examples/keeptaste/config-research/` swaps the users for a simulated research team, to ask where
the app could go rather than whether a task works. The team must not know the
product's intended limits, or it stays inside them, so nothing it reads is
written from the spec. Weighing its ideas against the spec is the owner's job,
after the study.

```bash
caffeinate -i bash "$PERSONA_LAB_ENGINE/run.sh" persona-lab/config-research \
  --personas-file persona-lab/config-research/personas.json
```

1. **Desk research** — runs whenever a config has `prompts/desk-research.md`. One
   agent with `WebSearch`/`WebFetch` and nothing else, in an empty directory,
   gets a topic, not the app or its name, and writes `desk-research.md`, a
   dossier of signals with numbered sources. `--dossier-file` reuses one from an
   earlier session.
2. **Hands-on** — seven specialists, each with a frame-breaking lens: rival
   founder, kitchen anthropologist, category designer, designer from other
   industries, business-model inventor, futurist, researcher of extreme users.
   Personas are still tool-free and can't see the repo. They know the app from
   one neutral sentence, and the dossier reaches them as text in the system
   prompt (`{{DOSSIER}}`). They report `Obserwacje`, which need a screenshot, and
   `Pomysły`, which don't and may ignore what the app is today.
3. **Synthesis** — the lead researcher keeps the outliers, cross-breeds ideas,
   and writes alternative futures, an idea portfolio and cheap real-world tests.
   A change to today's app is a price to state, never a veto.

**Scoped synthesis.** With `SYNTHESIS_SCOPE` set, the synthesis agent doesn't run
in the repository. It runs in a throwaway copy of the listed paths, after the
config's `scope_scrub` (here: comments removed, because they carry the spec's
reasoning), with no settings and no pre-approved tools, so reads outside it are
refused and no `CLAUDE.md` or memory loads. `verify-isolation.sh` proves this
before each session: told to read a canary inside the copy, a canary in the repo
and the `SCOPE_FORBIDDEN` files, the agent must get only the first. The session's
`scope-audit.txt` records what the real synthesis tried, and a forbidden file in
its transcript stops the session.

Simulated specialists are not users, and nothing here measures demand. Treat
the output as ideas to test on real people; the report ends with how.

