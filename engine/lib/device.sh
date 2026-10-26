# shellcheck shell=bash
#
# Device plumbing for persona-lab — plain adb plus the emulator console
# recorder. No other tooling: taps, swipes, keyevents, screencap, uiautomator.
#
# Source after common.sh and load_config (needs ANDROID_SERIAL, APP_ID,
# SHOT_WIDTH, UI_HINTS, SETTLE_SECONDS).

adbs() { adb -s "$ANDROID_SERIAL" "$@"; }

# device_check — the configured device is connected; sets DEV_W/DEV_H and
# SCALE (device pixels per screenshot pixel).
device_check() {
  adb devices | grep -q "^$ANDROID_SERIAL[[:space:]]*device" ||
    die "device $ANDROID_SERIAL not connected — running: $(adb devices | sed -n '2,$p' | awk '{print $1}' | tr '\n' ' ')"
  local size
  size="$(adbs shell wm size | sed -n 's/.*: \([0-9]*x[0-9]*\).*/\1/p' | tail -1)"
  DEV_W="${size%x*}"
  DEV_H="${size#*x}"
  [ -n "$DEV_W" ] && [ -n "$DEV_H" ] || die "could not read the screen size of $ANDROID_SERIAL"
  SCALE="$(awk -v d="$DEV_W" -v s="$SHOT_WIDTH" 'BEGIN { printf "%.6f", d / s }')"
  SHOT_HEIGHT="$(awk -v h="$DEV_H" -v s="$SCALE" 'BEGIN { printf "%d", h / s + 0.5 }')"
}

is_emulator() { case "$ANDROID_SERIAL" in emulator-*) return 0 ;; *) return 1 ;; esac; }

# --- app lifecycle (generic helpers; the config's reset_app hook uses them) ---

app_stop() { adbs shell am force-stop "$APP_ID"; }
app_clear() { adbs shell pm clear "$APP_ID" >/dev/null; }
app_set_locale() { adbs shell cmd locale set-app-locales "$APP_ID" --locales "$1" >/dev/null; }
app_start() { adbs shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; }

# app_wait_ready [timeout-s] — the app's window has focus and its UI exposes
# some text (i.e. past the launch splash). Never a fixed sleep: a cold start on
# a loaded host can take 20 s.
app_wait_ready() {
  local timeout="${1:-60}" i
  for i in $(seq 1 "$timeout"); do
    if adbs shell dumpsys window | grep -q "mCurrentFocus=.*$APP_ID" &&
      [ -n "$(ui_raw | grep -oE 'text="[^"]+"' | head -1)" ]; then
      sleep 1
      return 0
    fi
    sleep 1
  done
  log "$APP_ID did not become ready within ${timeout}s"
  return 1
}

# --- per-persona device profile ----------------------------------------------

# device_profile_apply <font_scale> <dark:true|false> — remembers the previous
# values so device_profile_restore can put them back.
device_profile_apply() {
  PREV_FONT_SCALE="$(adbs shell settings get system font_scale | tr -d '\r')"
  case "$PREV_FONT_SCALE" in null | "") PREV_FONT_SCALE=1.0 ;; esac
  PREV_NIGHT="$(adbs shell cmd uimode night | sed -n 's/.*: //p' | tr -d '\r')"
  adbs shell settings put system font_scale "${1:-1.0}"
  if [ "${2:-false}" = true ]; then adbs shell cmd uimode night yes >/dev/null; else adbs shell cmd uimode night no >/dev/null; fi
}
device_profile_restore() {
  [ -n "${PREV_FONT_SCALE:-}" ] && adbs shell settings put system font_scale "$PREV_FONT_SCALE"
  case "${PREV_NIGHT:-}" in yes | no) adbs shell cmd uimode night "$PREV_NIGHT" >/dev/null ;; esac
  PREV_FONT_SCALE=""
  PREV_NIGHT=""
}

# --- perception ----------------------------------------------------------------

# shot_take <out.png> — screenshot, downscaled to SHOT_WIDTH (the persona taps
# in these pixels; actions scale back by SCALE).
shot_take() {
  local raw
  raw="$(mktemp "${TMPDIR:-/tmp}/persona-shot.XXXXXX")"
  adbs exec-out screencap -p >"$raw"
  sips --resampleWidth "$SHOT_WIDTH" "$raw" --out "$1" >/dev/null
  rm -f "$raw"
}

# ui_raw — the uiautomator XML. A dump taken mid-transition fails now and then
# ("null root node"), so it gets a second try.
ui_raw() {
  local i
  for i in 1 2; do
    if adbs shell uiautomator dump /sdcard/persona-lab-ui.xml 2>&1 </dev/null | grep -q 'dumped to'; then
      adbs exec-out cat /sdcard/persona-lab-ui.xml </dev/null
      return 0
    fi
    sleep 1
  done
  return 1
}

# ui_hints — what is on screen as text, in screenshot coordinates.
#
# Developer identifiers never reach the persona: resource-id (React Native
# testID), class, package and every other attribute are dropped. Only the
# visible text survives, plus — with UI_HINTS=full — the accessibility label
# (content-desc), which is what a screen-reader user would hear. The default
# (text) leaves content-desc out on purpose: a sighted user cannot read the
# label of an icon-only button, and handing it over would hide exactly the
# "what does this icon do?" problems the test is for.
ui_hints() {
  [ "$UI_HINTS" = none ] && return 0
  ui_raw | perl -CS -Mutf8 -ne '
    BEGIN { $s = shift @ARGV; $mode = shift @ARGV }
    while (/<node\b([^>]*)>/g) {
      my $a = $1;
      my ($t) = $a =~ /\btext="([^"]*)"/;
      my ($d) = $a =~ /\bcontent-desc="([^"]*)"/;
      my ($x1, $y1, $x2, $y2) = $a =~ /\bbounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/;
      next unless defined $x1 && $x2 > $x1 && $y2 > $y1;
      $d = "" unless $mode eq "full";
      # Icon fonts render as private-use glyphs: noise, not visible text.
      for ($t, $d) { s/&quot;/"/g; s/&apos;/\x27/g; s/&lt;/</g; s/&gt;/>/g; s/&amp;/&/g; s/\p{Co}//g; s/\s+/ /g; s/^ | $//g }
      next if $t eq "" && $d eq "";
      my @b = map { int($_ / $s + 0.5) } ($x1, $y1, $x2, $y2);
      my $line = $t ne "" ? "\"$t\"" : "";
      $line .= ($line ne "" ? " " : "") . "(etykieta dostępności: \"$d\")" if $d ne "";
      print "- $line @ [$b[0],$b[1] - $b[2],$b[3]]\n";
    }' "$SCALE" "$UI_HINTS"
}

# --- actions -------------------------------------------------------------------

# to_dev <shot-coordinate> — screenshot pixels → device pixels.
to_dev() { awk -v v="$1" -v s="$SCALE" 'BEGIN { printf "%d", v * s + 0.5 }'; }

# ascii_for_input <text> — `adb shell input text` cannot type non-ASCII. Polish
# letters lose their diacritics, typographic quotes/dashes become ASCII, the
# rest is dropped. The persona is told about this up front, so it does not
# report it as an app problem.
ascii_for_input() {
  printf '%s' "$1" | perl -CSA -Mutf8 -pe '
    tr/ąćęłńóśźżĄĆĘŁŃÓŚŹŻ/acelnoszzACELNOSZZ/;
    s/[„”“″]/"/g; s/[‘’′]/\x27/g; s/[–—]/-/g; s/…/.../g; s/\x{00A0}/ /g;
    s/[^\x0A\x20-\x7E]//g;'
}

# type_text <text> — line by line (Enter between lines), in short chunks;
# spaces as %s, the whole chunk single-quoted for the device shell.
#
# Every adb call here reads </dev/null: `adb shell` otherwise drains stdin,
# which inside this loop is the text itself — everything after the first line
# silently vanished, and a persona gave up over "the app cuts my text off".
# It also types one word per call, with a pause after each, roughly at a fast
# human pace. Injected all at once, a loaded emulator (the recorder runs
# during every persona run) drops characters inside a controlled React Native
# TextInput while the keyboard is composing — "1 kostka masła (miękkiego)"
# arrived as "1 kostka mas". A person typing never hits that race, so the
# persona must not either.
type_text() {
  local text first=1 line word q sep
  text="$(ascii_for_input "$1")"
  while IFS= read -r line || [ -n "$line" ]; do
    if [ $first = 0 ]; then
      sleep 0.5
      adbs shell input keyevent KEYCODE_ENTER </dev/null
      sleep 0.5
    fi
    first=0
    sep=""
    # Split on single spaces by hand (not `for w in $line`) so runs of
    # spaces and glob characters in the text survive untouched.
    while [ -n "$line" ]; do
      case "$line" in
        *" "*) word="${line%%" "*}"; line="${line#*" "}" ;;
        *) word="$line"; line="" ;;
      esac
      q="$(printf '%s%s' "$sep" "$word" | sed -e 's/ /%s/g' -e "s/'/'\\\\''/g")"
      [ -n "$q" ] && adbs shell "input text '$q'" </dev/null
      sep=" "
      sleep 0.3
    done
  done <<EOF
$text
EOF
}

# perform_action <action-json> — executes one persona action. Prints a short
# description of what was done (fed back to the persona and logged).
# Returns 2 for the terminal actions (done/give_up), 1 for an invalid action.
perform_action() {
  local a="$1" type x y x2 y2 dir text
  type="$(jq -r '.type // ""' <<<"$a")"
  case "$type" in
    tap | long_press)
      x="$(jq -r '.x // empty' <<<"$a")"
      y="$(jq -r '.y // empty' <<<"$a")"
      valid_xy "$x" "$y" || { echo "niepoprawne współrzędne ($x, $y) — obraz ma ${SHOT_WIDTH}x${SHOT_HEIGHT} px"; return 1; }
      if [ "$type" = tap ]; then
        adbs shell input tap "$(to_dev "$x")" "$(to_dev "$y")"
        echo "stuknięcie w ($x, $y)"
      else
        adbs shell input swipe "$(to_dev "$x")" "$(to_dev "$y")" "$(to_dev "$x")" "$(to_dev "$y")" 900
        echo "przytrzymanie w ($x, $y)"
      fi
      ;;
    swipe)
      x="$(jq -r '.x1 // empty' <<<"$a")"
      y="$(jq -r '.y1 // empty' <<<"$a")"
      x2="$(jq -r '.x2 // empty' <<<"$a")"
      y2="$(jq -r '.y2 // empty' <<<"$a")"
      valid_xy "$x" "$y" && valid_xy "$x2" "$y2" || { echo "niepoprawne współrzędne przesunięcia"; return 1; }
      adbs shell input swipe "$(to_dev "$x")" "$(to_dev "$y")" "$(to_dev "$x2")" "$(to_dev "$y2")" 400
      echo "przesunięcie palcem z ($x, $y) do ($x2, $y2)"
      ;;
    scroll)
      dir="$(jq -r '.direction // "down"' <<<"$a")"
      local cx=$((DEV_W / 2)) top=$((DEV_H * 30 / 100)) bottom=$((DEV_H * 70 / 100))
      # With the keyboard open, the lower part of the screen IS the keyboard:
      # a swipe there is glide typing and inserts words ("to", "to że to")
      # into the field. Swipe above it, as a person would.
      if adbs shell dumpsys input_method </dev/null | grep -q 'mInputShown=true'; then
        top=$((DEV_H * 15 / 100))
        bottom=$((DEV_H * 50 / 100))
      fi
      if [ "$dir" = up ]; then
        adbs shell input swipe "$cx" "$top" "$cx" "$bottom" 500
      else
        adbs shell input swipe "$cx" "$bottom" "$cx" "$top" 500
      fi
      echo "przewinięcie ($dir)"
      ;;
    type)
      text="$(jq -r '.text // ""' <<<"$a")"
      [ -n "$text" ] || { echo "pusty tekst do wpisania"; return 1; }
      type_text "$text"
      if [ "$(ascii_for_input "$text")" != "$text" ]; then
        echo "wpisano tekst (klawiatura testowa: bez polskich znaków): $(ascii_for_input "$text" | head -c 200)"
      else
        echo "wpisano tekst: $(printf '%s' "$text" | head -c 200)"
      fi
      ;;
    back)
      adbs shell input keyevent KEYCODE_BACK
      echo "systemowe Wstecz"
      ;;
    enter)
      adbs shell input keyevent KEYCODE_ENTER
      echo "Enter na klawiaturze"
      ;;
    wait)
      sleep 3
      echo "odczekanie 3 s"
      ;;
    done | give_up)
      echo "$type"
      return 2
      ;;
    *)
      echo "nieznany typ akcji: '$type'"
      return 1
      ;;
  esac
}

valid_xy() {
  case "$1$2" in *[!0-9]* | "") return 1 ;; esac
  [ "$1" -ge 0 ] && [ "$1" -le "$SHOT_WIDTH" ] && [ "$2" -ge 0 ] && [ "$2" -le "$SHOT_HEIGHT" ]
}

# --- video -----------------------------------------------------------------------
#
# The emulator console recorder (`adb emu screenrecord`), not `adb shell
# screenrecord`: the on-device one captures a single frame on the emulator. The
# console one writes VP9 .webm straight to the host. Start the emulator with
# `-gpu host` or the video drops to a few fps. Real devices get no video.

video_start() {
  is_emulator || { log "not an emulator — no video for this run"; return 0; }
  # 1800 s is the console recorder's maximum; a run longer than that keeps
  # going, the video just ends there.
  local r
  r="$(adbs emu screenrecord start --time-limit 1800 "$1" 2>&1)"
  case "$r" in OK*) ;; *) log "WARNING: video not recording: $r" ;; esac
  sleep 0.8
}
video_stop() {
  is_emulator || return 0
  adbs emu screenrecord stop >/dev/null
  sleep 3 # the muxer keeps writing after the console call returns
}

# video_compact <in.webm> <out.mp4> — the raw take is real time, which is
# mostly the screen standing still while the model thinks. This drops runs of
# identical frames (keeping one per ~second of stillness) so transitions play
# at speed and pauses shrink to a beat.
video_compact() {
  [ -s "$1" ] || return 0
  ffmpeg -v error -y -i "$1" -vf "mpdecimate=max=20,setpts=N/(15*TB),scale=540:-2" -r 15 \
    -c:v libx264 -pix_fmt yuv420p -an "$2" || log "WARNING: could not compact $1"
}
