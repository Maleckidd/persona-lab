# Focused studies

A study of one feature gets its own config directory next to `config/` that
sources the base one and overrides what differs: see
`examples/keeptaste/config-import/`. Personas
there are written by hand, because each one has to match the materials on the
device, and `SYNTHESIS_FOCUS` adds an instruction to the synthesis.

```bash
caffeinate -i bash "$PERSONA_LAB_ENGINE/run.sh" persona-lab/config-import \
  --personas-file persona-lab/config-import/personas.json
```

`caffeinate` doesn't stop the sleep of a closed MacBook lid. A session pauses
there and resumes on wake, and a network call right after waking can fail, so
keep the lid open (it cost one false "couldn't load the page" in iteration 7,
and twelve hours in a later session: the run in progress crawled through the
night on the system's maintenance wakes). For a session left overnight,
`sudo pmset -a disablesleep 1` holds a closed lid too; set it back to `0`
afterwards.

