# shellcheck shell=bash
#
# Shared plumbing for persona-lab: config loading, logging, template rendering
# and the two ways this engine calls Claude.
#
# Source it, do not run it. Written for the stock macOS bash 3.2 — no
# associative arrays, no mapfile, no ${var,,}.
#
# This file (and everything under engine/) must never name a specific app.
# Anything app-specific comes from the config directory passed to run.sh, so
# the engine can move to its own repository unchanged.

ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROMPTS_DIR="$ENGINE_DIR/prompts"

log() { printf '[persona-lab %s] %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die() {
  log "ERROR: $*"
  exit 1
}

# load_config <config-dir> — sources <config-dir>/config.sh and fills defaults.
load_config() {
  CONFIG_DIR="$(cd "$1" && pwd)" || die "no such config dir: $1"
  [ -f "$CONFIG_DIR/config.sh" ] || die "missing $CONFIG_DIR/config.sh (copy engine/templates/config.sh)"
  # shellcheck source=/dev/null
  source "$CONFIG_DIR/config.sh"

  : "${APP_ID:?config.sh must set APP_ID}"
  : "${APP_REPO:?config.sh must set APP_REPO}"
  : "${ANDROID_SERIAL:?config.sh must set ANDROID_SERIAL}"
  APP_NAME="${APP_NAME:-$APP_ID}"
  APP_LANGUAGES="${APP_LANGUAGES:-en}"
  STATES="${STATES:-fresh}"
  PERSONA_COUNT="${PERSONA_COUNT:-5}"
  RUNS_PER_PERSONA="${RUNS_PER_PERSONA:-2}"
  MAX_STEPS="${MAX_STEPS:-40}"
  MODEL_PERSONA="${MODEL_PERSONA:-sonnet}"
  MODEL_GENERATOR="${MODEL_GENERATOR:-opus}"
  MODEL_SYNTHESIS="${MODEL_SYNTHESIS:-opus}"
  MAX_BUDGET_PER_CALL="${MAX_BUDGET_PER_CALL:-1.00}"
  MAX_BUDGET_SYNTHESIS="${MAX_BUDGET_SYNTHESIS:-5.00}"
  MAX_BUDGET_DESK_RESEARCH="${MAX_BUDGET_DESK_RESEARCH:-3.00}"
  EVIDENCE_SECTIONS="${EVIDENCE_SECTIONS:-Problemy|Problems|Życzenia|Wishes}"
  UI_HINTS="${UI_HINTS:-text}"
  SHOT_WIDTH="${SHOT_WIDTH:-540}"
  SETTLE_SECONDS="${SETTLE_SECONDS:-1.5}"
  # Outcome check: a model call per run that compares the persona's needs
  # with the end state read by the config's capture_state hook (verify.sh).
  JUDGE_OUTCOME="${JUDGE_OUTCOME:-1}"
  MODEL_JUDGE="${MODEL_JUDGE:-$MODEL_PERSONA}"
  MODEL_SCORER="${MODEL_SCORER:-$MODEL_SYNTHESIS}"
  STATE_MAX_CHARS="${STATE_MAX_CHARS:-24000}"
  CAPTURE_SETTLE_SECONDS="${CAPTURE_SETTLE_SECONDS:-6}"
  # Rig incidents: a turn slower than STALL_SECONDS means the host slept or a
  # call hung; turns starting within POST_STALL_SECONDS after it are suspect.
  STALL_SECONDS="${STALL_SECONDS:-180}"
  POST_STALL_SECONDS="${POST_STALL_SECONDS:-180}"
  POST_STALL_WAIT="${POST_STALL_WAIT:-30}"
  # The setup before the first turn (reset, reading the state) may take this
  # much longer than a turn before it counts as a stall.
  RESET_ALLOW_SECONDS="${RESET_ALLOW_SECONDS:-600}"
  # The same for what follows the last turn: reading the end state, the
  # persona's report, the judge. Three to five minutes on a healthy rig.
  CLOSE_ALLOW_SECONDS="${CLOSE_ALLOW_SECONDS:-600}"
  # Typing goes in one device call per word and per line break. A typing turn
  # may take this long per call; with TYPE_SLOW_MIN_CALLS calls or more, a
  # slower one is an incident of its own (verify.sh, slow_typing).
  TYPE_CALL_SECONDS="${TYPE_CALL_SECONDS:-5}"
  TYPE_SLOW_MIN_CALLS="${TYPE_SLOW_MIN_CALLS:-10}"
  SYNTHESIS_LANG="${SYNTHESIS_LANG:-pl}"
  SYNTHESIS_FOCUS="${SYNTHESIS_FOCUS:-}"
  RUNS_DIR="${RUNS_DIR:-$CONFIG_DIR/../runs}"
  HISTORY_DIR="${HISTORY_DIR:-$CONFIG_DIR/../history}"
  mkdir -p "$RUNS_DIR"
  RUNS_DIR="$(cd "$RUNS_DIR" && pwd)"
  export ANDROID_SERIAL

  BRIEF_FILE="$CONFIG_DIR/brief.md"
  [ -s "$BRIEF_FILE" ] || die "missing $BRIEF_FILE — the public app brief is required"
  if grep -q 'PERSONA-LAB-TEMPLATE' "$BRIEF_FILE"; then
    die "$BRIEF_FILE is still the template — write the brief first"
  fi
}

# strip_preamble <file> — drops what a model said before the document it was
# asked for: everything above the first "# " heading. A file without such a
# heading is left alone.
strip_preamble() {
  grep -q '^# ' "$1" || return 0
  perl -ni -e 'print if $on ||= /^# /' "$1"
}

# engine_version — the commit this engine is at, with "+" when it has
# uncommitted changes; nothing when it is not a git checkout. The app's
# repository does not pin the engine, so each session records what it ran on.
engine_version() {
  local v
  v="$(git -C "$ENGINE_DIR" rev-parse --short HEAD 2>/dev/null)" || return 0
  [ -z "$(git -C "$ENGINE_DIR" status --porcelain -- "$ENGINE_DIR" 2>/dev/null)" ] || v="$v+"
  printf '%s' "$v"
}

# rel_path <target> <base-dir> — <target> as a path relative to <base-dir>.
# Both must exist. Symlinks are resolved first, so /tmp and /private/tmp on
# macOS count as the same place.
rel_path() {
  perl -MCwd=realpath -MFile::Spec -e 'print File::Spec->abs2rel(realpath($ARGV[0]), realpath($ARGV[1])), "\n"' "$1" "$2"
}

# prompt_file <name> — the config's prompts/<name> when it has one (a study of
# another kind: other instructions, other report), else the engine's.
prompt_file() {
  if [ -f "$CONFIG_DIR/prompts/$1" ]; then echo "$CONFIG_DIR/prompts/$1"; else echo "$PROMPTS_DIR/$1"; fi
}

# brief_for <lang> — brief.<lang>.md when the config has one (a persona reads
# the store listing in its own language), else brief.md.
brief_for() {
  if [ -f "$CONFIG_DIR/brief.$1.md" ]; then echo "$CONFIG_DIR/brief.$1.md"; else echo "$BRIEF_FILE"; fi
}

# Start states are declared by the config as STATES="a b" plus, per state,
# STATE_DESC_<state> (for the persona generator: what the state is) and
# STATE_PERSONA_<state> (told to the persona: their situation, in user terms).
state_desc() { eval "printf '%s' \"\${STATE_DESC_$1:-}\""; }
state_persona_text() { eval "printf '%s' \"\${STATE_PERSONA_$1:-}\""; }

# resolve_claude — sets CLAUDE_BIN and CLAUDE_AUTH_FLAGS.
#
# With ANTHROPIC_API_KEY set, persona calls run under --bare: no CLAUDE.md
# discovery, no auto-memory, no hooks, no plugins, no keychain. Without it the
# CLI's own login is used and the same isolation comes from the flags in
# isolated_claude (verified by verify-isolation.sh either way).
resolve_claude() {
  if [ -z "${CLAUDE_BIN:-}" ]; then
    CLAUDE_BIN="$(command -v claude || true)"
  fi
  # No CLI on PATH: use the one bundled with the Claude desktop app (macOS),
  # newest version — the path changes with every app update.
  if [ -z "$CLAUDE_BIN" ]; then
    CLAUDE_BIN="$(ls -d "$HOME/Library/Application Support/Claude/claude-code"/*/*/claude.app/Contents/MacOS/claude 2>/dev/null | sort -V | tail -1)"
  fi
  [ -n "$CLAUDE_BIN" ] && [ -x "$CLAUDE_BIN" ] ||
    die "claude CLI not found — install Claude Code or set CLAUDE_BIN in config.sh"
  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    CLAUDE_AUTH_FLAGS="--bare"
  else
    CLAUDE_AUTH_FLAGS=""
  fi
}

# claude_cli <args...> — every model call the engine makes goes through here.
# It drops the markers of the Claude Code session the engine may be running in,
# and turns off two context sources outright: the auto-memory Claude Code keeps
# for the directory a call runs in, which --setting-sources "" does not stop,
# and CLAUDE.md files (the user's ~/.claude/CLAUDE.md and the repository's),
# which it does stop, here made independent of the flag. Without this, whatever
# the person running the study has in their own Claude setup can reach the
# model, and a session stops being comparable with the last one.
claude_cli() {
  env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT \
    CLAUDE_CODE_DISABLE_CLAUDE_MDS=1 CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 \
    "$CLAUDE_BIN" "$@"
}

# render_template <file> — prints the file with every {{KEY}} replaced by the
# value of the environment variable T_KEY. Unknown keys are left in place, so a
# typo shows up in the output instead of silently becoming an empty string.
render_template() {
  perl -pe 's/\{\{(\w+)\}\}/exists $ENV{"T_$1"} ? $ENV{"T_$1"} : "{{$1}}"/ge' "$1"
}

# isolated_claude <model> <system-prompt-file> <out.jsonl>
#
# The ONLY way a persona (or the persona generator) talks to a model. Reads one
# stream-json user message on stdin, writes the stream-json transcript to
# <out.jsonl>, prints the final result text on stdout.
#
# Isolation is by construction, not by permission rules:
#   --tools ""            no built-in tools at all: no Read, no Bash, no Grep…
#   --strict-mcp-config   no MCP servers (none are passed)
#   --setting-sources ""  no user/project/local settings, hence no plugins
#   claude_cli            no CLAUDE.md, no auto-memory (see above)
#   --system-prompt       replaces the default coding-agent prompt entirely
#   cwd = fresh empty dir outside any repository; checked empty afterwards
# The device is driven by the engine, never by the model.
isolated_claude() {
  local model="$1" sysfile="$2" out="$3" sandbox rc
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/persona-sandbox.XXXXXX")"
  # shellcheck disable=SC2086
  (
    cd "$sandbox" &&
      claude_cli -p $CLAUDE_AUTH_FLAGS \
        --input-format stream-json --output-format stream-json --verbose \
        --tools "" --strict-mcp-config --setting-sources "" \
        --no-session-persistence \
        --model "$model" \
        --max-budget-usd "$MAX_BUDGET_PER_CALL" \
        --system-prompt "$(cat "$sysfile")"
  ) >"$out" 2>"$out.stderr"
  rc=$?
  if [ -n "$(ls -A "$sandbox")" ]; then
    log "WARNING: sandbox $sandbox is not empty after a persona call: $(ls -A "$sandbox" | tr '\n' ' ')"
  else
    rmdir "$sandbox"
  fi
  [ -s "$out.stderr" ] || rm -f "$out.stderr"
  result_text "$out"
  return $rc
}

# repo_claude <model> <budget> <prompt-file> <out.json> — the synthesis agent.
# Runs in the app repository with read-only tools; it is the one component
# that is supposed to see code. It sees it through those tools only: no
# settings, plugins or hooks (--setting-sources ""), and through claude_cli no
# CLAUDE.md and no auto-memory, so the developer's notes about the app and the
# person's own Claude instructions stay out of the verdict.
repo_claude() {
  local model="$1" budget="$2" prompt="$3" out="$4"
  (
    cd "$APP_REPO" &&
      claude_cli -p \
        --output-format json \
        --tools "Read,Grep,Glob" --allowedTools "Read" "Grep" "Glob" \
        --strict-mcp-config --setting-sources "" --no-session-persistence \
        --model "$model" --max-budget-usd "$budget" <"$prompt"
  ) >"$out" 2>"$out.stderr"
  local rc=$?
  [ -s "$out.stderr" ] || rm -f "$out.stderr"
  jq -r '.result // empty' "$out" 2>/dev/null
  return $rc
}

# scope_snapshot <session> — prints a new directory outside the repository with
# only what the config lists in SYNTHESIS_SCOPE plus this session, at the same
# relative paths, so that links in the report still resolve from the repo root.
# The config's scope_scrub <dir> runs before the session is copied in.
scope_snapshot() {
  local session="$1" dir rel
  dir="$(mktemp -d "${TMPDIR:-/tmp}/persona-scope.XXXXXX")" || return 1
  dir="$(cd "$dir" && pwd -P)"
  for rel in $SYNTHESIS_SCOPE; do
    mkdir -p "$dir/$(dirname "$rel")"
    cp -R "$APP_REPO/$rel" "$dir/$rel" || return 1
  done
  if declare -F scope_scrub >/dev/null; then
    scope_scrub "$dir" || return 1
  fi
  rel="${session#"$APP_REPO"/}"
  mkdir -p "$dir/$rel"
  rsync -a --exclude '*.mp4' --exclude '*.jsonl' --exclude 'synthesis*' --exclude 'isolation' "$session/" "$dir/$rel/" || return 1
  echo "$dir"
}

# scoped_claude <model> <budget> <prompt-file> <out.jsonl> <scope-dir> — the
# synthesis agent of a study that must not see the repository. Runs inside the
# snapshot with no settings and no pre-approved tools, so reads outside it are
# refused and no project instructions load. Prints the result text.
scoped_claude() {
  local model="$1" budget="$2" prompt="$3" out="$4" scope="$5" rc
  (
    cd "$scope" &&
      claude_cli -p \
        --output-format stream-json --verbose \
        --tools "Read,Grep,Glob" \
        --strict-mcp-config --setting-sources "" --no-session-persistence \
        --model "$model" --max-budget-usd "$budget" <"$prompt"
  ) >"$out" 2>"$out.stderr"
  rc=$?
  [ -s "$out.stderr" ] || rm -f "$out.stderr"
  result_text "$out"
  return $rc
}

# scope_escapes <transcript.jsonl> <scope-dir> — prints every absolute path the
# agent tried to reach outside the snapshot.
scope_escapes() {
  jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") |
    .input | (.file_path // .path // empty)' "$1" 2>/dev/null |
    grep '^/' | grep -v "^$2" | sort -u
}

# scope_leaks <file> — prints each SCOPE_FORBIDDEN file whose longest line shows
# up in <file>. Compared as letters and digits only: a transcript escapes quotes.
scope_leaks() {
  local f line text
  text="$(LC_ALL=C tr -cd 'a-zA-Z0-9' <"$1")"
  for f in ${SCOPE_FORBIDDEN:-}; do
    line="$(awk 'length > n { n = length; l = $0 } END { print l }' "$APP_REPO/$f" | LC_ALL=C tr -cd 'a-zA-Z0-9')"
    case "$text" in *"$line"*) [ -z "$line" ] || echo "$f" ;; esac
  done
}

# web_claude <model> <budget> <prompt-file> <out.json> — the desk researcher.
# Web tools only, in an empty directory outside the repository: it can look at
# the world, not at the code. Its answer reaches the personas as plain text.
web_claude() {
  local model="$1" budget="$2" prompt="$3" out="$4" sandbox rc
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/persona-web.XXXXXX")"
  (
    cd "$sandbox" &&
      claude_cli -p \
        --output-format json \
        --tools "WebSearch,WebFetch" --allowedTools "WebSearch" "WebFetch" \
        --strict-mcp-config --setting-sources "" --no-session-persistence \
        --model "$model" --max-budget-usd "$budget" <"$prompt"
  ) >"$out" 2>"$out.stderr"
  rc=$?
  rmdir "$sandbox" 2>/dev/null
  [ -s "$out.stderr" ] || rm -f "$out.stderr"
  jq -r '.result // empty' "$out" 2>/dev/null
  return $rc
}

# result_text <transcript.jsonl> — the final answer of a stream-json run.
result_text() { jq -rs '[.[] | select(.type == "result")] | last | .result // empty' "$1" 2>/dev/null; }
# result_cost <transcript.jsonl> — its cost in USD (0 when absent).
result_cost() { jq -rs '[.[] | select(.type == "result")] | last | .total_cost_usd // 0' "$1" 2>/dev/null || echo 0; }

# user_message <text> [image.png] — one stream-json user message on stdout.
user_message() {
  local text="$1" img="${2:-}"
  if [ -n "$img" ]; then
    base64 -i "$img" | tr -d '\n' |
      jq -cRs --arg text "$text" '{type: "user", message: {role: "user", content: [
        {type: "text", text: $text},
        {type: "image", source: {type: "base64", media_type: "image/png", data: .}}]}}'
  else
    jq -cn --arg text "$text" '{type: "user", message: {role: "user", content: [{type: "text", text: $text}]}}'
  fi
}

# extract_json — reads model output on stdin, prints the first top-level JSON
# object in it (models wrap JSON in ``` fences more often than told not to).
extract_json() {
  perl -0777 -ne 'if (/(\{.*\})/s) { print $1 }' | jq -c . 2>/dev/null
}

# add_cost <a> <b>
add_cost() { awk -v a="$1" -v b="$2" 'BEGIN { printf "%.4f", a + b }'; }
