#!/bin/bash
# persona-lab — persona-based usability testing on an Android emulator.
#
#   bash engine/run.sh <config-dir> [options]
#
# One command, in this order:
#   1. preflight     device connected, claude CLI present, optional build/install
#   2. isolation     verify-isolation.sh — a persona must not be able to read the repo
#   3. desk research only when the config has prompts/desk-research.md: one agent
#                    with web tools and no repo writes desk-research.md for the rest
#   4. personas      generated from the public brief alone (or --personas-file)
#   5. runs          for each persona × run: reset app → video → persona loop → report
#                    → the app's end state is read and checked against the needs
#   6. synthesis     one agent merges everything into synthesis.md; it reads the
#                    repo, or only SYNTHESIS_SCOPE when the config sets one. Its
#                    findings go into the ledger (history/findings.json).
#   7. calibration   only with --seeded: recall on defects planted in this build
#
# Options:
#   --count N              personas to generate (default PERSONA_COUNT)
#   --runs N               runs per persona (default RUNS_PER_PERSONA)
#   --only ID[,ID]         run only these persona ids
#   --personas-file FILE   reuse personas.json from an earlier session (no generation)
#   --dossier-file FILE    reuse desk-research.md from an earlier session (no web research)
#   --max-steps N          hard cap of turns per run (default MAX_STEPS)
#   --skip-isolation       skip step 2 (not recommended)
#   --skip-synthesis       stop after the runs
#   --synthesize-only DIR  only re-run step 6 on an existing session directory
#   --archive-only DIR     only (re)write the history entry of an existing session
#   --seeded FILE          this build has planted defects, listed in FILE: score how
#                          many the personas caught, and keep the session out of
#                          the ledger (see lib/calibration.sh)
#   --score-only DIR       only re-run step 7 on an existing session (with --seeded)
#
# Without a session:
#   --finding ID STATUS [NOTE]   set a ledger finding to open | fixed | wontfix | artifact
#   --compare DIR-A DIR-B        two sessions side by side (before/after a fix, or two
#                                store listings); prints Markdown
#
# Output: <runs-dir>/<session-id>/ — see README.md.
set -uo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$DIR/lib/common.sh"
# shellcheck source=lib/device.sh
source "$DIR/lib/device.sh"
# shellcheck source=lib/report.sh
source "$DIR/lib/report.sh"
# shellcheck source=lib/persona-loop.sh
source "$DIR/lib/persona-loop.sh"
# shellcheck source=lib/history.sh
source "$DIR/lib/history.sh"
# shellcheck source=lib/verify.sh
source "$DIR/lib/verify.sh"
# shellcheck source=lib/ledger.sh
source "$DIR/lib/ledger.sh"
# shellcheck source=lib/calibration.sh
source "$DIR/lib/calibration.sh"
# shellcheck source=lib/compare.sh
source "$DIR/lib/compare.sh"

[ $# -ge 1 ] || die "usage: $0 <config-dir> [options] — see the header of this file"
load_config "$1"
shift

COUNT="$PERSONA_COUNT"
RUNS="$RUNS_PER_PERSONA"
ONLY=""
PERSONAS_FILE=""
DOSSIER_REUSE=""
SKIP_ISOLATION=0
SKIP_SYNTHESIS=0
SYNTH_ONLY=""
SCORE_ONLY=""
SEEDED=""
while [ $# -gt 0 ]; do
  case "$1" in
    --count) COUNT="$2"; shift 2 ;;
    --runs) RUNS="$2"; shift 2 ;;
    --only) ONLY="$2"; shift 2 ;;
    --personas-file) PERSONAS_FILE="$2"; shift 2 ;;
    --dossier-file) DOSSIER_REUSE="$2"; shift 2 ;;
    --max-steps) MAX_STEPS="$2"; shift 2 ;;
    --skip-isolation) SKIP_ISOLATION=1; shift ;;
    --skip-synthesis) SKIP_SYNTHESIS=1; shift ;;
    --synthesize-only) SYNTH_ONLY="$2"; shift 2 ;;
    --archive-only) archive_session "$(cd "$2" && pwd)"; exit 0 ;;
    --seeded)
      [ -f "$2" ] || die "no such manifest: $2"
      SEEDED="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
      grep -q 'PERSONA-LAB-TEMPLATE' "$SEEDED" && die "$SEEDED is still the template"
      shift 2
      ;;
    --score-only) SCORE_ONLY="$2"; shift 2 ;;
    --finding)
      [ $# -ge 3 ] || die "usage: --finding <id> <open|fixed|wontfix|artifact> [note]"
      ledger_set "$2" "$3" "${4:-}"
      exit 0
      ;;
    --compare)
      [ $# -ge 3 ] || die "usage: --compare <session-dir-A> <session-dir-B>"
      compare_sessions "$(cd "$2" && pwd)" "$(cd "$3" && pwd)"
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

resolve_claude

# --- 6. synthesis (defined first so --synthesize-only can jump to it) ----------

calibration_filled() {
  local f="$CONFIG_DIR/calibration/real-testers.md"
  [ -f "$f" ] && grep -E '^[[:space:]]*- ' "$f" | grep -vq 'PERSONA-LAB-TEMPLATE'
}

synthesize() {
  local session="$1" list="" d
  for d in "$session"/*/run-*/; do
    [ -f "$d/report.md" ] && list="$list ${d#"$APP_REPO"/}report.md"
  done
  [ -n "$list" ] || die "no reports under $session"
  local cal="" cal_section=""
  if calibration_filled; then
    cal="CALIBRATION: $CONFIG_DIR/calibration/real-testers.md holds feedback from real human testers of this app. For each real-tester point, decide whether the personas caught it (yes / partly / no — cite the matching finding). Then list persona findings the humans did not report, and give recall = caught / all human points (count 'partly' as half)."
    cal_section="
## Kalibracja względem prawdziwych testerów
Table: real-tester point | tester | caught by personas (tak/częściowo/nie) | matching finding. Then recall, then the persona-only findings, then 2–3 sentences on what the personas systematically miss or over-report."
  fi
  T_RUN_DIR="${session#"$APP_REPO"/}" T_RUN_LIST="$list" T_RUN_ID="$(basename "$session")" \
    T_LANG="$SYNTHESIS_LANG" T_CALIBRATION="$cal" T_CALIBRATION_SECTION="$cal_section" T_FOCUS="$SYNTHESIS_FOCUS" \
    T_LEDGER="$(ledger_for_prompt)" T_BRIEF_PATH="${BRIEF_FILE#"$APP_REPO"/}" \
    render_template "$(prompt_file synthesis.md)" >"$session/synthesis-prompt.md"
  if [ -n "${SYNTHESIS_SCOPE:-}" ]; then
    local scope escapes leaks
    scope="$(scope_snapshot "$session")" || die "cannot build the synthesis snapshot"
    log "synthesis ($MODEL_SYNTHESIS, only: $SYNTHESIS_SCOPE)…"
    scoped_claude "$MODEL_SYNTHESIS" "$MAX_BUDGET_SYNTHESIS" "$session/synthesis-prompt.md" "$session/synthesis.jsonl" "$scope" >"$session/synthesis.md"
    jq -c 'select(.type == "result")' "$session/synthesis.jsonl" | tail -1 >"$session/synthesis.json"
    escapes="$(scope_escapes "$session/synthesis.jsonl" "$scope")"
    leaks="$(scope_leaks "$session/synthesis.jsonl")"
    rm -rf "$scope"
    {
      printf 'Scope: %s\n' "$SYNTHESIS_SCOPE"
      printf 'Reads attempted outside the snapshot: %s\n' "${escapes:-none}"
      printf 'Forbidden files seen in the transcript: %s\n' "${leaks:-none}"
    } >"$session/scope-audit.txt"
    [ -z "$leaks" ] || die "the synthesis saw $leaks — see $session/scope-audit.txt"
    [ -z "$escapes" ] || log "WARNING: the synthesis tried to leave its snapshot — see $session/scope-audit.txt"
  else
    log "synthesis ($MODEL_SYNTHESIS, with repo access)…"
    repo_claude "$MODEL_SYNTHESIS" "$MAX_BUDGET_SYNTHESIS" "$session/synthesis-prompt.md" "$session/synthesis.json" >"$session/synthesis.md"
  fi
  [ -s "$session/synthesis.md" ] || die "synthesis produced nothing — see $session/synthesis.json"
  log "synthesis → $session/synthesis.md"

  # The ledger. A session on a seeded build stays out of it: its findings
  # include defects that were planted, and those must not become history.
  local found
  found="$(extract_findings "$session/synthesis.md")"
  if is_seeded_session "$session"; then
    log "seeded build — the findings ledger is not updated"
  elif [ -n "$found" ]; then
    ledger_merge "$session" "$found"
  elif grep -q 'persona-lab-findings' "$(prompt_file synthesis.md)"; then
    log "WARNING: the synthesis ended without a readable findings block — the ledger is not updated"
  fi

  if [ -n "$SEEDED" ]; then
    score_seeded "$session" "$SEEDED" || true
  fi
  archive_session "$session"
}

# Seeded sessions are remembered next to the runs, not inside the session:
# the synthesis reads the session directory and must not learn that this
# build was tampered with.
is_seeded_session() { grep -qx "$(basename "$1")" "$RUNS_DIR/.seeded-sessions" 2>/dev/null; }
mark_seeded_session() { is_seeded_session "$1" || basename "$1" >>"$RUNS_DIR/.seeded-sessions"; }

if [ -n "$SCORE_ONLY" ]; then
  [ -n "$SEEDED" ] || die "--score-only needs --seeded <manifest.json>"
  SCORE_ONLY="$(cd "$SCORE_ONLY" && pwd)"
  mark_seeded_session "$SCORE_ONLY"
  score_seeded "$SCORE_ONLY" "$SEEDED" || die "scoring failed"
  archive_session "$SCORE_ONLY"
  exit 0
fi

if [ -n "$SYNTH_ONLY" ]; then
  SYNTH_ONLY="$(cd "$SYNTH_ONLY" && pwd)"
  [ -z "$SEEDED" ] || mark_seeded_session "$SYNTH_ONLY"
  synthesize "$SYNTH_ONLY"
  exit 0
fi

# --- 1. preflight -----------------------------------------------------------------

device_check
log "device $ANDROID_SERIAL ${DEV_W}x${DEV_H}, screenshots ${SHOT_WIDTH}x${SHOT_HEIGHT}"
command -v ffmpeg >/dev/null || log "WARNING: ffmpeg missing — no compact video"
if [ -n "${BUILD_CMD:-}" ]; then
  log "build: $BUILD_CMD"
  (cd "$APP_REPO" && eval "$BUILD_CMD") || die "build failed"
fi
if [ -n "${APK:-}" ]; then
  log "install: $APK"
  adbs install -r "$APK" >/dev/null || die "install failed (signature mismatch? uninstall $APP_ID first)"
fi
adbs shell pm path "$APP_ID" >/dev/null 2>&1 || die "$APP_ID is not installed on $ANDROID_SERIAL"
APP_VERSION="$(adbs shell dumpsys package "$APP_ID" | sed -n 's/.*versionName=//p' | head -1 | tr -d '\r')"

SESSION_ID="$(date +%Y%m%d-%H%M%S)"
SESSION="$RUNS_DIR/$SESSION_ID"
mkdir -p "$SESSION"
log "session $SESSION_ID — $APP_NAME $APP_VERSION"
[ -z "$SEEDED" ] || mark_seeded_session "$SESSION"
if declare -F capture_state >/dev/null && [ "$JUDGE_OUTCOME" = 1 ]; then
  log "outcome check: on (capture_state hook, judge $MODEL_JUDGE, plus each persona's \"expect\" patterns)"
elif declare -F capture_state >/dev/null; then
  log "outcome check: only for personas with \"expect\" patterns (JUDGE_OUTCOME=0)"
else
  log "outcome check: off — the config has no capture_state hook, so \"done\" is only what the persona believes"
fi
# Keep the host awake for as long as this script runs. It does not stop the
# sleep of a closed laptop lid; a stall is detected and marked either way.
if command -v caffeinate >/dev/null 2>&1; then
  caffeinate -i -w $$ &
fi

# --- 2. isolation ---------------------------------------------------------------------

if [ $SKIP_ISOLATION = 0 ]; then
  bash "$DIR/verify-isolation.sh" "$CONFIG_DIR" --out "$SESSION/isolation" || die "isolation check failed — not running personas"
fi

# --- 3. desk research ---------------------------------------------------------------------

DOSSIER_FILE=""
if [ -n "$DOSSIER_REUSE" ]; then
  DOSSIER_FILE="$SESSION/desk-research.md"
  cp "$DOSSIER_REUSE" "$DOSSIER_FILE" || die "cannot read $DOSSIER_REUSE"
elif [ -f "$CONFIG_DIR/prompts/desk-research.md" ]; then
  DOSSIER_FILE="$SESSION/desk-research.md"
  T_BRIEF="$(cat "$BRIEF_FILE")" T_DATE="$(date +%Y-%m-%d)" \
    render_template "$CONFIG_DIR/prompts/desk-research.md" >"$SESSION/desk-research-prompt.md"
  log "desk research ($MODEL_SYNTHESIS, web tools, no repo)…"
  web_claude "$MODEL_SYNTHESIS" "$MAX_BUDGET_DESK_RESEARCH" "$SESSION/desk-research-prompt.md" "$SESSION/desk-research.json" >"$DOSSIER_FILE"
  [ -s "$DOSSIER_FILE" ] || die "desk research produced nothing — see $SESSION/desk-research.json"
  log "desk research → $DOSSIER_FILE"
fi

# --- 4. personas -------------------------------------------------------------------------

if [ -n "$PERSONAS_FILE" ]; then
  cp "$PERSONAS_FILE" "$SESSION/personas.json"
else
  states=""
  for s in $STATES; do states="$states
  - \"$s\": $(state_desc "$s")"; done
  overrides=""
  if [ -s "$CONFIG_DIR/personas.override.md" ]; then
    overrides="The study owner suggests these personas. Treat them as hints, not a fixed list: keep the ones that fit, adjust them, replace weak ones.

<owner-suggestions>
$(cat "$CONFIG_DIR/personas.override.md")
</owner-suggestions>"
  fi
  T_BRIEF="$(cat "$BRIEF_FILE")" T_COUNT="$COUNT" T_MAX_STEPS="$MAX_STEPS" \
    T_LANGUAGES="$(echo "$APP_LANGUAGES" | sed 's/ /, /g')" T_STATES="$states" T_OVERRIDES="$overrides" \
    render_template "$(prompt_file generator.md)" >"$SESSION/generator-prompt.md"
  printf 'You are a UX researcher. Follow the instructions in the user message exactly.\n' >"$SESSION/generator-system.md"
  log "generating $COUNT personas from the brief ($MODEL_GENERATOR, no tools)…"
  for attempt in 1 2; do
    user_message "$(cat "$SESSION/generator-prompt.md")" |
      isolated_claude "$MODEL_GENERATOR" "$SESSION/generator-system.md" "$SESSION/generator.jsonl" |
      extract_json >"$SESSION/personas.raw.json"
    jq -e '.personas | length > 0' "$SESSION/personas.raw.json" >/dev/null 2>&1 && break
    [ $attempt = 2 ] && die "persona generation failed — see $SESSION/generator.jsonl"
  done
  # Clamp what the generator may get wrong: unknown states/languages fall back
  # to the first configured one, patience never exceeds the hard cap.
  jq --arg states "$STATES" --arg langs "$APP_LANGUAGES" --argjson max "$MAX_STEPS" '
    ($states | split(" ")) as $S | ($langs | split(" ")) as $L |
    .personas |= map(
      .start_state = (if (.start_state | IN($S[])) then .start_state else $S[0] end) |
      .language = (if (.language | IN($L[])) then .language else $L[0] end) |
      .patience.max_steps = ([(.patience.max_steps // $max), $max] | min) |
      .device.font_scale = ([[(.device.font_scale // 1.0), 0.85] | max, 1.3] | min))
  ' "$SESSION/personas.raw.json" >"$SESSION/personas.json"
fi

PERSONA_IDS="$(jq -r '.personas[].id' "$SESSION/personas.json")"
if [ -n "$ONLY" ]; then
  PERSONA_IDS="$(printf '%s\n' "$PERSONA_IDS" | grep -Fx -f <(tr ',' '\n' <<<"$ONLY") || true)"
  [ -n "$PERSONA_IDS" ] || die "--only $ONLY matched no persona (have: $(jq -r '[.personas[].id] | join(", ")' "$SESSION/personas.json"))"
fi
log "personas: $(echo $PERSONA_IDS) × $RUNS run(s)"

# --- 5. runs -------------------------------------------------------------------------------

for id in $PERSONA_IDS; do
  persona="$(jq -c --arg id "$id" '.personas[] | select(.id == $id)' "$SESSION/personas.json")"
  for n in $(seq 1 "$RUNS"); do
    run_persona "$persona" "$SESSION/$id/run-$n" "$n" || true
  done
done

jq -s '{session: $sid, app: $app, version: $ver, runs: .}' --arg sid "$SESSION_ID" --arg app "$APP_NAME" --arg ver "$APP_VERSION" \
  "$SESSION"/*/run-*/summary.json >"$SESSION/summary.json"
log "total cost of runs: \$$(jq '[.runs[].cost_usd] | add' "$SESSION/summary.json")"
log "outcomes: $(jq -r '.runs | map(select(.outcome != "skipped")) |
  "\(length) runs — declared done: \(map(select(.outcome == "done")) | length), " +
  "confirmed by the end state: \(map(select(.verified == "met")) | length), " +
  "overclaimed: \(map(select(.self_report == "overclaimed")) | length), " +
  "tainted by the rig: \(map(select(.tainted == true)) | length)"' "$SESSION/summary.json")"

# --- 6. synthesis ---------------------------------------------------------------------------

if [ $SKIP_SYNTHESIS = 0 ]; then
  synthesize "$SESSION"
fi
log "done → $SESSION"
