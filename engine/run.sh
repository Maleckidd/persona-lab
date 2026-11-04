#!/bin/bash
# persona-lab — persona-based usability testing on an Android emulator.
#
#   bash persona-lab/engine/run.sh <config-dir> [options]
#
# One command, in this order:
#   1. preflight     device connected, claude CLI present, optional build/install
#   2. isolation     verify-isolation.sh — a persona must not be able to read the repo
#   3. personas      generated from the public brief alone (or --personas-file)
#   4. runs          for each persona × run: reset app → video → persona loop → report
#   5. synthesis     one agent WITH repo access merges everything into synthesis.md
#
# Options:
#   --count N              personas to generate (default PERSONA_COUNT)
#   --runs N               runs per persona (default RUNS_PER_PERSONA)
#   --only ID[,ID]         run only these persona ids
#   --personas-file FILE   reuse personas.json from an earlier session (no generation)
#   --max-steps N          hard cap of turns per run (default MAX_STEPS)
#   --skip-isolation       skip step 2 (not recommended)
#   --skip-synthesis       stop after the runs
#   --synthesize-only DIR  only re-run step 5 on an existing session directory
#   --archive-only DIR     only (re)write the history entry of an existing session
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

[ $# -ge 1 ] || die "usage: $0 <config-dir> [options] — see the header of this file"
load_config "$1"
shift

COUNT="$PERSONA_COUNT"
RUNS="$RUNS_PER_PERSONA"
ONLY=""
PERSONAS_FILE=""
SKIP_ISOLATION=0
SKIP_SYNTHESIS=0
SYNTH_ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --count) COUNT="$2"; shift 2 ;;
    --runs) RUNS="$2"; shift 2 ;;
    --only) ONLY="$2"; shift 2 ;;
    --personas-file) PERSONAS_FILE="$2"; shift 2 ;;
    --max-steps) MAX_STEPS="$2"; shift 2 ;;
    --skip-isolation) SKIP_ISOLATION=1; shift ;;
    --skip-synthesis) SKIP_SYNTHESIS=1; shift ;;
    --synthesize-only) SYNTH_ONLY="$2"; shift 2 ;;
    --archive-only) archive_session "$(cd "$2" && pwd)"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

resolve_claude

# --- 5. synthesis (defined first so --synthesize-only can jump to it) ----------

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
    cal="6. CALIBRATION: $CONFIG_DIR/calibration/real-testers.md holds feedback from real human testers of this app. For each real-tester point, decide whether the personas caught it (yes / partly / no — cite the matching finding). Then list persona findings the humans did not report, and give recall = caught / all human points (count 'partly' as half)."
    cal_section="
## Kalibracja względem prawdziwych testerów
Table: real-tester point | tester | caught by personas (tak/częściowo/nie) | matching finding. Then recall, then the persona-only findings, then 2–3 sentences on what the personas systematically miss or over-report."
  fi
  T_RUN_DIR="${session#"$APP_REPO"/}" T_RUN_LIST="$list" T_RUN_ID="$(basename "$session")" \
    T_LANG="$SYNTHESIS_LANG" T_CALIBRATION="$cal" T_CALIBRATION_SECTION="$cal_section" T_FOCUS="$SYNTHESIS_FOCUS" \
    render_template "$PROMPTS_DIR/synthesis.md" >"$session/synthesis-prompt.md"
  log "synthesis ($MODEL_SYNTHESIS, with repo access)…"
  repo_claude "$MODEL_SYNTHESIS" "$MAX_BUDGET_SYNTHESIS" "$session/synthesis-prompt.md" "$session/synthesis.json" >"$session/synthesis.md"
  [ -s "$session/synthesis.md" ] || die "synthesis produced nothing — see $session/synthesis.json"
  log "synthesis → $session/synthesis.md"
  archive_session "$session"
}

if [ -n "$SYNTH_ONLY" ]; then
  synthesize "$(cd "$SYNTH_ONLY" && pwd)"
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

# --- 2. isolation ---------------------------------------------------------------------

if [ $SKIP_ISOLATION = 0 ]; then
  bash "$DIR/verify-isolation.sh" "$CONFIG_DIR" --out "$SESSION/isolation" || die "isolation check failed — not running personas"
fi

# --- 3. personas -------------------------------------------------------------------------

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
    render_template "$PROMPTS_DIR/generator.md" >"$SESSION/generator-prompt.md"
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

# --- 4. runs -------------------------------------------------------------------------------

for id in $PERSONA_IDS; do
  persona="$(jq -c --arg id "$id" '.personas[] | select(.id == $id)' "$SESSION/personas.json")"
  for n in $(seq 1 "$RUNS"); do
    run_persona "$persona" "$SESSION/$id/run-$n" "$n" || true
  done
done

jq -s '{session: $sid, app: $app, version: $ver, runs: .}' --arg sid "$SESSION_ID" --arg app "$APP_NAME" --arg ver "$APP_VERSION" \
  "$SESSION"/*/run-*/summary.json >"$SESSION/summary.json"
log "total cost of runs: \$$(jq '[.runs[].cost_usd] | add' "$SESSION/summary.json")"

# --- 5. synthesis ---------------------------------------------------------------------------

if [ $SKIP_SYNTHESIS = 0 ]; then
  synthesize "$SESSION"
fi
log "done → $SESSION"
