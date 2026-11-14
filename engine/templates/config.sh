# shellcheck shell=bash
# persona-lab config for <APP>. Sourced by the engine with CONFIG_DIR set to
# this directory. Copy engine/templates/ to <your-repo>/persona-lab/config/.

APP_NAME="<App name>"
APP_ID=<com.example.app>
APP_REPO="$(cd "$CONFIG_DIR/../.." && pwd)"   # the repository the synthesis reads
ANDROID_SERIAL="${ANDROID_SERIAL:-emulator-5554}"

BUILD_CMD="${BUILD_CMD:-}"   # optional, run in APP_REPO before the session
APK="${APK:-}"               # optional, installed with adb install -r

APP_LANGUAGES="en"           # personas' languages; app UI set via per-app locale

STATES="fresh"
STATE_DESC_fresh="first launch right after installing; no data of their own yet"
STATE_PERSONA_fresh="You have just installed the app from the store and are opening it for the first time."

# reset_app <state> <lang> — known state, app launched. Engine helpers:
# app_stop, app_clear, app_set_locale <bcp47>, app_start, adbs <adb args…>.
reset_app() {
  case "$1" in
    fresh) app_stop; app_clear; app_set_locale "$2"; app_start ;;
    *) return 1 ;;
  esac
}

# Optional: state_ready <state> <lang> — runs after the last cold restart, right
# before the persona starts. For what a restart would lose: a share intent
# (adbs shell am start …), or clipboard_set <file> followed by app_start.
# gallery_add <image> adds a photo the persona "already has"; gallery_clear
# removes the ones earlier studies left.

# Optional, and worth the effort: capture_state <before|after> <state> <lang> —
# prints, as plain text or Markdown, what is stored in the app right now. With
# it the engine stops taking the persona's "done" on trust: it reads the app
# after the reset and again after the run, and a judge decides per need whether
# the difference shows it achieved (summary.json: verified, self_report).
# Rules for the hook:
#   - read persisted state only: restart the app first (app_stop, then a deep
#     link or app_start), so an unsaved form does not count;
#   - never tap a control that changes data;
#   - print the same thing for the same state both times — the engine takes
#     the lines added by the second read as "what the persona did". ui_collect
#     drops a line a later screen repeats, so on a list whose rows share texts
#     (a duration, a count) read the rows' labels with ui_nodes instead;
#   - cover every place a need can end up in. What the hook does not visit the
#     judge sees as missing, and a persona that put something there gets
#     flagged as wrong about it.
# Helpers (device pixels, hooks only — never shown to a persona):
#   ui_texts            visible texts, top to bottom
#   ui_collect [n]      the same, scrolling down up to n times
#   ui_nodes            clickable, x1, y1, x2, y2, text, label (tab-separated)
#   tap_dev <x> <y>
#   keyboard_hide       closes the keyboard if it is up; call it before a tap or
#                       a swipe on a screen whose field takes focus by itself
#
# capture_state() {
#   app_stop
#   adbs shell am start -W -a android.intent.action.VIEW -d "myapp://items" "$APP_ID" >/dev/null 2>&1 </dev/null
#   app_wait_ready 60 || return 1
#   printf '# Items\n\n'
#   ui_collect 4
# }
JUDGE_OUTCOME=1              # 0: no judge call; "expect" patterns are still checked

# Hand-written personas (--personas-file) may add two fields a persona never sees:
#   "expect": [{"need": 1, "label": "the note is saved", "matches": "regex"},
#              {"need": 2, "label": "no junk left behind", "lacks": "regex"}]
#       checked by the engine against what the session added to the end state
#   "avoids": ["long_press", "swipe"]
#       gestures this person never makes; the engine refuses them

PERSONA_COUNT=5
RUNS_PER_PERSONA=2
MAX_STEPS=40
MODEL_PERSONA=sonnet
MODEL_GENERATOR=opus
MODEL_SYNTHESIS=opus
MAX_BUDGET_PER_CALL=1.00
MAX_BUDGET_SYNTHESIS=5.00
UI_HINTS=text                # none | text | full
SYNTHESIS_LANG=en
SYNTHESIS_FOCUS=""           # extra instruction for a study aimed at one feature
STALL_SECONDS=180            # a turn slower than this is a rig incident (host asleep, hung call)

# Phrases that exist only in the repo's code/docs (class names, internal terms).
ISOLATION_SENTINELS=""
