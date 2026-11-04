# shellcheck shell=bash
#
# Post-processing of a persona run: the evidence check on the report and the
# step-by-step think-aloud log.

# check_citations <report.raw.md> <shots-dir> <last-step>
#
# Every bullet under the EVIDENCE_SECTIONS headings ("Problemy" and "Życzenia i
# inspiracje" by default) must cite at least one screenshot that exists, as
# [shot-NNN]. Bullets that do not are moved to a final "Odrzucone" section —
# kept visible, never counted. Valid citations become links to the image.
check_citations() {
  perl -e '
    my ($file, $shots, $last, $sections) = @ARGV;
    open my $fh, "<", $file or die; my @lines = <$fh>; close $fh;
    my (@out, @rejected, $section, @bullet);
    my $flush = sub {
      return unless @bullet;
      my $text = join "", @bullet; @bullet = ();
      if ($section) {
        my @cites = $text =~ /\[shot-(\d{3})\]/g;
        my @ok = grep { $_ >= 1 && $_ <= $last && -f "$shots/shot-$_.png" } @cites;
        unless (@ok) { push @rejected, $text; return }
      }
      push @out, $text;
    };
    for my $l (@lines) {
      if ($l =~ /^#/) {
        $flush->();
        $section = ($l =~ /^##\s*($sections)/i) ? 1 : 0;
        push @out, $l; next;
      }
      if ($l =~ /^\s*[-*]\s+/) { $flush->(); push @bullet, $l; next }
      if (@bullet && $l =~ /^\s+\S/) { push @bullet, $l; next }
      $flush->(); push @out, $l;
    }
    $flush->();
    my $md = join "", @out;
    if (@rejected) {
      $md =~ s/\s*$/\n\n/;
      $md .= "## Odrzucone (brak dowodu na screenshocie)\n\n" . join("", @rejected);
    }
    $md =~ s{\[shot-(\d{3})\](?!\()}{-f "$shots/shot-$1.png" ? "[shot-$1](shots/shot-$1.png)" : "[shot-$1]"}ge;
    print $md;
  ' "$1" "$2" "$3" "$EVIDENCE_SECTIONS"
}

# render_think_aloud <run-dir> <title> — the per-step log, one section per
# turn, each pinned to the screenshot it was decided on.
render_think_aloud() {
  local dir="$1" title="$2" f sid
  printf '# Think-aloud — %s\n\n' "$title"
  printf '_Każdy krok: zrzut ekranu, który persona widziała → jej notatki → akcja wykonana przez silnik._\n\n'
  for f in "$dir"/steps/shot-*.json; do
    [ -f "$f" ] || continue
    sid="$(basename "$f" .json)"
    jq -r --arg sid "$sid" '
      "## \($sid)\n\n" +
      "![\($sid)](shots/\($sid).png)\n\n" +
      "- **Co widzę:** \(.see // "")\n" +
      "- **Czego oczekuję:** \(.expect // "")\n" +
      "- **Co robię:** \(.do // "")\n" +
      (if (.surprise // "") != "" then "- **Co mnie zaskoczyło:** \(.surprise)\n" else "" end) +
      "- **Potrzeba:** \(.need // "")\n" +
      "- **Akcja:** `\(.action | tojson)` → \(.performed // "")\n"' "$f"
    printf '\n'
  done
  if grep -q 'INVALID' "$dir/actions.log" 2>/dev/null; then
    printf '## Odpowiedzi odrzucone przez silnik\n\n'
    grep 'INVALID' "$dir/actions.log" | sed 's/^/    /'
  fi
}
