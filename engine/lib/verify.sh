# shellcheck shell=bash
#
# What the engine checks about a run on its own, without taking the persona's
# word for it:
#
#   run_taint           did the rig misbehave (host asleep, a hung call)?
#   check_expectations  the study owner's patterns against the end state
#   judge_outcome       per need: does the end state show it was achieved?
#
# A persona reports what it believes. A person who believes they saved a recipe
# and didn't is the most expensive kind of usability problem, and only a look
# at the app's real end state can find it.
#
# Source after common.sh and load_config.

# run_taint <run-dir> — prints a JSON array of rig incidents in this run.
#
# A turn normally takes seconds. One that took minutes means the host slept or
# a call hung, and what the persona saw right after (a failed request, a blank
# screen) says nothing about the app. Reads steps/timing.tsv; runs recorded
# before it existed fall back to the clock times in actions.log.
#
# Each incident: {kind, at: "shot-NNN", seconds, suspect_steps: [...]}.
#
#   stall        a turn, the setup ("reset") or the part after the last turn
#                ("close": end state, report, judge) took longer than
#                STALL_SECONDS plus what it is allowed. suspect_steps are the
#                turns that started within POST_STALL_SECONDS after it, the
#                stalled one included.
#   slow_typing  a typing turn of at least TYPE_SLOW_MIN_CALLS device calls
#                averaged more than TYPE_CALL_SECONDS a call. A loaded
#                emulator loses letters at that pace: in the session this rule
#                comes from, ten long texts typed at up to 4.6 s a call arrived
#                whole, the one at 5.8 s did not. Only that turn is suspect.
#   after_stall  the run started within POST_STALL_SECONDS of a stall in the
#                run before it (see carried_stall). Every turn is suspect.
run_taint() {
  local dir="$1"
  if [ -s "$dir/steps/timing.tsv" ]; then
    perl -e '
      my ($stall, $post, $slow_min) = splice @ARGV, 0, 3;
      my (@rows, @out, $after);
      while (<>) {
        chomp; my @f = split /\t/;
        if ($f[0] eq "after") { $after = $f[2]; next }
        push @rows, { sid => $f[0], start => $f[1], think => $f[2], act => $f[3], allow => $f[4] // 0, calls => $f[5] // 0 };
      }
      if (defined $after) {
        push @out, sprintf(q({"kind":"after_stall","at":"reset","seconds":%d,"suspect_steps":[%s]}), $after,
          join(",", map { qq("$_->{sid}") } grep { $_->{sid} =~ /^shot-/ } @rows));
      }
      for my $i (0 .. $#rows) {
        my $r = $rows[$i];
        my $over = 0;
        $over = $r->{think} if $r->{think} > $stall;
        $over = $r->{think} + $r->{act} if $r->{act} > $stall + $r->{allow};
        if (!$over) {
          # Enough calls to speak of a rate, and the rate below what the rig keeps.
          push @out, sprintf(q({"kind":"slow_typing","at":"%s","seconds":%d,"suspect_steps":["%s"]}), $r->{sid}, $r->{act}, $r->{sid})
            if $r->{calls} >= $slow_min && $r->{act} > $r->{allow};
          next;
        }
        my $end = $r->{start} + $r->{think} + $r->{act};
        my @sus = ($r->{sid});
        for my $j ($i + 1 .. $#rows) {
          next if $rows[$j]{sid} eq "close";
          push @sus, $rows[$j]{sid} if $rows[$j]{start} <= $end + $post || $j == $i + 1;
        }
        push @out, sprintf(q({"kind":"stall","at":"%s","seconds":%d,"suspect_steps":[%s]}), $r->{sid}, $over, join(",", map { qq("$_") } @sus));
      }
      print "[" . join(",", @out) . "]\n";
    ' "$STALL_SECONDS" "$POST_STALL_SECONDS" "${TYPE_SLOW_MIN_CALLS:-10}" "$dir/steps/timing.tsv"
  elif [ -s "$dir/actions.log" ]; then
    # Legacy: one clock time per turn, taken after the action. The gap between
    # two of them is a whole turn, so the threshold is doubled.
    perl -e '
      my ($stall, $post) = splice @ARGV, 0, 2;
      my (@rows, @out);
      while (<>) { my @f = split /\t/; next unless $f[1] =~ /^(\d+):(\d+):(\d+)$/; push @rows, { sid => $f[0], t => $1 * 3600 + $2 * 60 + $3 } }
      for my $i (1 .. $#rows) {
        my $gap = $rows[$i]{t} - $rows[$i - 1]{t};
        $gap += 86400 if $gap < 0;
        next unless $gap > 2 * $stall;
        my @sus = ($rows[$i]{sid});
        for my $j ($i + 1 .. $#rows) {
          my $d = $rows[$j]{t} - $rows[$i]{t};
          $d += 86400 if $d < 0;
          push @sus, $rows[$j]{sid} if $d <= $post || $j == $i + 1;
        }
        push @out, sprintf(q({"kind":"stall","at":"%s","seconds":%d,"suspect_steps":[%s]}), $rows[$i]{sid}, $gap, join(",", map { qq("$_") } @sus));
      }
      print "[" . join(",", @out) . "]\n";
    ' "$STALL_SECONDS" "$POST_STALL_SECONDS" "$dir/actions.log"
  else
    echo '[]'
  fi
}

# run_last_stall <run-dir> — "<end, epoch seconds><TAB><seconds>" of the last
# stall this run had itself, nothing when it had none. The session hands it to
# the next run.
run_last_stall() {
  [ -s "$1/steps/timing.tsv" ] || return 0
  perl -e '
    my $stall = shift @ARGV;
    my $last;
    while (<>) {
      chomp; my @f = split /\t/;
      next if $f[0] eq "after";
      my ($think, $act, $allow) = ($f[2], $f[3], $f[4] // 0);
      my $over = $think > $stall ? $think : 0;
      $over = $think + $act if $act > $stall + $allow;
      $last = join("\t", $f[1] + $think + $act, $over) if $over;
    }
    print "$last\n" if defined $last;
  ' "$STALL_SECONDS" "$1/steps/timing.tsv"
}

# carried_stall <last stall of the previous run> <start of this run> — the
# "after" row for this run's timing.tsv when it starts within
# POST_STALL_SECONDS of that stall, nothing otherwise.
#
# Inside a run the turns right after a stall are suspect. Across two runs that
# rule found nothing: the setup of the next run takes minutes, so its first
# turn is already outside the window, and a run that began four seconds after
# the host woke from a night's sleep came out clean. Such a run is marked as a
# whole. Whether its failures are artifacts is for the synthesis to weigh
# against the clean runs; the engine only says where the run stood.
carried_stall() {
  local end="${1%%	*}" seconds="${1#*	}"
  [ -n "$1" ] || return 0
  [ $(($2 - end)) -le "$POST_STALL_SECONDS" ] || return 0
  printf 'after\t%s\t%s\n' "$end" "$seconds"
}

# type_calls <text> — how many device calls typing it takes: one per word and
# one per line break, the way type_text sends it. The allowance for a typing
# turn is counted from this.
type_calls() {
  jq -rn --arg t "$1" '$t | split("\n") |
    (map(split(" ") | map(select(. != "")) | length) | add // 0) + ([length - 1, 0] | max)'
}

# state_new_lines <state-before> <state-after> — the lines the session added:
# what is in the second read of the app and was not in the first. Only that is
# the persona's doing; a recipe that was there before the session proves
# nothing about it. With no first read, everything counts.
state_new_lines() {
  if [ -s "$1" ]; then
    diff "$1" "$2" | sed -n 's/^> //p'
  else
    cat "$2"
  fi
}

# check_expectations <persona-json> <state-file> — prints a JSON array, one
# entry per pattern in the persona's "expect". The engine passes the new lines
# of the end state (state_new_lines), so "matches" means "the session put it
# there" and "lacks" means "the session did not leave it behind":
#
#   "expect": [{"need": 1, "label": "the cake is saved", "matches": "piernik"},
#              {"need": 3, "label": "no private notes left", "lacks": "buziaki"}]
#
# Patterns are Perl regular expressions, case-insensitive, matched against the
# end state. "pass" is true, false, or null for a pattern that does not
# compile. The persona never sees "expect".
check_expectations() {
  perl -MJSON::PP -e '
    my ($persona, $file) = @ARGV;
    my $p = JSON::PP->new->utf8->decode($persona);
    open my $fh, "<:encoding(UTF-8)", $file or die "cannot read $file";
    my $text = do { local $/; <$fh> };
    my @out;
    for my $e (@{ $p->{expect} // [] }) {
      for my $kind ("matches", "lacks") {
        next unless defined $e->{$kind};
        my $hit = eval { $text =~ /$e->{$kind}/i ? 1 : 0 };
        my $pass = $@ ? JSON::PP::null
          : (($kind eq "matches") == !!$hit) ? JSON::PP::true : JSON::PP::false;
        push @out, { need => $e->{need}, label => $e->{label} // "", kind => $kind, pattern => $e->{$kind}, pass => $pass };
      }
    }
    print JSON::PP->new->utf8->canonical->encode(\@out), "\n";
  ' "$1" "$2"
}

# judge_outcome <persona-json> <run-dir> <outcome> <outcome-reason> <lang> <system-prompt-out>
#
# One tool-free model call, isolated like a persona: the persona's needs and
# materials, what it claims, and the app's state before and after. Prints
# {"needs": [{need, verdict, claimed, evidence, note}]} or nothing when the call fails.
# The transcript goes to <run-dir>/steps/judge.jsonl.
judge_outcome() {
  local persona="$1" dir="$2" outcome="$3" reason="$4" lang="$5" sys="$6" before="" msg
  T_LANG="$lang" render_template "$(prompt_file judge.md)" >"$sys"
  [ -s "$dir/state-before.md" ] && before="$(head -c "$STATE_MAX_CHARS" "$dir/state-before.md")"
  msg="# The person's needs

$(jq -r '.needs // [] | to_entries | map("\(.key + 1). \(.value)") | join("\n")' <<<"$persona")

# The materials they had

$(jq -r '.materials // "(none)" | if type == "string" then . else tojson end' <<<"$persona")

# What the person claims

Outcome: $outcome. $reason

# The app BEFORE the session

<state-before>
${before:-(not captured)}
</state-before>

# The app AFTER the session (the evidence)

<state-after>
$(head -c "$STATE_MAX_CHARS" "$dir/state.md")
</state-after>

# Lines that are in AFTER and were not in BEFORE (computed, for orientation)

<added>
$(head -c "$STATE_MAX_CHARS" "$dir/state-new.md" 2>/dev/null)
</added>

Reply with one JSON object only."
  user_message "$msg" | isolated_claude "$MODEL_JUDGE" "$sys" "$dir/steps/judge.jsonl" | extract_json
}

# outcome_verdict <expect-json> <judge-json> <outcome> — folds both checks into
# the run's outcome.json (printed).
#
#   verified     met | partly | not_met | unverifiable   (none: nothing was checked)
#   self_report  consistent | overclaimed | underclaimed | unknown
#
# "overclaimed" is the persona leaving with a belief the end state contradicts:
# it stopped with "done", and a need it does not itself call a failure has
# nothing in the app (the judge's "not_met"), or one of the owner's patterns
# for such a need fails.
#
# "done" alone claims nothing: the action means "I am finished, successfully or
# not", and the claim is in the reason given with it. So the judge also says per
# need whether the person believes it was achieved ("claimed"), and a need the
# person reports as failed is not an overclaim however empty the state is. A
# missing "claimed" counts as believed, which errs towards flagging. "partly"
# makes "verified" partly and is never an overclaim by itself: the judge gives
# it for an inference it could not confirm as readily as for a missing step.
outcome_verdict() {
  jq -n --argjson expect "${1:-[]}" --argjson judge "${2:-null}" --arg outcome "$3" '
    ($judge.needs // []) as $needs |
    def believed($n): if ($n | type) == "number" and $n >= 1 then $needs[$n - 1].claimed != false else true end;
    ([$expect[] | select(.pass == false)] | length) as $failed |
    ([$needs[] | select(.verdict == "not_met" and .claimed != false)] | length) as $missing |
    ([$expect[] | select(.pass == false) | select(believed(.need))] | length) as $broken |
    ([$needs[] | select(.verdict == "met")] | length) as $met |
    ([$needs[] | select(.verdict == "partly")] | length) as $partly |
    ([$needs[] | select(.verdict == "not_met")] | length) as $not |
    ([$expect[] | select(.pass == true)] | length) as $passed |
    (if ($needs | length) == 0 and ($expect | length) == 0 then "none"
     elif $met + $partly + $not + $failed + $passed == 0 then "unverifiable"
     elif $not + $partly + $failed == 0 then "met"
     elif $met + $partly + $passed == 0 then "not_met"
     else "partly" end) as $verified |
    {verified: $verified,
     self_report: (if $verified == "none" or $verified == "unverifiable" then "unknown"
       elif $outcome == "done" and $missing + $broken > 0 then "overclaimed"
       elif $outcome != "done" and $verified == "met" then "underclaimed"
       else "consistent" end),
     needs_met: $met, needs_partly: $partly, needs_not_met: $not, needs_contradicted: $missing,
     expect_failed: $failed, expect: $expect, needs: $needs}'
}
