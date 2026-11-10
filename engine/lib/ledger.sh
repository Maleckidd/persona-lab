# shellcheck shell=bash
#
# The findings ledger: HISTORY_DIR/findings.json, one entry per finding with a
# stable id (F-001…), a status, and every session that saw it. It is what lets
# a study answer "did the fix hold?" instead of starting from zero each time.
#
#   open ──owner──▶ fixed ──not reproduced though exercised──▶ verified
#                     └───────────reproduced again────────────▶ regressed
#   wontfix / artifact: set by the owner, kept, never reopened by a sighting
#
# The synthesis gets the ledger in its prompt, tags each finding with the id it
# matches (or NEW-n), and ends its answer with a machine-readable block. The
# engine merges that block here; the owner sets "fixed" with
#   run.sh <config> --finding F-012 fixed "commit abc123"
#
# Source after common.sh and load_config.

ledger_file() { echo "$HISTORY_DIR/findings.json"; }

ledger_init() {
  mkdir -p "$HISTORY_DIR"
  [ -s "$(ledger_file)" ] || printf '{"next": 1, "findings": []}\n' >"$(ledger_file)"
}

# ledger_for_prompt — the known findings, one per line, for the synthesis.
ledger_for_prompt() {
  [ -s "$(ledger_file)" ] || { echo "(none yet — this is the first tracked session)"; return 0; }
  jq -r '.findings | if length == 0 then "(none yet — this is the first tracked session)" else
    map("- \(.id) [\(.status), \(.kind)\(if .priority then ", " + .priority else "" end)] \(.title)" +
      (if (.where // []) | length > 0 then " — " + (.where | join(", ")) else "" end)) | join("\n") end' "$(ledger_file)"
}

# extract_findings <synthesis.md> — prints the JSON array from the trailing
# <!-- persona-lab-findings … --> block and removes the block from the file.
# Prints nothing when the block is missing or is not a JSON array.
extract_findings() {
  local md="$1" json
  json="$(perl -0777 -ne 'print $1 if /<!--\s*persona-lab-findings\s*(.*?)-->/s' "$md" | jq -c 'if type == "array" then . else empty end' 2>/dev/null)"
  perl -0777 -i -pe 's/\s*<!--\s*persona-lab-findings.*?-->\s*/\n/s' "$md"
  printf '%s' "$json"
}

# ledger_merge <session-dir> <findings-json> — merges one session's findings
# into the ledger, writes <session>/findings.json with the final ids, and
# replaces NEW-n in the session's synthesis.md by the ids just assigned.
# Merging the same session again replaces what it contributed before.
ledger_merge() {
  local session="$1" found="$2" sid version ledger tmp
  sid="$(basename "$session")"
  version="$(jq -r '.version // "?"' "$session/summary.json" 2>/dev/null || echo '?')"
  ledger_init
  ledger="$(ledger_file)"
  tmp="$ledger.tmp"
  jq --argjson found "$found" --arg sid "$sid" --arg version "$version" '
    def pad: tostring | ("000" + .)[-3:];
    def sighting($f; $before): {session: $sid, version: $version, result: ($f.status // "reproduced"),
      priority: ($f.priority // null), runs: ($f.runs // null), personas: ($f.personas // []), status_before: $before};
    def norm: ascii_downcase | gsub("\\s+"; " ") | sub("^ "; "") | sub(" $"; "");
    # 1. forget what this session said before (a re-synthesis). A status the
    #    engine derived from that sighting goes back; one the owner set stays.
    .findings |= map(
      ([.sightings[] | select(.session == $sid)] | first) as $old |
      if $old then
        (if .status == "verified" or .status == "regressed" then .status = ($old.status_before // .status) else . end) |
        .sightings |= map(select(.session != $sid))
      else . end)
    | .assigned = {}
    # 2. apply the findings of this session
    | reduce $found[] as $f (.;
        ($f.id // "NEW") as $id |
        # A finding the synthesis calls new but that has the title of a known
        # one is that one: ids must survive a re-synthesis of the same session.
        ((.findings | map(.id) | index($id)) //
          (if ($f.title // "") != "" then (.findings | map(.title | norm) | index($f.title | norm)) else null end)) as $at |
        if $at != null then
          ($f.status // "reproduced") as $r |
          (if .findings[$at].id != $id then .assigned[$id] = .findings[$at].id else . end) |
          if $r == "not_exercised" then .
          else .findings[$at] |= (
            .status as $before |
            # Only a session run after the verdict of the owner can confirm or refute it.
            ($sid > (.status_changed_at // "")) as $later |
            .sightings += [sighting($f; $before)] |
            (if $r == "reproduced" then
               (if $later and ($before == "fixed" or $before == "verified") then .status = "regressed" else . end) |
               (if $f.priority then .priority = $f.priority else . end) |
               (if (($f.where // []) | length) > 0 then .where = $f.where else . end)
             elif $r == "not_reproduced" and $later and $before == "fixed" then .status = "verified"
             else . end))
          end
        elif ($f.title // "") != "" and (($f.status // "reproduced") == "reproduced") then
          ("F-" + (.next | pad)) as $new |
          .findings += [{id: $new, kind: ($f.kind // "problem"), title: $f.title, priority: ($f.priority // null),
            status: "open", where: ($f.where // []), first_seen: $sid, last_seen: $sid, note: "",
            sightings: [sighting($f; "open")]}] |
          .assigned[$id] = $new | .next += 1
        else . end)
    # 3. a finding this session created earlier and no longer reports is gone
    | .findings |= map(select((.sightings | length) > 0 or .first_seen != $sid))
    | .findings |= map(.last_seen = (([.sightings[] | select(.result == "reproduced") | .session] | last) // .first_seen))
  ' "$ledger" >"$tmp" || { rm -f "$tmp"; log "WARNING: could not merge the findings into $ledger"; return 1; }

  jq --argjson found "$found" '.assigned as $a | $found | map(if $a[.id // "NEW"] then .id = $a[.id // "NEW"] else . end)' \
    "$tmp" >"$session/findings.json"
  # NEW-n → F-nnn in the report, longest key first so NEW-1 does not eat NEW-12.
  jq -r '.assigned | to_entries | sort_by(-(.key | length)) | .[] | "\(.key)\t\(.value)"' "$tmp" |
    while IFS="$(printf '\t')" read -r key id; do
      [ -n "$key" ] && KEY="$key" ID="$id" perl -i -pe 's/\Q$ENV{KEY}\E(?![0-9])/$ENV{ID}/g' "$session/synthesis.md"
    done
  jq 'del(.assigned)' "$tmp" >"$ledger" && rm -f "$tmp"
  ledger_render
  log "ledger → $ledger ($(jq '.findings | length' "$ledger") findings, $(jq '[.findings[] | select(.first_seen == $sid)] | length' --arg sid "$sid" "$ledger") new)"
}

# ledger_set <id> <status> [note] — the owner's verdict on a finding.
ledger_set() {
  local id="$1" status="$2" note="${3:-}" ledger
  ledger="$(ledger_file)"
  [ -s "$ledger" ] || die "no ledger yet at $ledger — it is created by the first synthesis"
  case "$status" in open | fixed | wontfix | artifact | verified | regressed) ;; *) die "status must be one of: open fixed wontfix artifact (verified and regressed are normally set by the engine)" ;; esac
  jq -e --arg id "$id" '.findings | map(.id) | index($id) != null' "$ledger" >/dev/null || die "no finding $id in $ledger"
  # status_changed_at has the shape of a session id, so the two compare as text.
  jq --arg id "$id" --arg status "$status" --arg note "$note" --arg date "$(date +%Y-%m-%d)" --arg at "$(date +%Y%m%d-%H%M%S)" '
    .findings |= map(if .id == $id then .status = $status | .status_changed = $date | .status_changed_at = $at |
      (if $note != "" then .note = $note else . end) else . end)' "$ledger" >"$ledger.tmp" && mv "$ledger.tmp" "$ledger"
  ledger_render
  log "$id → $status"
}

# ledger_render — HISTORY_DIR/findings.md, the ledger as a table for people.
ledger_render() {
  local ledger
  ledger="$(ledger_file)"
  [ -s "$ledger" ] || return 0
  {
    if [ "$SYNTHESIS_LANG" = pl ]; then
      printf '# Rejestr znalezisk — %s\n\n' "$APP_NAME"
      printf 'Generowany z `findings.json` po każdej syntezie. Status zmienia właściciel: `run.sh <config> --finding F-012 fixed "commit"`.\n'
      printf 'Po `fixed` silnik sam ustawia `verified` (nie wróciło, choć ścieżka była sprawdzana) albo `regressed` (wróciło).\n\n'
      printf '| ID | Status | Priorytet | Rodzaj | Znalezisko | Sesje | Pierwszy raz | Ostatnio | Gdzie | Notatka |\n|---|---|---|---|---|---|---|---|---|---|\n'
    else
      printf '# Findings ledger — %s\n\n' "$APP_NAME"
      printf 'Generated from `findings.json` after every synthesis. The owner changes a status: `run.sh <config> --finding F-012 fixed "commit"`.\n'
      printf 'After `fixed` the engine sets `verified` (did not come back although the flow was exercised) or `regressed` (came back).\n\n'
      printf '| ID | Status | Priority | Kind | Finding | Sessions | First seen | Last seen | Where | Note |\n|---|---|---|---|---|---|---|---|---|---|\n'
    fi
    jq -r '
      def cell: tostring | gsub("\\|"; "\\|") | gsub("\n"; " ");
      def rank: {"regressed": 0, "open": 1, "fixed": 2, "verified": 3, "wontfix": 4, "artifact": 5}[.] // 6;
      .findings | sort_by([(.status | rank), (.priority // "P9"), .id]) | .[] |
      "| \(.id) | \(.status) | \(.priority // "—") | \(.kind) | \(.title | cell) | \([.sightings[] | select(.result == "reproduced")] | length) | \(.first_seen) | \(.last_seen) | \((.where // []) | map("`" + . + "`") | join(", ") | cell) | \(.note // "" | cell) |"' "$ledger"
  } >"$HISTORY_DIR/findings.md"
}
