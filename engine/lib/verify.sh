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
# Each incident: {kind: "stall", at: "shot-NNN", seconds, suspect_steps: [...]}
# where suspect_steps are the turns that started within POST_STALL_SECONDS
# after it, the stalled one included.
run_taint() {
  local dir="$1"
  if [ -s "$dir/steps/timing.tsv" ]; then
    perl -e '
      my ($stall, $post) = splice @ARGV, 0, 2;
      my (@rows, @out);
      while (<>) { chomp; my @f = split /\t/; push @rows, { sid => $f[0], start => $f[1], think => $f[2], act => $f[3], allow => $f[4] // 0 } }
      for my $i (0 .. $#rows) {
        my $r = $rows[$i];
        my $over = 0;
        $over = $r->{think} if $r->{think} > $stall;
        $over = $r->{think} + $r->{act} if $r->{act} > $stall + $r->{allow};
        next unless $over;
        my $end = $r->{start} + $r->{think} + $r->{act};
        my @sus = ($r->{sid});
        for my $j ($i + 1 .. $#rows) { push @sus, $rows[$j]{sid} if $rows[$j]{start} <= $end + $post || $j == $i + 1 }
        push @out, sprintf(q({"kind":"stall","at":"%s","seconds":%d,"suspect_steps":[%s]}), $r->{sid}, $over, join(",", map { qq("$_") } @sus));
      }
      print "[" . join(",", @out) . "]\n";
    ' "$STALL_SECONDS" "$POST_STALL_SECONDS" "$dir/steps/timing.tsv"
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
# {"needs": [{need, verdict, evidence, note}]} or nothing when the call fails.
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
# "overclaimed" is the persona saying it is done while the end state disagrees.
outcome_verdict() {
  jq -n --argjson expect "${1:-[]}" --argjson judge "${2:-null}" --arg outcome "$3" '
    ($judge.needs // []) as $needs |
    ([$expect[] | select(.pass == false)] | length) as $failed |
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
       elif $outcome == "done" and $verified != "met" then "overclaimed"
       elif $outcome != "done" and $verified == "met" then "underclaimed"
       else "consistent" end),
     needs_met: $met, needs_partly: $partly, needs_not_met: $not,
     expect_failed: $failed, expect: $expect, needs: $needs}'
}
