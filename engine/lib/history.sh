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
  # Sessions recorded before the engine had a repository of its own have none.
  local engine
  engine="$(jq -r '.engine // empty' "$session/summary.json" 2>/dev/null)"

  # Where the raw data is, seen from the history file, and the same directory
  # as the synthesis wrote it: relative to the app repository, its working
  # directory. Neither assumes what the folder around runs/ is called.
  local runs_link runs_in_repo
  runs_link="$(rel_path "$RUNS_DIR" "$HISTORY_DIR")"
  runs_in_repo="${RUNS_DIR#"$APP_REPO"/}"

  local runs done gave limit skipped cost_runs cost_synth isolation
  runs="$(jq '[.runs[] | select(.outcome != "skipped")] | length' "$session/summary.json")"
  done="$(jq '[.runs[] | select(.outcome == "done")] | length' "$session/summary.json")"
  gave="$(jq '[.runs[] | select(.outcome == "give_up")] | length' "$session/summary.json")"
  limit="$(jq '[.runs[] | select(.outcome == "limit")] | length' "$session/summary.json")"
  skipped="$(jq '[.runs[] | select(.outcome == "skipped")] | length' "$session/summary.json")"
  cost_runs="$(jq '[.runs[].cost_usd] | add // 0 | . * 100 | round / 100' "$session/summary.json")"
  cost_synth="$(jq '.total_cost_usd // 0 | . * 100 | round / 100' "$session/synthesis.json" 2>/dev/null || echo 0)"
  isolation="$(sed -n 's/^\*\*Result: \(.*\)\*\*$/\1/p' "$session/isolation/isolation.md" 2>/dev/null | head -1)"

  # The engine's own checks. Sessions recorded before they existed have no
  # "verified" at all: they show "—", not a zero.
  local checked verified over tainted
  checked="$(jq '[.runs[] | select((.verified // "none") != "none")] | length' "$session/summary.json")"
  verified="$(jq '[.runs[] | select(.verified == "met")] | length' "$session/summary.json")"
  over="$(jq '[.runs[] | select(.self_report == "overclaimed")] | length' "$session/summary.json")"
  tainted="$(jq '[.runs[] | select(.tainted == true)] | length' "$session/summary.json")"
  if [ "$checked" = 0 ]; then
    verified="—"
    over="—"
  fi

  local L_ITER L_DATE L_APP L_ENGINE L_RAW L_PERSONAS L_RUNS L_COST L_ISO L_OUT L_TITLE L_CHECK L_SEEDED
  if [ "$SYNTHESIS_LANG" = pl ]; then
    L_TITLE="Iteracja"; L_DATE="Data"; L_APP="Wersja aplikacji"; L_ENGINE="Silnik (commit persona-lab)"; L_RAW="Surowe dane (lokalnie, poza gitem)"
    L_PERSONAS="Persony"; L_RUNS="Przebiegi"; L_COST="Koszt (orientacyjny)"; L_ISO="Izolacja person"
    L_OUT="przebiegów: %s — cel osiągnięty według persony: %s, rezygnacja: %s, limit: %s, pominięte: %s"
    L_CHECK="Kontrola silnika|stan końcowy potwierdza cel: %s z %s sprawdzonych, persona się myliła (overclaimed): %s, przebiegi z incydentem stanowiska: %s"
    L_SEEDED="Build z zasianymi defektami — sesja kalibracyjna, poza rejestrem znalezisk"
  else
    L_TITLE="Iteration"; L_DATE="Date"; L_APP="App version"; L_ENGINE="Engine (persona-lab commit)"; L_RAW="Raw data (local, not in git)"
    L_PERSONAS="Personas"; L_RUNS="Runs"; L_COST="Cost (approx.)"; L_ISO="Persona isolation"
    L_OUT="runs: %s — done according to the persona: %s, gave up: %s, limit: %s, skipped: %s"
    L_CHECK="Engine checks|end state confirms the goal: %s of %s checked, persona was wrong (overclaimed): %s, runs with a rig incident: %s"
    L_SEEDED="Build with seeded defects — a calibration session, kept out of the findings ledger"
  fi

  {
    printf '<!-- persona-lab-session: %s | iteration: %s | date: %s | version: %s | runs: %s | done: %s | verified: %s | tainted: %s | give_up: %s -->\n' \
      "$sid" "$num" "$date" "$version" "$runs" "$done" "$verified" "$tainted" "$gave"
    printf '# %s %s — %s · %s %s\n\n' "$L_TITLE" "$num" "$date" "$APP_NAME" "$version"
    printf -- '- **%s:** %s\n' "$L_DATE" "$date (session \`$sid\`)"
    printf -- '- **%s:** %s\n' "$L_APP" "$version"
    [ -n "$engine" ] && printf -- '- **%s:** `%s`\n' "$L_ENGINE" "$engine"
    printf -- "- **%s:** $L_OUT\n" "$L_RUNS" "$runs" "$done" "$gave" "$limit" "$skipped"
    printf -- "- **%s:** ${L_CHECK#*|}\n" "${L_CHECK%%|*}" "$verified" "$checked" "$over" "$tainted"
    [ -s "$session/seeded-score.md" ] && printf -- '- **%s**\n' "$L_SEEDED"
    printf -- '- **%s:** %s\n' "$L_ISO" "${isolation:-?}"
    printf -- '- **%s:** $%s + $%s\n' "$L_COST" "$cost_runs" "$cost_synth"
    printf -- '- **%s:** [`runs/%s/`](%s/%s/)\n\n' "$L_RAW" "$sid" "$runs_link" "$sid"
    printf '## %s\n\n' "$L_PERSONAS"
    jq -r '.personas[] | "- **\(.name)** (`\(.id)`, \(.language), \(.start_state), \(.tech_level)) — \(.summary)"' "$session/personas.json"
    if [ "$SYNTHESIS_LANG" = pl ]; then
      printf '\n| Persona | Przebieg | Wynik według persony | Stan końcowy | Kroki | Stanowisko |\n|---|---|---|---|---|---|\n'
    else
      printf '\n| Persona | Run | Outcome per persona | End state | Steps | Rig |\n|---|---|---|---|---|---|\n'
    fi
    jq -r '.runs[] | "| `\(.id)` | \(.run) | \(.outcome) | \(if (.verified // "none") == "none" then "—" else .verified end)" +
      "\(if .self_report == "overclaimed" or .self_report == "underclaimed" then " (" + .self_report + ")" else "" end) | \(.steps) | " +
      "\(if .tainted == true then "⚠ " + ([.taint[]? | "\(.kind) @ \(.at), \(.seconds) s"] | join("; ")) else "" end) |"' "$session/summary.json"
    printf '\n---\n\n'
    # The synthesis links screenshots from the repo root; here they are
    # relative to this file.
    sed -e '1{/^# /d;}' "$session/synthesis.md" |
      FROM="]($runs_in_repo/" TO="]($runs_link/" perl -pe 's/\Q$ENV{FROM}\E/$ENV{TO}/g'
    if [ -s "$session/seeded-score.md" ]; then
      printf '\n'
      cat "$session/seeded-score.md"
    fi
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
      printf 'Jedna iteracja = jedna sesja persona-lab (`engine/run.sh`). Pliki powstają automatycznie po syntezie.\n'
      printf 'Zrzuty ekranu i wideo zostają lokalnie w `runs/` (poza gitem).\n\n'
      printf '„Cel według persony” to deklaracja persony. „Potwierdzone” to przebiegi, w których stan końcowy aplikacji pokazuje osiągnięty cel\n'
      printf '(„—”: sesja sprzed tej kontroli albo bez niej). „Stanowisko” to przebiegi z incydentem (uśpiony komputer, zawieszone wywołanie).\n'
      [ -s "$HISTORY_DIR/findings.json" ] && printf '\nZnaleziska ze stałymi identyfikatorami i statusem: [findings.md](findings.md).\n'
      printf '\n| # | Data | Wersja | Przebiegi | Cel według persony | Potwierdzone | Rezygnacja | Stanowisko | Plik |\n|---|---|---|---|---|---|---|---|---|\n'
    else
      printf '# Persona testing history — %s\n\n' "$APP_NAME"
      printf 'One iteration = one persona-lab session (`engine/run.sh`), archived automatically after synthesis.\n'
      printf 'Screenshots and videos stay local in `runs/` (not in git).\n\n'
      printf '"Done per persona" is what the persona declared. "Confirmed" counts the runs whose end state shows the goal achieved\n'
      printf '("—": a session recorded before that check, or without it). "Rig" counts runs with an incident (host asleep, a hung call).\n'
      [ -s "$HISTORY_DIR/findings.json" ] && printf '\nFindings with stable ids and a status: [findings.md](findings.md).\n'
      printf '\n| # | Date | Version | Runs | Done per persona | Confirmed | Gave up | Rig | File |\n|---|---|---|---|---|---|---|---|---|\n'
    fi
    for f in "$HISTORY_DIR"/[0-9]*.md; do
      [ -f "$f" ] || continue
      meta="$(head -1 "$f")"
      printf '| %s | %s | %s | %s | %s | %s | %s | %s | [%s](%s) |\n' \
        "$(meta_field "$meta" iteration)" "$(meta_field "$meta" date)" "$(meta_field "$meta" version)" \
        "$(meta_field "$meta" runs)" "$(meta_field "$meta" done)" "$(meta_or_dash "$meta" verified)" \
        "$(meta_field "$meta" give_up)" "$(meta_or_dash "$meta" tainted)" \
        "$(basename "$f")" "$(basename "$f")"
    done
  } >"$HISTORY_DIR/README.md"
}

# meta_or_dash <meta-line> <field> — a field older history files do not have.
meta_or_dash() {
  local v
  v="$(meta_field "$1" "$2")"
  printf '%s' "${v:-—}"
}

meta_field() { printf '%s' "$1" | sed -n "s/.*$2: \([^|]*\) |.*/\1/p; s/.*$2: \([^|]*\) -->.*/\1/p" | head -1 | sed 's/ *$//'; }
