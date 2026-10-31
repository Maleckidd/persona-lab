# shellcheck shell=bash
#
# The study history: one Markdown file per session ("iteration") in
# HISTORY_DIR, plus an index. Unlike runs/ (screenshots and videos, ignored by
# git) this is meant to be committed — it is the record of how the app's
# usability moves over time.
#
# Source after common.sh and load_config.

# archive_session <session-dir> — writes/updates the iteration file for this
# session and rebuilds the index. Re-synthesizing a session overwrites its own
# file and keeps its number; a new session gets the next number.
archive_session() {
  local session="$1" sid file num date version
  sid="$(basename "$session")"
  [ -s "$session/synthesis.md" ] || return 0
  mkdir -p "$HISTORY_DIR"
  HISTORY_DIR="$(cd "$HISTORY_DIR" && pwd)"

  file="$(grep -l "persona-lab-session: $sid " "$HISTORY_DIR"/[0-9]*.md 2>/dev/null | head -1)"
  if [ -n "$file" ]; then
    num="$(basename "$file" | sed 's/^0*\([0-9][0-9]*\)-.*/\1/')"
  else
    num=$(($(ls "$HISTORY_DIR"/[0-9]*.md 2>/dev/null | wc -l) + 1))
  fi
  date="$(echo "$sid" | sed 's/^\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\).*/\1-\2-\3/')"
  file="$HISTORY_DIR/$(printf '%02d' "$num")-$date.md"
  version="$(jq -r '.version // "?"' "$session/summary.json" 2>/dev/null)"

  local runs done gave limit skipped cost_runs cost_synth isolation
  runs="$(jq '[.runs[] | select(.outcome != "skipped")] | length' "$session/summary.json")"
  done="$(jq '[.runs[] | select(.outcome == "done")] | length' "$session/summary.json")"
  gave="$(jq '[.runs[] | select(.outcome == "give_up")] | length' "$session/summary.json")"
  limit="$(jq '[.runs[] | select(.outcome == "limit")] | length' "$session/summary.json")"
  skipped="$(jq '[.runs[] | select(.outcome == "skipped")] | length' "$session/summary.json")"
  cost_runs="$(jq '[.runs[].cost_usd] | add // 0 | . * 100 | round / 100' "$session/summary.json")"
  cost_synth="$(jq '.total_cost_usd // 0 | . * 100 | round / 100' "$session/synthesis.json" 2>/dev/null || echo 0)"
  isolation="$(sed -n 's/^\*\*Result: \(.*\)\*\*$/\1/p' "$session/isolation/isolation.md" 2>/dev/null | head -1)"

  local L_ITER L_DATE L_APP L_RAW L_PERSONAS L_RUNS L_COST L_ISO L_OUT L_TITLE
  if [ "$SYNTHESIS_LANG" = pl ]; then
    L_TITLE="Iteracja"; L_DATE="Data"; L_APP="Wersja aplikacji"; L_RAW="Surowe dane (lokalnie, poza gitem)"
    L_PERSONAS="Persony"; L_RUNS="Przebiegi"; L_COST="Koszt (orientacyjny)"; L_ISO="Izolacja person"
    L_OUT="przebiegów: %s — cel osiągnięty: %s, rezygnacja: %s, limit: %s, pominięte: %s"
  else
    L_TITLE="Iteration"; L_DATE="Date"; L_APP="App version"; L_RAW="Raw data (local, not in git)"
    L_PERSONAS="Personas"; L_RUNS="Runs"; L_COST="Cost (approx.)"; L_ISO="Persona isolation"
    L_OUT="runs: %s — done: %s, gave up: %s, limit: %s, skipped: %s"
  fi

  {
    printf '<!-- persona-lab-session: %s | iteration: %s | date: %s | version: %s | runs: %s | done: %s | give_up: %s -->\n' \
      "$sid" "$num" "$date" "$version" "$runs" "$done" "$gave"
    printf '# %s %s — %s · %s %s\n\n' "$L_TITLE" "$num" "$date" "$APP_NAME" "$version"
    printf -- '- **%s:** %s\n' "$L_DATE" "$date (session \`$sid\`)"
    printf -- '- **%s:** %s\n' "$L_APP" "$version"
    printf -- "- **%s:** $L_OUT\n" "$L_RUNS" "$runs" "$done" "$gave" "$limit" "$skipped"
    printf -- '- **%s:** %s\n' "$L_ISO" "${isolation:-?}"
    printf -- '- **%s:** $%s + $%s\n' "$L_COST" "$cost_runs" "$cost_synth"
    printf -- '- **%s:** [`runs/%s/`](../runs/%s/)\n\n' "$L_RAW" "$sid" "$sid"
    printf '## %s\n\n' "$L_PERSONAS"
    jq -r '.personas[] | "- **\(.name)** (`\(.id)`, \(.language), \(.start_state), \(.tech_level)) — \(.summary)"' "$session/personas.json"
    if [ "$SYNTHESIS_LANG" = pl ]; then
      printf '\n| Persona | Przebieg | Wynik | Kroki |\n|---|---|---|---|\n'
    else
      printf '\n| Persona | Run | Outcome | Steps |\n|---|---|---|---|\n'
    fi
    jq -r '.runs[] | "| `\(.id)` | \(.run) | \(.outcome) | \(.steps) |"' "$session/summary.json"
    printf '\n---\n\n'
    # The synthesis links screenshots from the repo root; from here they are ../runs/.
    sed -e '1{/^# /d;}' -e 's#](persona-lab/runs/#](../runs/#g' "$session/synthesis.md"
  } >"$file.tmp" && mv "$file.tmp" "$file"

  history_index
  log "history → $file"
}

# history_index — HISTORY_DIR/README.md, one row per iteration.
history_index() {
  local f meta
  {
    if [ "$SYNTHESIS_LANG" = pl ]; then
      printf '# Historia testów z personami — %s\n\n' "$APP_NAME"
      printf 'Jedna iteracja = jedna sesja `persona-lab/engine/run.sh`. Pliki powstają automatycznie po syntezie.\n'
      printf 'Zrzuty ekranu i wideo zostają lokalnie w `runs/` (poza gitem).\n\n'
      printf '| # | Data | Wersja | Przebiegi | Cel osiągnięty | Rezygnacja | Plik |\n|---|---|---|---|---|---|---|\n'
    else
      printf '# Persona testing history — %s\n\n' "$APP_NAME"
      printf 'One iteration = one `persona-lab/engine/run.sh` session, archived automatically after synthesis.\n'
      printf 'Screenshots and videos stay local in `runs/` (not in git).\n\n'
      printf '| # | Date | Version | Runs | Done | Gave up | File |\n|---|---|---|---|---|---|---|\n'
    fi
    for f in "$HISTORY_DIR"/[0-9]*.md; do
      [ -f "$f" ] || continue
      meta="$(head -1 "$f")"
      printf '| %s | %s | %s | %s | %s | %s | [%s](%s) |\n' \
        "$(meta_field "$meta" iteration)" "$(meta_field "$meta" date)" "$(meta_field "$meta" version)" \
        "$(meta_field "$meta" runs)" "$(meta_field "$meta" done)" "$(meta_field "$meta" give_up)" \
        "$(basename "$f")" "$(basename "$f")"
    done
  } >"$HISTORY_DIR/README.md"
}

meta_field() { printf '%s' "$1" | sed -n "s/.*$2: \([^|]*\) |.*/\1/p; s/.*$2: \([^|]*\) -->.*/\1/p" | head -1 | sed 's/ *$//'; }
