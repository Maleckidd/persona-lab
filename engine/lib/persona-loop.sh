# shellcheck shell=bash
#
# One persona run: screenshot → model decides → engine acts → repeat, until the
# persona is done, gives up, or hits the hard step cap. Then the persona writes
# its report and the engine checks its evidence.
#
# The persona never touches the device or the file system: each turn is a
# stateless isolated_claude call that gets the current screenshot plus the
# persona's own notes so far, and answers with one JSON action. The engine
# validates and performs it.
#
# Source after common.sh, device.sh and report.sh.

# run_persona <persona-json> <out-dir> <run-number>
run_persona() {
  local persona="$1" out="$2" run_no="$3"
  local id name lang state font dark max_steps
  id="$(jq -r .id <<<"$persona")"
  name="$(jq -r .name <<<"$persona")"
  lang="$(jq -r .language <<<"$persona")"
  state="$(jq -r .start_state <<<"$persona")"
  font="$(jq -r '.device.font_scale // 1.0' <<<"$persona")"
  dark="$(jq -r '.device.dark_mode // false' <<<"$persona")"
  # The persona's own patience budget is the hard cap (never above MAX_STEPS):
  # left to the model, a persona with patience 18 kept going to step 29.
  max_steps="$(jq -r --argjson cap "$MAX_STEPS" '[(.patience.max_steps // $cap), $cap] | min' <<<"$persona")"

  mkdir -p "$out/shots" "$out/steps"
  printf '%s\n' "$persona" | jq . >"$out/persona.json"
  log "▶ $id (run $run_no): $name — state=$state lang=$lang font=$font dark=$dark"

  # --- environment ---
  # Reset first, at the device's default font and theme: a config's reset hook
  # may drive the UI by coordinates, which a larger font_scale moves (and it
  # may force a theme of its own). The persona's profile goes on afterwards,
  # with a cold restart so the app comes up in it.
  # A failed reset loses this run, not the session: the rest still runs and
  # the skipped one is visible in summary.json.
  trap 'video_stop; device_profile_restore' INT TERM
  # An optional state_ready hook runs last, on the final app process: anything
  # a cold restart would wipe (a share intent) or that goes stale (the clipboard).
  if ! (reset_app "$state" "$lang") || ! app_wait_ready 90 ||
    ! device_profile_apply "$font" "$dark" || ! app_stop || ! app_start || ! app_wait_ready 90 ||
    { declare -F state_ready >/dev/null && ! (state_ready "$state" "$lang"); }; then
    log "WARNING: could not put the app into state '$state' ($lang) — skipping $id run $run_no"
    trap - INT TERM
    device_profile_restore
    jq -n --arg id "$id" --arg name "$name" --argjson run "$run_no" --arg state "$state" --arg lang "$lang" \
      '{id: $id, name: $name, run: $run, start_state: $state, language: $lang, steps: 0,
        outcome: "skipped", outcome_reason: "reset failed", cost_usd: 0, seconds: 0, rejected_findings: 0}' >"$out/summary.json"
    return 1
  fi

  # --- system prompt: the persona, the brief, the situation; constant per run ---
  local sys="$out/steps/system-prompt.md"
  T_PERSONA="$(jq -r 'del(.id, .start_state, .device) | to_entries | map("- **\(.key)**: \(.value | if type == "string" then . else tojson end)") | join("\n")' <<<"$persona")" \
    T_BRIEF="$(cat "$(brief_for "$lang")")" \
    T_STATE="$(state_persona_text "$state")" \
    T_LANG="$lang" T_MAX_STEPS="$max_steps" T_SHOT_W="$SHOT_WIDTH" T_SHOT_H="$SHOT_HEIGHT" \
    render_template "$PROMPTS_DIR/persona.md" >"$sys"

  video_start "$out/video.webm"
  local started_at step=0 history="" feedback="" outcome="limit" outcome_reason="" cost=0 bad=0
  started_at="$(date +%s)"
  : >"$out/actions.log"

  while [ "$step" -lt "$max_steps" ]; do
    step=$((step + 1))
    local sid shot hints prompt reply json action did rc c
    sid="$(printf 'shot-%03d' "$step")"
    shot="$out/shots/$sid.png"
    sleep "$SETTLE_SECONDS"
    shot_take "$shot"
    hints="$(ui_hints)"

    prompt="TURN $step of at most $max_steps."
    if [ -n "$history" ]; then
      prompt="$prompt

Your notes from the previous turns:
$history"
    fi
    [ -n "$feedback" ] && prompt="$prompt

$feedback"
    prompt="$prompt

Below is your phone screen now ($sid, ${SHOT_WIDTH}x${SHOT_HEIGHT} px)."
    if [ -n "$hints" ]; then
      prompt="$prompt
Texts visible on the screen with their positions [x1,y1 - x2,y2] (aiming aid only):
$hints"
    fi
    prompt="$prompt

Reply with one JSON object only."

    user_message "$prompt" "$shot" |
      isolated_claude "$MODEL_PERSONA" "$sys" "$out/steps/$sid.jsonl" >"$out/steps/$sid.reply.txt"
    c="$(result_cost "$out/steps/$sid.jsonl")"
    cost="$(add_cost "$cost" "$c")"
    reply="$(cat "$out/steps/$sid.reply.txt")"
    json="$(printf '%s' "$reply" | extract_json)"

    if [ -z "$json" ] || [ -z "$(jq -r '.action.type // empty' <<<"$json")" ]; then
      bad=$((bad + 1))
      printf '%s\t%s\tINVALID\t%s\n' "$sid" "$(date +%H:%M:%S)" "$(printf '%s' "$reply" | tr '\n' ' ' | head -c 300)" >>"$out/actions.log"
      if grep -q 'Not logged in\|Invalid API key\|authentication' "$out/steps/$sid.jsonl" "$out/steps/$sid.jsonl.stderr" 2>/dev/null; then
        video_stop
        device_profile_restore
        die "claude is not authenticated — see README (ANTHROPIC_API_KEY or claude setup-token)"
      fi
      [ "$bad" -ge 3 ] && { outcome="error"; outcome_reason="3 invalid replies in a row"; break; }
      feedback="Your previous reply was not a valid JSON object with an \"action\". Reply with JSON only."
      continue
    fi
    bad=0
    printf '%s\n' "$json" >"$out/steps/$sid.json"
    action="$(jq -c .action <<<"$json")"

    did="$(perform_action "$action")"
    rc=$?
    printf '%s\t%s\t%s\t%s\n' "$sid" "$(date +%H:%M:%S)" "$action" "$did" >>"$out/actions.log"
    jq -c --arg did "$did" --arg rc "$rc" '. + {performed: $did, performed_ok: ($rc != "1")}' \
      "$out/steps/$sid.json" >"$out/steps/$sid.json.tmp" && mv "$out/steps/$sid.json.tmp" "$out/steps/$sid.json"

    history="$history
[$sid] saw: $(jq -r .see <<<"$json") | expected: $(jq -r .expect <<<"$json") | did: $(jq -r .do <<<"$json") → $did$(
      s="$(jq -r '.surprise // ""' <<<"$json")"
      [ -n "$s" ] && printf ' | surprise: %s' "$s"
    )"

    if [ $rc = 2 ]; then
      outcome="$(jq -r .type <<<"$action")"
      outcome_reason="$(jq -r '.reason // ""' <<<"$action")"
      break
    elif [ $rc = 1 ]; then
      feedback="Your previous action could not be performed: $did."
    else
      feedback="Your previous action was performed: $did."
    fi
  done

  sleep 1
  video_stop
  trap - INT TERM
  device_profile_restore
  video_compact "$out/video.webm" "$out/video.mp4"

  # --- the persona's report ---
  local outcome_text title rep
  case "$outcome" in
    done) outcome_text="you finished: $outcome_reason" ;;
    give_up) outcome_text="you gave up: $outcome_reason" ;;
    limit) outcome_text="you used up your patience: $max_steps turns, and you stopped there" ;;
    *) outcome_text="the session was interrupted by a technical error" ;;
  esac
  title="Raport: $name — przebieg $run_no"
  T_OUTCOME="$outcome_text" T_HISTORY="$history" T_LANG="$lang" T_TITLE="$title" \
    render_template "$PROMPTS_DIR/report.md" >"$out/steps/report-prompt.md"
  user_message "$(cat "$out/steps/report-prompt.md")" |
    isolated_claude "$MODEL_PERSONA" "$sys" "$out/steps/report.jsonl" >"$out/report.raw.md"
  cost="$(add_cost "$cost" "$(result_cost "$out/steps/report.jsonl")")"

  check_citations "$out/report.raw.md" "$out/shots" "$step" >"$out/report.md"
  render_think_aloud "$out" "$title" >"$out/think-aloud.md"

  jq -n --arg id "$id" --arg name "$name" --argjson run "$run_no" --arg state "$state" --arg lang "$lang" \
    --argjson steps "$step" --arg outcome "$outcome" --arg reason "$outcome_reason" \
    --argjson cost "$cost" --argjson secs "$(($(date +%s) - started_at))" \
    --argjson rejected "$(grep -c '^- ' <(sed -n '/^## Odrzucone/,$p' "$out/report.md") || true)" \
    '{id: $id, name: $name, run: $run, start_state: $state, language: $lang, steps: $steps,
      outcome: $outcome, outcome_reason: $reason, cost_usd: $cost, seconds: $secs,
      rejected_findings: $rejected}' >"$out/summary.json"
  log "■ $id (run $run_no): $outcome after $step steps, \$$cost"
}
