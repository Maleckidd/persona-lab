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

# Phrases that exist only in the repo's code/docs (class names, internal terms).
ISOLATION_SENTINELS=""
