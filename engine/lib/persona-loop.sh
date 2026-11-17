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
# Whatever matters is enforced here, not asked for in the prompt: the patience
# cap, the gestures a persona does not use, and the outcome — which the engine
# checks against the app's real end state instead of taking the persona's word.
#
# Source after common.sh, device.sh, report.sh and verify.sh.

# persona_actions <persona-json> — the action list shown to the persona, minus
# the gestures in its "avoids" (long_press, swipe). A person who never
# long-presses does not find what hides behind a long press; a model playing
# them knows every platform convention and would, unless the engine says no.
persona_actions() {
  local avoid
  avoid=" $(jq -r '.avoids // [] | join(" ")' <<<"$1") "
  printf '%s\n' '- {"type": "tap", "x": 120, "y": 560}'
  case "$avoid" in *" long_press "*) ;; *) printf '%s\n' '- {"type": "long_press", "x": 120, "y": 560}' ;; esac
  case "$avoid" in *" swipe "*) ;; *) printf '%s\n' '- {"type": "swipe", "x1": 270, "y1": 900, "x2": 270, "y2": 300}' ;; esac
  printf '%s\n' \
    '- {"type": "scroll", "direction": "down"}   (or "up")' \
    '- {"type": "type", "text": "text to type into the field that has focus"}' \
    '- {"type": "back"}     (the phone'"'"'s system Back)' \
    '- {"type": "enter"}    (Enter on the keyboard)' \
    '- {"type": "wait"}     (wait for the screen to change)' \
    '- {"type": "done", "reason": "..."}     (you have dealt with all your needs, successfully or not, and stop using the app)' \
    '- {"type": "give_up", "reason": "..."}  (you have had enough and close the app)'
}

# persona_avoids <persona-json> <action-type> — true when the persona's profile
# rules this gesture out. Only long_press and swipe can be ruled out.
persona_avoids() {
  case "$2" in long_press | swipe) ;; *) return 1 ;; esac
  jq -e --arg t "$2" '(.avoids // []) | index($t) != null' <<<"$1" >/dev/null
}

# wants_end_state <persona-json> — the config can read the app's end state and
# something will use it: the judge, or the persona's own "expect" patterns.
wants_end_state() {
  declare -F capture_state >/dev/null || return 1
  [ "$JUDGE_OUTCOME" = 1 ] || jq -e '(.expect // []) | length > 0' <<<"$1" >/dev/null
}

# read_before <persona-json> <state> <lang> <run-dir> — the app's state before
# the persona touches it, for the judge. A failed read is tolerated (the judge
# is told nothing was captured); a failed cold restart after it is not.
read_before() {
  wants_end_state "$1" || return 0
  (capture_state before "$2" "$3") >"$4/state-before.md" 2>"$4/steps/capture-before.log"
  app_restart
}

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

  local t_run_start
  t_run_start="$(date +%s)"
  mkdir -p "$out/shots" "$out/steps"
  printf '%s\n' "$persona" | jq . >"$out/persona.json"
  log "▶ $id (run $run_no): $name — state=$state lang=$lang font=$font dark=$dark"

  # --- environment ---
  # Reset first, at the device's own font and theme: a config's reset hook may
  # drive the UI by coordinates, which a larger font_scale moves (and it may
  # force a theme of its own). The persona's profile goes on afterwards, with a
  # cold restart so the app comes up in it.
  # With a capture_state hook the app is read next, already under the persona's
  # profile, because the read after the run happens under it too: a read
  # depends on the layout (ui_collect drops a line it saw on an earlier
  # screen), so two reads at different font scales differ by lines nobody
  # wrote. The read leaves the app wherever it navigated, so another cold
  # restart follows.
  # An optional state_ready hook runs last, on the final app process: anything
  # a cold restart would wipe (a share intent) or that goes stale (the clipboard).
  # A failed reset loses this run, not the session: the rest still runs and
  # the skipped one is visible in summary.json.
  # The device's own profile comes back after the run, or from run.sh's EXIT
  # trap if the session ends inside it.
  if ! (reset_app "$state" "$lang") || ! app_wait_ready 90 ||
    ! device_profile_apply "$font" "$dark" || ! app_restart ||
    ! read_before "$persona" "$state" "$lang" "$out" ||
    { declare -F state_ready >/dev/null && ! (state_ready "$state" "$lang"); }; then
    log "WARNING: could not put the app into state '$state' ($lang) — skipping $id run $run_no"
    device_profile_restore
    jq -n --arg id "$id" --arg name "$name" --argjson run "$run_no" --arg state "$state" --arg lang "$lang" \
      '{id: $id, name: $name, run: $run, start_state: $state, language: $lang, steps: 0,
        outcome: "skipped", outcome_reason: "reset failed", cost_usd: 0, seconds: 0, rejected_findings: 0,
        verified: "none", self_report: "unknown", tainted: false, taint: []}' >"$out/summary.json"
    return 1
  fi

  # --- system prompt: the persona, the brief, the situation; constant per run ---
  local sys="$out/steps/system-prompt.md"
  T_PERSONA="$(jq -r 'del(.id, .start_state, .device, .expect, .avoids) | to_entries | map("- **\(.key)**: \(.value | if type == "string" then . else tojson end)") | join("\n")' <<<"$persona")" \
    T_BRIEF="$(cat "$(brief_for "$lang")")" \
    T_STATE="$(state_persona_text "$state")" \
    T_DOSSIER="$(cat "${DOSSIER_FILE:-/dev/null}" 2>/dev/null)" \
    T_ACTIONS="$(persona_actions "$persona")" \
    T_LANG="$lang" T_MAX_STEPS="$max_steps" T_SHOT_W="$SHOT_WIDTH" T_SHOT_H="$SHOT_HEIGHT" \
    render_template "$(prompt_file persona.md)" >"$sys"

  video_start "$out/video.webm"
  local started_at step=0 history="" feedback="" outcome="limit" outcome_reason="" cost=0 bad=0
  started_at="$(date +%s)"
  : >"$out/actions.log"
  # The setup is timed too: a host that slept through the reset wakes up with
  # the network down, and the persona's first turns would pay for it.
  # So is a stall the previous run left behind, when this one began right after it.
  {
    carried_stall "${LAST_STALL:-}" "$t_run_start"
    printf 'reset\t%s\t0\t%s\t%s\n' "$t_run_start" "$((started_at - t_run_start))" "$RESET_ALLOW_SECONDS"
  } >"$out/steps/timing.tsv"

  while [ "$step" -lt "$max_steps" ]; do
    step=$((step + 1))
    local sid shot hints prompt reply json action did rc c t_start t_reply think allow calls act
    sid="$(printf 'shot-%03d' "$step")"
    shot="$out/shots/$sid.png"
    t_start="$(date +%s)"
    sleep "$SETTLE_SECONDS"
    shot_take "$shot"
    if [ ! -s "$shot" ]; then
      sleep 3
      shot_take "$shot"
    fi
    if [ ! -s "$shot" ]; then
      outcome="error"
      outcome_reason="no screenshot from the device at $sid"
      break
    fi
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
    t_reply="$(date +%s)"
    think=$((t_reply - t_start))
    if [ "$think" -gt "$STALL_SECONDS" ]; then
      # The host slept or the call hung. The network is often still down for a
      # while after a wake, so give it a moment before touching the app again.
      log "WARNING: $sid took ${think}s — rig stall, the run is marked as tainted"
      sleep "$POST_STALL_WAIT"
      t_reply="$(date +%s)"
    fi

    if [ -z "$json" ] || [ -z "$(jq -r '.action.type // empty' <<<"$json")" ]; then
      bad=$((bad + 1))
      printf '%s\t%s\tINVALID\t%s\n' "$sid" "$(date +%H:%M:%S)" "$(printf '%s' "$reply" | tr '\n' ' ' | head -c 300)" >>"$out/actions.log"
      if grep -q 'Not logged in\|Invalid API key\|authentication' "$out/steps/$sid.jsonl" "$out/steps/$sid.jsonl.stderr" 2>/dev/null; then
        video_stop
        device_profile_restore
        die "claude is not authenticated — see docs/how-it-works.md (ANTHROPIC_API_KEY or claude setup-token)"
      fi
      [ "$bad" -ge 3 ] && { outcome="error"; outcome_reason="3 invalid replies in a row"; break; }
      feedback="Your previous reply was not a valid JSON object with an \"action\". Reply with JSON only."
      printf '%s\t%s\t%s\t0\t0\n' "$sid" "$t_start" "$think" >>"$out/steps/timing.tsv"
      continue
    fi
    bad=0
    printf '%s\n' "$json" >"$out/steps/$sid.json"
    action="$(jq -c .action <<<"$json")"

    if persona_avoids "$persona" "$(jq -r .type <<<"$action")"; then
      did="tego gestu nie używasz ($(jq -r .type <<<"$action")) — zrób to, co ta osoba zrobiłaby naprawdę"
      rc=1
    else
      did="$(perform_action "$action")"
      rc=$?
    fi
    # Typing is paced like a person's, so a long text legitimately takes long:
    # the allowance grows with the device calls it takes.
    calls=0
    [ "$(jq -r .type <<<"$action")" != type ] || calls="$(type_calls "$(jq -r '.text // ""' <<<"$action")")"
    allow=$((calls * TYPE_CALL_SECONDS))
    act=$(($(date +%s) - t_reply))
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$sid" "$t_start" "$think" "$act" "$allow" "$calls" >>"$out/steps/timing.tsv"
    if [ "$calls" -ge "$TYPE_SLOW_MIN_CALLS" ] && [ "$act" -gt "$allow" ] && [ "$act" -le $((STALL_SECONDS + allow)) ]; then
      log "WARNING: $sid typed $calls words and lines in ${act}s — too slow to trust the text, the run is marked as tainted"
    fi
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
  local t_close
  t_close="$(date +%s)"

  # --- the end state: what is really in the app now ---
  if wants_end_state "$persona"; then
    sleep "$CAPTURE_SETTLE_SECONDS" # deferred writes (an undo window) must land first
    (capture_state after "$state" "$lang") >"$out/state.md" 2>"$out/steps/capture-after.log" ||
      log "WARNING: capture_state failed for $id run $run_no — see $out/steps/capture-after.log"
  fi
  device_profile_restore || log "WARNING: could not restore the device's font scale and theme — the next run retries"
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
    render_template "$(prompt_file report.md)" >"$out/steps/report-prompt.md"
  user_message "$(cat "$out/steps/report-prompt.md")" |
    isolated_claude "$MODEL_PERSONA" "$sys" "$out/steps/report.jsonl" >"$out/report.raw.md"
  cost="$(add_cost "$cost" "$(result_cost "$out/steps/report.jsonl")")"

  check_citations "$out/report.raw.md" "$out/shots" "$step" >"$out/report.md"
  render_think_aloud "$out" "$title" >"$out/think-aloud.md"

  # --- did it really work? the end state against the persona's claim ---
  local expect_json="[]" judge_json="null" taint
  if [ -s "$out/state.md" ]; then
    state_new_lines "$out/state-before.md" "$out/state.md" >"$out/state-new.md"
    expect_json="$(check_expectations "$persona" "$out/state-new.md")" || expect_json="[]"
    if [ "$JUDGE_OUTCOME" = 1 ] && jq -e '(.needs // []) | length > 0' <<<"$persona" >/dev/null; then
      judge_json="$(judge_outcome "$persona" "$out" "$outcome" "$outcome_reason" "$lang" "$out/steps/judge-system.md")"
      cost="$(add_cost "$cost" "$(result_cost "$out/steps/judge.jsonl")")"
      jq -e '.needs | type == "array"' <<<"${judge_json:-null}" >/dev/null 2>&1 || {
        log "WARNING: the outcome judge gave no usable answer for $id run $run_no"
        judge_json="null"
      }
    fi
  fi
  outcome_verdict "$expect_json" "$judge_json" "$outcome" >"$out/outcome.json"
  # Everything since the last turn is timed as one piece: a host that slept
  # through the report or the judge is a stall like any other.
  printf 'close\t%s\t0\t%s\t%s\n' "$t_close" "$(($(date +%s) - t_close))" "$CLOSE_ALLOW_SECONDS" >>"$out/steps/timing.tsv"
  taint="$(run_taint "$out")"
  [ -n "$taint" ] || taint="[]"
  LAST_STALL="$(run_last_stall "$out")" # for the next run of this session

  jq -n --arg id "$id" --arg name "$name" --argjson run "$run_no" --arg state "$state" --arg lang "$lang" \
    --argjson steps "$step" --arg outcome "$outcome" --arg reason "$outcome_reason" \
    --argjson cost "$cost" --argjson secs "$(($(date +%s) - started_at))" \
    --argjson rejected "$(grep -c '^- ' <(sed -n '/^## Odrzucone/,$p' "$out/report.md") || true)" \
    --argjson taint "$taint" --slurpfile verdict "$out/outcome.json" \
    '{id: $id, name: $name, run: $run, start_state: $state, language: $lang, steps: $steps,
      outcome: $outcome, outcome_reason: $reason, cost_usd: $cost, seconds: $secs,
      rejected_findings: $rejected,
      verified: $verdict[0].verified, self_report: $verdict[0].self_report,
      tainted: (($taint | length) > 0 or $outcome == "error"), taint: $taint}' >"$out/summary.json"
  log "■ $id (run $run_no): $outcome after $step steps, verified: $(jq -r .verified "$out/outcome.json")$(
    [ "$taint" = "[]" ] || printf ', TAINTED'
  ), \$$cost"
}
