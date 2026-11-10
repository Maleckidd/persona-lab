# shellcheck shell=bash
#
# Calibration on seeded defects: how much of what is wrong do the personas
# actually catch?
#
# The study owner builds the app with a handful of usability defects planted on
# purpose, lists them in a manifest, and runs a normal session on that build
# with --seeded <manifest.json>. Nobody in the session knows about the manifest:
# the personas cannot see any file, and the synthesis is written before the
# scoring. A scorer then compares the manifest with what the personas reported
# and gives recall — the mutation-testing idea, applied to a usability test.
#
# The manifest:
#   {"build": "free text: which build, which patch",
#    "defects": [{"id": "S1", "screen": "where it is, in user terms",
#                 "defect": "what was changed", "symptom": "what a user would run into"}]}
#
# Recall is measured on the personas' own reports, never on the synthesis: the
# synthesis reads the repository and could come across the manifest there.
#
# Source after common.sh and load_config.

# seeded_evidence <session-dir> — everything the personas said, per run.
seeded_evidence() {
  local session="$1" d rel f
  for d in "$session"/*/run-*/; do
    [ -f "$d/report.md" ] || continue
    rel="${d#"$session"/}"
    printf '## %s (outcome: %s)\n\n### Report\n\n' "${rel%/}" "$(jq -r '.outcome // "?"' "$d/summary.json" 2>/dev/null)"
    # Bullets without screenshot evidence were rejected; they do not count here either.
    sed '/^## Odrzucone/,$d' "$d/report.md"
    printf '\n### Turn notes\n\n'
    for f in "$d"/steps/shot-*.json; do
      [ -f "$f" ] || continue
      jq -r --arg sid "$(basename "$f" .json)" '"[\($sid)] saw: \(.see // "") | did: \(.do // "")" +
        (if (.surprise // "") != "" then " | surprise: \(.surprise)" else "" end)' "$f"
    done
    printf '\n'
  done
}

# score_seeded <session-dir> <manifest.json> — writes seeded-score.json and
# seeded-score.md into the session.
score_seeded() {
  local session="$1" manifest="$2" sys out
  jq -e '.defects | length > 0' "$manifest" >/dev/null 2>&1 || die "$manifest has no \"defects\" — see engine/templates/seeded.json"
  sys="$session/seeded-score-system.md"
  T_LANG="$SYNTHESIS_LANG" render_template "$(prompt_file seeded-score.md)" >"$sys"
  log "scoring $(jq '.defects | length' "$manifest") seeded defects ($MODEL_SCORER, no tools)…"
  out="$(user_message "# Planted defects

$(jq -r '.defects[] | "- \(.id) — screen: \(.screen // "?") — defect: \(.defect) — symptom: \(.symptom // "?")"' "$manifest")

# What the personas reported and noted

$(seeded_evidence "$session")

Reply with one JSON object only." |
    MAX_BUDGET_PER_CALL="$MAX_BUDGET_SYNTHESIS" isolated_claude "$MODEL_SCORER" "$sys" "$session/seeded-score.jsonl" | extract_json)"
  jq -e '.defects | type == "array"' <<<"${out:-null}" >/dev/null 2>&1 || {
    log "WARNING: the scorer gave no usable answer — see $session/seeded-score.jsonl"
    return 1
  }
  # Join with the manifest so a defect the scorer skipped still shows up, as missed.
  jq -n --argjson score "$out" --slurpfile manifest "$manifest" '
    ($score.defects | map({key: .id, value: .}) | from_entries) as $by |
    [$manifest[0].defects[] | . + ($by[.id] // {verdict: "missed", runs: [], quote: ""}) |
      .verdict |= (if IN("reported", "noticed", "missed", "not_exercised") then . else "missed" end)] as $rows |
    ([$rows[] | select(.verdict != "not_exercised")] | length) as $reachable |
    ([$rows[] | select(.verdict == "reported")] | length) as $reported |
    ([$rows[] | select(.verdict == "noticed")] | length) as $noticed |
    {build: ($manifest[0].build // ""), total: ($rows | length), reachable: $reachable,
     reported: $reported, noticed: $noticed,
     missed: ([$rows[] | select(.verdict == "missed")] | length),
     not_exercised: ([$rows[] | select(.verdict == "not_exercised")] | length),
     recall: (if $reachable > 0 then ($reported / $reachable * 100 | round / 100) else null end),
     recall_with_noticed: (if $reachable > 0 then (($reported + $noticed) / $reachable * 100 | round / 100) else null end),
     defects: $rows}' >"$session/seeded-score.json"
  {
    if [ "$SYNTHESIS_LANG" = pl ]; then
      printf '## Kalibracja na zasianych defektach\n\n'
      jq -r '"Build: \(.build)\n\n**Recall: \(.reported)/\(.reachable)" + (if .recall != null then " = \(.recall)" else "" end) +
        "** (zgłoszone w raportach person; mianownik bez defektów, do których nikt nie dotarł). " +
        "Z samym zauważeniem w notatkach: \(.reported + .noticed)/\(.reachable). " +
        "Poza zasięgiem tej sesji: \(.not_exercised) z \(.total).\n\n" +
        "To miara na \(.total) defektach, więc przedział niepewności jest szeroki; porównuj ją między sesjami, nie traktuj jak odsetka.\n"' "$session/seeded-score.json"
      printf '\n| ID | Ekran | Defekt | Wynik | Przebiegi | Cytat |\n|---|---|---|---|---|---|\n'
    else
      printf '## Calibration on seeded defects\n\n'
      jq -r '"Build: \(.build)\n\n**Recall: \(.reported)/\(.reachable)" + (if .recall != null then " = \(.recall)" else "" end) +
        "** (reported by the personas; defects nobody reached are left out of the denominator). " +
        "Counting what was only noticed in the turn notes: \(.reported + .noticed)/\(.reachable). " +
        "Out of this session'"'"'s reach: \(.not_exercised) of \(.total).\n\n" +
        "This is a measure over \(.total) defects, so its uncertainty is wide; compare it between sessions, do not read it as a rate.\n"' "$session/seeded-score.json"
      printf '\n| ID | Screen | Defect | Verdict | Runs | Quote |\n|---|---|---|---|---|---|\n'
    fi
    jq -r 'def cell: tostring | gsub("\\|"; "\\|") | gsub("\n"; " ");
      .defects[] | "| \(.id) | \(.screen // "" | cell) | \(.defect | cell) | \(.verdict) | \((.runs // []) | join(", ") | cell) | \(.quote // "" | cell) |"' "$session/seeded-score.json"
  } >"$session/seeded-score.md"
  log "seeded calibration → $session/seeded-score.md (recall $(jq -r '"\(.reported)/\(.reachable)"' "$session/seeded-score.json"))"
}
