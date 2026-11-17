#!/bin/bash
# Self-test of the engine's own logic. No device, no model, no app: only the
# parts that decide something by themselves — rig incidents, the outcome
# verdict, expectation patterns, the evidence rule, the findings ledger, the
# session comparison and the seeded-defect score (with a stand-in for the CLI),
# and the device profile's save and restore (with a stand-in for adb).
#
#   bash engine/selftest.sh
#
# Exit 0 = every check passed. Run it after any change to engine/lib.
set -uo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$DIR/lib/common.sh"

T="$(mktemp -d "${TMPDIR:-/tmp}/persona-selftest.XXXXXX")"
trap '[ -n "$T" ] && [ -d "$T" ] && rm -rf "$T"' EXIT

# What load_config would have set.
CONFIG_DIR="$T"
HISTORY_DIR="$T/history"
RUNS_DIR="$T/runs"
APP_NAME="Selftest"
SYNTHESIS_LANG=en
STALL_SECONDS=180
POST_STALL_SECONDS=180
RESET_ALLOW_SECONDS=600
CLOSE_ALLOW_SECONDS=600
TYPE_CALL_SECONDS=5
TYPE_SLOW_MIN_CALLS=10
JUDGE_OUTCOME=1
MODEL_SCORER=stub
MAX_BUDGET_SYNTHESIS=1
MAX_BUDGET_PER_CALL=1
EVIDENCE_SECTIONS="Problemy|Problems|Życzenia|Wishes"
CLAUDE_AUTH_FLAGS=""
mkdir -p "$HISTORY_DIR" "$RUNS_DIR"

# shellcheck source=lib/report.sh
source "$DIR/lib/report.sh"
# shellcheck source=lib/verify.sh
source "$DIR/lib/verify.sh"
# shellcheck source=lib/ledger.sh
source "$DIR/lib/ledger.sh"
# shellcheck source=lib/calibration.sh
source "$DIR/lib/calibration.sh"
# shellcheck source=lib/compare.sh
source "$DIR/lib/compare.sh"
# shellcheck source=lib/persona-loop.sh
source "$DIR/lib/persona-loop.sh"

PASS=0
FAIL=0
# check <name> <actual> <expected>
check() {
  if [ "$2" = "$3" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL  %s\n      expected: %s\n      actual:   %s\n' "$1" "$3" "$2"
  fi
}
TAB="$(printf '\t')"
row() {
  local IFS="$TAB"
  printf '%s\n' "$*"
}

# --- rig incidents ---------------------------------------------------------------

mkdir -p "$T/run/steps"
{
  row reset 1000 0 120 600      # a normal setup
  row shot-001 1120 9 1 0
  row shot-002 1130 400 2 0     # the host slept while the model was thinking
  row shot-003 1540 8 1 0       # starts right after: suspect
  row shot-004 1800 8 250 200   # 100 words typed: slow, and allowed to be
  row shot-005 2060 8 250 0     # the same time with nothing to type: a stall
  row shot-006 2500 8 1 0
} >"$T/run/steps/timing.tsv"
check "taint: a slow turn and a hung action, typing excused" \
  "$(run_taint "$T/run" | jq -c '[.[] | [.at, .seconds, (.suspect_steps | join(" "))]]')" \
  '[["shot-002",400,"shot-002 shot-003"],["shot-005",258,"shot-005 shot-006"]]'

{
  row reset 1000 0 4000 600     # the host slept through the reset
  row shot-001 5000 9 1 0
  row shot-002 5100 9 1 0
  row shot-003 5400 9 1 0
} >"$T/run/steps/timing.tsv"
check "taint: a stall during the setup makes the first turns suspect" \
  "$(run_taint "$T/run" | jq -c '.[0] | [.at, (.suspect_steps | join(" "))]')" \
  '["reset","reset shot-001 shot-002"]'

mkdir -p "$T/legacy"
{
  row shot-001 23:50:00 '{}' x
  row shot-002 23:50:10 '{}' x
  row shot-003 00:40:10 '{}' x   # across midnight, 50 minutes later
  row shot-004 00:40:20 '{}' x
} >"$T/legacy/actions.log"
check "taint: runs recorded before timing.tsv, across midnight" \
  "$(run_taint "$T/legacy" | jq -c '.[0] | [.at, .seconds, (.suspect_steps | join(" "))]')" \
  '["shot-003",3000,"shot-003 shot-004"]'

mkdir -p "$T/clean/steps"
row shot-001 1000 9 1 0 >"$T/clean/steps/timing.tsv"
check "taint: a clean run has none" "$(run_taint "$T/clean")" '[]'

# Typing: one device call per word and one per line break, as type_text makes
# them. Counted on spaces alone, "starter\n- 50" was one word and a recipe of
# eleven lines got the allowance of a sentence.
check "typing: device calls are words plus line breaks" \
  "$(type_calls "one two") $(type_calls "$(printf '# Dough\n- 400 g flour\n\n- 10 g salt')") $(type_calls "")" "2 13 0"

{
  row reset 1000 0 120 600
  row shot-001 1120 9 283 305 61   # 51 words on 11 lines at 4.6 s a call: slow, and whole
  row shot-002 1420 7 233 200 40   # 5.8 s a call: this is where letters went missing
  row shot-003 1660 6 30 15 3      # three words in 30 s: too few calls to judge a rate
  row shot-004 1700 8 500 200 40   # typing that hung: a stall, not slow typing
  row shot-005 2210 8 1 0 0
  row close 2220 0 250 600
} >"$T/run/steps/timing.tsv"
check "taint: typing slower than the rate the rig can keep is its own incident" \
  "$(run_taint "$T/run" | jq -c '[.[] | [.kind, .at, .seconds, (.suspect_steps | join(" "))]]')" \
  '[["slow_typing","shot-002",233,"shot-002"],["stall","shot-004",508,"shot-004 shot-005"]]'

# The report, the end state and the judge come after the last turn. A host
# that sleeps there used to leave no trace: two hours, and a clean run.
{
  row reset 1000 0 120 600
  row shot-001 1120 9 1 0 0
  row close 1130 0 7644 600
} >"$T/run/steps/timing.tsv"
check "taint: a stall after the last turn is recorded" \
  "$(run_taint "$T/run" | jq -c '[.[] | [.kind, .at, .seconds, (.suspect_steps | join(" "))]]')" \
  '[["stall","close",7644,"close"]]'
check "taint: where and when the last stall of a run ended" "$(run_last_stall "$T/run")" "8774${TAB}7644"
check "taint: a run without a stall has no last one" "$(run_last_stall "$T/clean")" ""

# The next run starts on a rig that has just stalled. Its setup takes minutes,
# so no turn falls into the three minutes after the stall, and the run used to
# come out clean.
{
  row after 8774 7644
  row reset 8778 0 256 600
  row shot-001 9034 9 1 0 0
  row shot-002 9500 9 1 0 0
  row close 9600 0 250 600
} >"$T/run/steps/timing.tsv"
check "taint: a run that starts right after a stall is suspect as a whole" \
  "$(run_taint "$T/run" | jq -c '[.[] | [.kind, .at, .seconds, (.suspect_steps | join(" "))]]')" \
  '[["after_stall","reset",7644,"shot-001 shot-002"]]'
check "taint: the carried stall is not this run's own last stall" "$(run_last_stall "$T/run")" ""
check "taint: carried over within the window, not after it" \
  "$(carried_stall "8774${TAB}7644" 8778 | cut -f1) [$(carried_stall "8774${TAB}7644" 9000)] [$(carried_stall "" 9000)]" "after [] []"

# The synthesis is a model's reply, and a model sometimes says a sentence
# before it starts. That sentence went into the report and into the history.
printf 'I have everything I need. Writing the synthesis.\n\n# Synthesis\n\n## Summary\n# not a heading we cut at\n' >"$T/pre.md"
strip_preamble "$T/pre.md"
check "synthesis: the report starts at its first heading" "$(head -1 "$T/pre.md") $(wc -l <"$T/pre.md" | tr -d ' ')" "# Synthesis 4"
printf 'No heading at all.\nSecond line.\n' >"$T/pre.md"
strip_preamble "$T/pre.md"
check "synthesis: a reply without a heading is kept whole" "$(wc -l <"$T/pre.md" | tr -d ' ')" "2"

# --- the end state -----------------------------------------------------------------

printf '%s\n' '- Old cake' '' '## Item: Old cake' '    INGREDIENTS' '    1 egg' >"$T/before.md"
printf '%s\n' '- Hi Ann this is the cake' '- Old cake' '' '## Item: Hi Ann this is the cake' '    1 egg' '    kisses, mum' '' \
  '## Item: Old cake' '    INGREDIENTS' '    1 egg' >"$T/after.md"
state_new_lines "$T/before.md" "$T/after.md" >"$T/new.md"
check "state: only what the session added counts" "$(grep -c 'Old cake' "$T/new.md")" "0"
check "state: no first read means everything counts" "$(state_new_lines "$T/missing.md" "$T/after.md" | grep -c 'Old cake')" "2"

P='{"expect":[{"need":1,"label":"saved","matches":"cake"},{"need":2,"label":"own section","matches":"(?m)^\\s*INGREDIENTS\\s*$"},
  {"need":3,"label":"no private notes","lacks":"kisses"},{"need":1,"label":"both","matches":"egg","lacks":"advert"},{"need":1,"label":"broken","matches":"(("}]}'
check "expect: matches / lacks against the added lines, a broken pattern is null" \
  "$(check_expectations "$P" "$T/new.md" | jq -c '[.[] | .pass]')" \
  '[true,false,false,true,true,null]'

verdict() { outcome_verdict "$1" "$2" "$3" | jq -r '"\(.verified) \(.self_report)"'; }
check "verdict: done, but a pattern fails" "$(verdict '[{"pass":true},{"pass":false}]' '{"needs":[{"verdict":"met"}]}' done)" "partly overclaimed"
check "verdict: gave up although everything is there" "$(verdict '[]' '{"needs":[{"verdict":"met"},{"verdict":"met"}]}' give_up)" "met underclaimed"
check "verdict: done and nothing is there" "$(verdict '[]' '{"needs":[{"verdict":"not_met"}]}' done)" "not_met overclaimed"
check "verdict: done and confirmed" "$(verdict '[{"pass":true}]' '{"needs":[{"verdict":"met"},{"verdict":"unverifiable"}]}' done)" "met consistent"
check "verdict: done, incomplete, but nothing the person believes is missing" "$(verdict '[]' '{"needs":[{"verdict":"partly","claimed":true},{"verdict":"met","claimed":true}]}' done)" "partly consistent"
check "verdict: done, and the person says themselves that a need failed" "$(verdict '[]' '{"needs":[{"verdict":"not_met","claimed":false},{"verdict":"partly","claimed":true}]}' done)" "partly consistent"
check "verdict: done, and a need the person believes in is not there" "$(verdict '[]' '{"needs":[{"verdict":"not_met","claimed":true},{"verdict":"met","claimed":true}]}' done)" "partly overclaimed"
check "verdict: a failed pattern on a need the person disclaims" "$(verdict '[{"need":1,"pass":false}]' '{"needs":[{"verdict":"not_met","claimed":false}]}' done)" "not_met consistent"
check "verdict: a failed pattern on a need the person believes in" "$(verdict '[{"need":2,"pass":false}]' '{"needs":[{"verdict":"met","claimed":true},{"verdict":"partly","claimed":true}]}' done)" "partly overclaimed"
check "verdict: nothing was checked" "$(verdict '[]' 'null' done)" "none unknown"
check "verdict: nothing could be checked" "$(verdict '[]' '{"needs":[{"verdict":"unverifiable"}]}' done)" "unverifiable unknown"

# --- gestures ------------------------------------------------------------------------

LOW='{"avoids":["long_press"]}'
check "gestures: an avoided one is not offered" "$(persona_actions "$LOW" | grep -c long_press)" "0"
check "gestures: the rest still is" "$(persona_actions "$LOW" | grep -c '"swipe"')" "1"
check "gestures: nothing avoided, everything offered" "$(persona_actions '{}' | grep -c 'long_press\|"swipe"')" "2"
check "gestures: refused by the engine" "$(persona_avoids "$LOW" long_press && echo refused)" "refused"
check "gestures: tap can never be ruled out" "$(persona_avoids '{"avoids":["tap"]}' tap || echo allowed)" "allowed"

# --- the evidence rule ------------------------------------------------------------------

mkdir -p "$T/shots"
: >"$T/shots/shot-001.png"
printf '%s\n' '# R' '## Problemy' '- with proof [shot-001]' '- no proof' '- wrong proof [shot-009]' '## Uwagi końcowe' '- free text' >"$T/report.raw.md"
check_citations "$T/report.raw.md" "$T/shots" 1 >"$T/report.md"
check "evidence: uncited bullets are rejected, cited ones linked" \
  "$(sed -n '/^## Odrzucone/,$p' "$T/report.md" | grep -c '^- ') $(grep -c 'shots/shot-001.png' "$T/report.md")" "2 1"

# --- small plumbing ---------------------------------------------------------------------

check "extract_json: fenced output" "$(printf 'Sure:\n```json\n{"a": 1}\n```\n' | extract_json)" '{"a":1}'
printf 'x {{KNOWN}} {{UNKNOWN}}\n' >"$T/tpl.md"
check "render_template: unknown keys stay visible" "$(T_KNOWN=ok render_template "$T/tpl.md")" 'x ok {{UNKNOWN}}'

# --- the ledger ----------------------------------------------------------------------------

OLD="$T/runs/20000101-000000"   # before any verdict the owner gives below
NEW="$T/runs/29990101-000000"   # after it
mkdir -p "$OLD" "$NEW"
echo '{"version":"1.0","runs":[]}' >"$OLD/summary.json"
echo '{"version":"1.1","runs":[]}' >"$NEW/summary.json"
ledger() { jq -c '[.findings[] | [.id, .status, (.sightings | length)]]' "$HISTORY_DIR/findings.json"; }

cat >"$OLD/synthesis.md" <<'EOF'
### [NEW-1] No confirmation after saving — P2
### [NEW-12] Another one — P3
### [NEW-2] Bigger text
<!-- persona-lab-findings
[{"id": "NEW-1", "status": "reproduced", "kind": "problem", "title": "No confirmation after saving", "priority": "P2", "personas": ["a", "b"], "runs": 3, "where": ["x.tsx:1"]},
 {"id": "NEW-12", "status": "reproduced", "kind": "problem", "title": "Another | one", "priority": "P3"},
 {"id": "NEW-2", "status": "reproduced", "kind": "wish", "title": "Bigger text"}]
-->
EOF
found="$(extract_findings "$OLD/synthesis.md")"
check "ledger: the block is read and removed from the report" "$(jq length <<<"$found") $(grep -c 'persona-lab-findings' "$OLD/synthesis.md")" "3 0"
ledger_merge "$OLD" "$found" 2>/dev/null
check "ledger: new findings get ids" "$(ledger)" '[["F-001","open",1],["F-002","open",1],["F-003","open",1]]'
check "ledger: the report shows the ids, NEW-1 does not eat NEW-12" "$(tr '\n' ' ' <"$OLD/synthesis.md" | grep -o '\[[A-Z0-9-]*\]' | tr -d '\n')" "[F-001][F-002][F-003]"

printf 'garbage\n<!-- persona-lab-findings\n{not json}\n-->\n' >"$T/bad.md"
check "ledger: an unreadable block yields nothing" "$(extract_findings "$T/bad.md")" ""

(ledger_set F-001 fixed "commit abc") 2>/dev/null
(ledger_set F-002 fixed) 2>/dev/null
check "ledger: an unknown id is refused" "$( (ledger_set F-404 fixed) 2>/dev/null; echo $?)" "1"
check "ledger: an unknown status is refused" "$( (ledger_set F-001 done) 2>/dev/null; echo $?)" "1"

# The old session is synthesized again and calls its findings new again.
ledger_merge "$OLD" '[{"id":"NEW-1","status":"reproduced","kind":"problem","title":"no  confirmation after SAVING"},{"id":"NEW-2","status":"reproduced","kind":"wish","title":"Bigger text"}]' 2>/dev/null
check "ledger: a re-synthesis keeps ids and the owner's verdict, and drops what it no longer reports" \
  "$(ledger)" '[["F-001","fixed",1],["F-003","open",1]]'

# A later session: F-001 is back, F-003 was exercised and did not happen.
(ledger_set F-003 fixed) 2>/dev/null
ledger_merge "$NEW" '[{"id":"F-001","status":"reproduced"},{"id":"F-003","status":"not_reproduced"},{"id":"F-777","status":"not_reproduced"},{"id":"NEW-1","status":"reproduced","kind":"problem","title":"Fresh"}]' 2>/dev/null
check "ledger: fixed + reproduced = regressed, fixed + not reproduced = verified" \
  "$(ledger)" '[["F-001","regressed",2],["F-003","verified",2],["F-004","open",1]]'
ledger_merge "$NEW" '[{"id":"F-001","status":"not_exercised"}]' 2>/dev/null
check "ledger: merging that session again takes its verdicts back" "$(ledger)" '[["F-001","fixed",1],["F-003","fixed",1]]'
check "ledger: rendered for people" "$(grep -c '^| F-' "$HISTORY_DIR/findings.md")" "2"
check "ledger: listed for the synthesis" "$(ledger_for_prompt | head -1)" "- F-001 [fixed, problem, P2] No confirmation after saving — x.tsx:1"

# --- comparing sessions ----------------------------------------------------------------------

mkdir -p "$OLD/p1/run-1" "$NEW/p1/run-1"
echo '{"id":"p1","run":1,"steps":12,"outcome":"done","verified":"partly","self_report":"overclaimed","taint":[],"tainted":false}' >"$OLD/p1/run-1/summary.json"
echo '{"id":"p1","run":1,"steps":9,"outcome":"done","verified":"met","self_report":"consistent","taint":[{"kind":"stall"}],"tainted":true}' >"$NEW/p1/run-1/summary.json"
echo '[{"id":"F-001","status":"reproduced"},{"id":"F-003","status":"reproduced"}]' >"$OLD/findings.json"
echo '[{"id":"F-001","status":"not_reproduced"},{"id":"F-003","status":"reproduced"}]' >"$NEW/findings.json"
cmp_out="$(compare_sessions "$OLD" "$NEW")"
check "compare: per persona, with the end-state verdict and the rig flag" \
  "$(printf '%s\n' "$cmp_out" | grep '^| `p1`')" '| `p1` | done/partly (12) | done/met (9) ⚠ |'
check "compare: what is gone, and whether the flow was exercised" \
  "$(printf '%s\n' "$cmp_out" | grep -c '^- F-001 .*B: `not_reproduced`')" "1"

# --- the seeded-defect score -------------------------------------------------------------------

cat >"$T/stub-claude" <<'EOF'
#!/bin/bash
cat >/dev/null
jq -cn '{type: "result", total_cost_usd: 0, result: "{\"defects\":[{\"id\":\"S1\",\"verdict\":\"reported\",\"runs\":[\"p1/run-1\"],\"quote\":\"q\"},{\"id\":\"S2\",\"verdict\":\"noticed\"},{\"id\":\"S4\",\"verdict\":\"not_exercised\"},{\"id\":\"S5\",\"verdict\":\"made up\"}]}"}'
EOF
chmod +x "$T/stub-claude"
CLAUDE_BIN="$T/stub-claude"
printf '# R\n## Problemy\n- nothing told me it saved [shot-001]\n' >"$NEW/p1/run-1/report.md"
echo '{"defects":[{"id":"S1","defect":"a"},{"id":"S2","defect":"b"},{"id":"S3","defect":"c"},{"id":"S4","defect":"d"},{"id":"S5","defect":"e"}]}' >"$T/seeded.json"
score_seeded "$NEW" "$T/seeded.json" 2>/dev/null
check "seeded: recall over the defects somebody reached; skipped and unknown verdicts count as missed" \
  "$(jq -c '[.reported, .noticed, .missed, .not_exercised, .reachable, .recall]' "$NEW/seeded-score.json")" '[1,1,2,1,4,0.25]'
check "seeded: one table row per planted defect" "$(grep -c '^| S' "$NEW/seeded-score.md")" "5"

# --- the history: links do not depend on what the folders are called -------------------------

# shellcheck source=lib/history.sh
source "$DIR/lib/history.sh"
(
  APP_REPO="$T/app"
  RUNS_DIR="$APP_REPO/qa/sessions"
  HISTORY_DIR="$APP_REPO/qa/log/history"
  S="$RUNS_DIR/20260102-030405"
  mkdir -p "$S"
  echo '{"version":"1.0","engine":"abc1234","runs":[{"id":"p1","run":1,"steps":3,"outcome":"done","cost_usd":0.1}]}' >"$S/summary.json"
  echo '{"personas":[{"id":"p1","name":"P, 30","language":"en","start_state":"fresh","tech_level":"low","summary":"s"}]}' >"$S/personas.json"
  printf '# Synthesis\n\nSee [the shot](qa/sessions/20260102-030405/p1/run-1/shots/shot-001.png).\n' >"$S/synthesis.md"
  archive_session "$S" 2>/dev/null
  cat "$HISTORY_DIR/01-2026-01-02.md"
) >"$T/history-out.md" 2>/dev/null
check "history: screenshot links are rewritten relative to the history file" \
  "$(grep -c '](../../sessions/20260102-030405/p1/run-1/shots/shot-001.png)' "$T/history-out.md")" "1"
check "history: the entry names the engine commit the session ran on" \
  "$(grep -c '^- \*\*Engine (persona-lab commit):\*\* `abc1234`$' "$T/history-out.md")" "1"
check "history: the raw-data link follows RUNS_DIR" \
  "$(grep -c '](../../sessions/20260102-030405/)' "$T/history-out.md")" "1"

# --- the device profile, against a stand-in adb --------------------------------------------------

# The fake device keeps font_scale and night mode in two files and logs every
# call; ADB_FAIL=font or ADB_FAIL=night makes that one "put" fail.
# shellcheck source=lib/device.sh
source "$DIR/lib/device.sh"
mkdir -p "$T/bin" "$T/dev"
cat >"$T/bin/adb" <<'EOF'
#!/bin/bash
D="${FAKE_DEVICE:?}"
shift 2 # -s <serial>
echo "$*" >>"$D/calls"
case "$*" in
  "shell settings get system font_scale") cat "$D/font" ;;
  "shell settings put system font_scale "*) [ "${ADB_FAIL:-}" != font ] || exit 1; echo "${!#}" >"$D/font" ;;
  "shell cmd uimode night") echo "Night mode: $(cat "$D/night")" ;;
  "shell cmd uimode night "*) [ "${ADB_FAIL:-}" != night ] || exit 1; echo "${!#}" >"$D/night" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$T/bin/adb"
ANDROID_SERIAL=emulator-5554
export FAKE_DEVICE="$T/dev"
on_device() { printf '%s %s %s' "$(cat "$T/dev/font")" "$(cat "$T/dev/night")" "$(cat "$(device_profile_file)" 2>/dev/null | tr '\t' '/')"; }
dev_set() { echo "$1" >"$T/dev/font"; echo "$2" >"$T/dev/night"; : >"$T/dev/calls"; }

dev_set 1.0 no
PATH="$T/bin:$PATH" device_profile_apply 1.3 true
check "profile: a persona's profile goes on, the device's own is kept in a file" "$(on_device)" "1.3 yes 1.0/no"
PATH="$T/bin:$PATH" device_profile_restore
check "profile: the device's own comes back and the file is gone" "$(on_device)" "1.0 no "

# A session killed with -9 in the middle of a run: the device is at the
# persona's 1.3, the file still holds 1.0. The next run must not take 1.3 for
# the device's own.
dev_set 1.3 yes
printf '1.0\tno\n' >"$(device_profile_file)"
PATH="$T/bin:$PATH" device_profile_apply 1.15 false
check "profile: a leftover file is not overwritten by the next persona's apply" "$(on_device)" "1.15 no 1.0/no"
PATH="$T/bin:$PATH" device_profile_restore
check "profile: after a killed session, the restore goes back to the device's own" "$(on_device)" "1.0 no "

dev_set 1.3 yes
printf '1.0\tno\n' >"$(device_profile_file)"
PATH="$T/bin:$PATH" ADB_FAIL=font device_profile_restore
check "profile: a restore whose font call fails keeps the file" "$? $(on_device)" "1 1.3 yes 1.0/no"
PATH="$T/bin:$PATH" ADB_FAIL=night device_profile_restore
check "profile: a restore whose theme call fails keeps the file" "$? $(on_device)" "1 1.0 yes 1.0/no"
rm -f "$(device_profile_file)"

dev_set 1.0 no
PATH="$T/bin:$PATH" device_profile_restore
check "profile: with no file, a restore makes no device call" "$? $(wc -l <"$T/dev/calls" | tr -d ' ')" "0 0"

# The traps run.sh sets, in a shell that is then sent TERM in the middle of a
# run: it must stop there (exit 143), not carry on, and restore on the way out.
# A process of its own, so that $$ is the shell being killed (bash 3.2 has no
# BASHPID for a subshell).
dev_set 1.0 no
PATH="$T/bin:$PATH" RUNS_DIR="$RUNS_DIR" ANDROID_SERIAL="$ANDROID_SERIAL" "$BASH" -c '
  source "$1/lib/common.sh"
  source "$1/lib/device.sh"
  device_exit_traps
  device_profile_apply 1.3 true
  kill -TERM $$
  echo carried-on >"$FAKE_DEVICE/after-term"' _ "$DIR" 2>/dev/null
check "profile: TERM in the middle of a run ends the session and restores on exit" \
  "$? $(on_device)|$(cat "$T/dev/after-term" 2>/dev/null)" "143 1.0 no |"

# --- the isolation check, against a stand-in CLI -----------------------------------------------

# The stand-in is a model that does what the probe asks: with the Read tool it
# returns the content of the canary file named in the message, without it
# nothing from disk. LEAK=1 makes it return the canary with no tool at all.
APP="$T/iso-app"
mkdir -p "$APP/persona-lab/config"
cat >"$APP/persona-lab/config/config.sh" <<'EOF'
APP_ID=com.example.selftest
APP_REPO="$(cd "$CONFIG_DIR/../.." && pwd)"
ANDROID_SERIAL=none
EOF
echo 'A public store listing.' >"$APP/persona-lab/config/brief.md"
cat >"$T/stub-probe-claude" <<'EOF'
#!/bin/bash
[ "${1:-}" = --version ] && { echo stub; exit 0; }
msg="$(cat)"
tools='[]'
reply='{"tools": [], "canary": "NONE"}'
case " $* " in *' --tools Read '*) tools='["Read"]' ;; esac
if [ "$tools" != '[]' ] || [ "${LEAK:-0}" = 1 ]; then
  file="$(printf '%s' "$msg" | jq -r '.message.content[0].text' | sed -n 's/^1\. Read the file \(.*\) and quote.*/\1/p')"
  reply="$(cat "$file" 2>/dev/null)"
fi
jq -cn --argjson tools "$tools" --arg cwd "$PWD" '{type: "system", subtype: "init", tools: $tools, mcp_servers: [], cwd: $cwd}'
jq -cn --arg r "$reply" '{type: "result", total_cost_usd: 0, result: $r}'
EOF
chmod +x "$T/stub-probe-claude"
(cd "$APP" && CLAUDE_BIN="$T/stub-probe-claude" bash "$DIR/verify-isolation.sh" persona-lab/config --out iso-out --with-control) >/dev/null 2>&1
rc=$?
check "isolation: holds, and the positive control leaks, with a relative --out" \
  "$rc $(grep -c 'the canary leaked when Read was allowed' "$APP/iso-out/isolation.md" 2>/dev/null)" "0 1"
(cd "$APP" && LEAK=1 CLAUDE_BIN="$T/stub-probe-claude" bash "$DIR/verify-isolation.sh" persona-lab/config --out "$APP/iso-leak") >/dev/null 2>&1
rc=$?
check "isolation: a persona call that returns the canary fails the check" \
  "$rc $(grep -c '^- ❌ canary not leaked' "$APP/iso-leak/isolation.md" 2>/dev/null)" "1 1"
check "isolation: the canary is removed from the repository afterwards" \
  "$(ls "$APP/persona-lab/runs/.isolation-canary.txt" 2>/dev/null | wc -l | tr -d ' ')" "0"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ]
