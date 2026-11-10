# shellcheck shell=bash
#
# Two sessions side by side: the same personas on two builds (before and after
# a fix), or on two variants of the store listing (two config directories with
# different briefs). No model call: everything here is counted from the
# sessions' own files.
#
# Read it as "what changed", not as a measurement. The personas are a small
# hand-picked set and their runs vary on purpose, so one run flipping from
# give_up to done proves nothing by itself; a finding that every persona hit
# before and nobody hits now does.
#
# Source after common.sh, load_config and verify.sh.

# session_runs <session-dir> — the session's runs as a JSON array, with the
# fields of newer sessions filled in for older ones (taint is recomputed from
# the logs, so a session recorded before the check existed is covered too).
session_runs() {
  local session="$1" d s
  for d in "$session"/*/run-*/; do
    [ -f "$d/summary.json" ] || continue
    s="$(run_taint "$d")"
    jq -c --argjson taint "${s:-[]}" '. + {verified: (.verified // "none"), self_report: (.self_report // "unknown"),
      taint: (.taint // $taint)} | .tainted = ((.taint | length) > 0 or .outcome == "error")' "$d/summary.json"
  done | jq -s .
}

# compare_sessions <session-A> <session-B> — prints the comparison as Markdown.
compare_sessions() {
  local a="$1" b="$2" ra rb fa="[]" fb="[]" ledger="{}" pl=0
  [ -d "$a" ] && [ -d "$b" ] || die "--compare needs two session directories"
  ra="$(session_runs "$a")"
  rb="$(session_runs "$b")"
  [ -s "$a/findings.json" ] && fa="$(cat "$a/findings.json")"
  [ -s "$b/findings.json" ] && fb="$(cat "$b/findings.json")"
  [ -s "$(ledger_file)" ] && ledger="$(cat "$(ledger_file)")"
  [ "$SYNTHESIS_LANG" = pl ] && pl=1
  jq -rn --argjson A "$ra" --argjson B "$rb" --argjson FA "$fa" --argjson FB "$fb" --argjson L "$ledger" \
    --arg a "$(basename "$a")" --arg b "$(basename "$b")" --argjson pl "$pl" \
    --arg va "$(jq -r '.version // "?"' "$a/summary.json" 2>/dev/null)" --arg vb "$(jq -r '.version // "?"' "$b/summary.json" 2>/dev/null)" '
    def t($pl_text; $en_text): if $pl == 1 then $pl_text else $en_text end;
    def real: map(select(.outcome != "skipped"));
    def n(f): map(select(f)) | length;
    def mean_steps: real | if length == 0 then "—" else (map(.steps) | add / length * 10 | round / 10 | tostring) end;
    def checked: real | n(.verified != "none");
    def row($label; f): "| \($label) | \($A | f) | \($B | f) |";
    def cell($runs; $id): [$runs[] | select(.id == $id)] | sort_by(.run) |
      if length == 0 then "—" else map("\(.outcome)" +
        (if .verified != "none" then "/" + .verified else "" end) + " (\(.steps))" + (if .tainted then " ⚠" else "" end)) | join(", ") end;
    def title($id): ([$L.findings[]? | select(.id == $id)] | first | .title) // ([$FA[], $FB[] | select(.id == $id) | .title // empty] | first) // "";
    def seen($F): [$F[] | select((.status // "reproduced") == "reproduced") | .id];
    (seen($FA)) as $sa | (seen($FB)) as $sb |
    "# " + t("Porównanie sesji"; "Session comparison") + " — \($a) → \($b)\n",
    "| | A: `\($a)` (\($va)) | B: `\($b)` (\($vb)) |", "|---|---|---|",
    row(t("Przebiegi"; "Runs"); real | length),
    row(t("Persona mówi: cel osiągnięty"; "Persona says: done"); real | n(.outcome == "done")),
    row(t("Stan końcowy potwierdza (met)"; "End state confirms (met)"); if checked == 0 then "—" else "\(real | n(.verified == "met"))/\(checked)" end),
    row(t("Persona się myli (overclaimed)"; "Persona is wrong (overclaimed)"); if checked == 0 then "—" else (real | n(.self_report == "overclaimed")) end),
    row(t("Rezygnacja"; "Gave up"); real | n(.outcome == "give_up")),
    row(t("Limit kroków"; "Step limit"); real | n(.outcome == "limit")),
    row(t("Średnio kroków"; "Mean steps"); mean_steps),
    row(t("Przebiegi skażone (stanowisko)"; "Tainted runs (rig)"); real | n(.tainted)),
    "",
    "## " + t("Persony"; "Personas") + "\n",
    t("Każdy przebieg: wynik persony / werdykt ze stanu końcowego (kroki); ⚠ = incydent stanowiska."; "Each run: persona outcome / end-state verdict (steps); ⚠ = rig incident.") + "\n",
    "| Persona | A | B |", "|---|---|---|",
    (([$A[].id, $B[].id] | unique)[] as $id | "| `\($id)` | \(cell($A; $id)) | \(cell($B; $id)) |"),
    "",
    "## " + t("Znaleziska"; "Findings") + "\n",
    (if ($FA | length) == 0 or ($FB | length) == 0 then
       t("Brak `findings.json` w jednej z sesji (sesja sprzed rejestru znalezisk albo bez syntezy) — porównanie znalezisk pominięte."; "One of the sessions has no `findings.json` (recorded before the ledger, or not synthesized) — findings are not compared.")
     else
       "**" + t("Były w A, nie ma w B"; "In A, gone in B") + "** (\($sa - $sb | length))\n",
       (($sa - $sb)[] as $id | "- \($id) \(title($id)) — B: `\(([$FB[] | select(.id == $id) | .status] | first) // t("brak wpisu"; "no entry"))`"),
       "\n**" + t("Nowe w B"; "New in B") + "** (\($sb - $sa | length))\n",
       (($sb - $sa)[] | "- \(.) \(title(.))"),
       "\n**" + t("W obu"; "In both") + "** (\($sa - ($sa - $sb) | length))\n",
       (($sa - ($sa - $sb))[] | "- \(.) \(title(.))"),
       "\n" + t("„Nie ma w B” znaczy tylko, że B tego nie zgłosiła. Czy ścieżka w ogóle była sprawdzana, mówi wpis znaleziska w sesji B (`not_reproduced` kontra `not_exercised`) i rejestr."; "\"Gone in B\" only means B did not report it. Whether the flow was exercised at all is in session B'"'"'s own entry for the finding (`not_reproduced` versus `not_exercised`) and in the ledger.")
     end)'
}
