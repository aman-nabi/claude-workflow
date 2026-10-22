#!/usr/bin/env bash
# tiered-workflow Stop gate (docs/workflow-v1.0.0.md, section 2, step 8). Checks the
# files changed during the turn: the repo's lint, typecheck and related tests once
# the user trusts its config, then the comment check. A failure blocks the stop, so
# "done" means the checks passed. Every config key is described in
# templates/workflow-gate.conf; the config is read, never sourced.
set -u
[ "${CLAUDE_WORKFLOW_GATE:-on}" = "off" ] && exit 0

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
scripts_dir="$(cd "$(dirname "$0")" && pwd)"
. "$scripts_dir/lib.sh"

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/}"
  s="${s//$'\t'/  }"
  printf '%s' "$s" | LC_ALL=C tr -d '\000-\010\013\014\016-\037'
}

# Run a command in its own process group; on timeout kill the whole group, so a
# child such as a test runner cannot hold the output pipe open.
run_step() { # repo seconds command -> output on stdout; exit code, 142 on timeout
  (cd "$1" && perl -e '
    my $t = shift @ARGV;
    my $pid = fork();
    die "fork failed\n" unless defined $pid;
    if ($pid == 0) { setpgrp(0, 0); exec @ARGV; exit 127; }
    $SIG{ALRM} = sub { kill "TERM", -$pid; sleep 2; kill "KILL", -$pid; exit 142; };
    alarm $t;
    waitpid($pid, 0);
    exit($? & 127 ? 128 + ($? & 127) : $? >> 8);
  ' "$2" bash -c "$3") 2>&1
}

# The turn's changes as "<hash> <path>" or "deleted <path>" lines: dirty now and not
# in the baseline, changed since it, or deleted since it.
compute_turn() { # repo baseline-file
  local now changed gone
  now="$(dirty_files "$1" | hash_lines "$1")"
  # FILENAME, not NR == FNR: the first file is often empty.
  changed="$(awk 'FILENAME == ARGV[1] { base[$0] = 1; next } !($0 in base)' "$2" <(printf '%s\n' "$now"))"
  gone="$(awk 'FILENAME == ARGV[1] { now[substr($0, index($0, " ") + 1)] = 1; next } $1 != "deleted" { p = substr($0, index($0, " ") + 1); if (!(p in now)) print "deleted " p }' <(printf '%s\n' "$now") "$2")"
  printf '%s\n%s\n' "$changed" "$gone" | sed '/^$/d' | sort -u
}

session="$(json_field session_id)"
trusted_list="$(cat "$(trust_file)" 2>/dev/null)"
tab=$'\t'
failures=""
notes=""

while IFS= read -r repo; do
  [ -n "$repo" ] || continue
  conf="$repo/.claude/workflow-gate.conf"
  state="$(repo_state_dir "$session" "$repo")"
  # No record of the turn's start (the hook did not run): never guess what is the
  # user's own work, so do not check.
  [ -f "$state/baseline" ] || continue

  git_dir="$(git -C "$repo" rev-parse --absolute-git-dir 2>/dev/null)"
  if [ -n "$git_dir" ] && [ -f "$git_dir/tiered-workflow-pause" ]; then
    rm -f "$git_dir/tiered-workflow-pause"
    notes="$notes
Gate paused for this turn in $repo (tiered-workflow-pause); it checks again next turn."
    continue
  fi

  turn="$(compute_turn "$repo" "$state/baseline")"
  if [ -z "$turn" ]; then
    [ "$(cat "$state/last-result" 2>/dev/null)" = "fail" ] && notes="$notes
Checks were still failing in $repo when Claude stopped without further changes."
    continue
  fi
  key="$(printf '%s\n' "$turn" | git hash-object --stdin)"
  if [ "$(cat "$state/last-key" 2>/dev/null)" = "$key" ]; then
    [ "$(cat "$state/last-result" 2>/dev/null)" = "fail" ] && notes="$notes
Checks were still failing in $repo when Claude stopped without further changes."
    continue
  fi

  turn_files="$(printf '%s\n' "$turn" | awk '$1 != "deleted" { print substr($0, index($0, " ") + 1) }')"
  extensions="$(conf_get "$conf" GATE_EXTENSIONS "ts tsx js jsx mjs cjs")"
  files=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    for ext in $extensions; do
      case "$f" in *."$ext") files="$files $(printf '%q' "$repo/$f")"; break ;; esac
    done
  done <<EOF
$turn_files
EOF

  conf_sha="$(git hash-object -- "$conf")"
  trusted=0
  printf '%s\n' "$trusted_list" | grep -q -x -F "$repo$tab$conf_sha" && trusted=1

  timeout="$(conf_get "$conf" STEP_TIMEOUT 300)"
  case "$timeout" in ''|*[!0-9]*|0) timeout=300 ;; esac
  failed=""
  if [ "$trusted" = 1 ]; then
    for step in LINT TYPECHECK TEST; do
      cmd="$(conf_get "$conf" "${step}_CMD" "")"
      [ -n "$cmd" ] || continue
      case "$cmd" in
        *"{files}"*)
          [ -n "$files" ] || continue
          # Split rather than substitute, so quoted paths keep their backslashes.
          cmd="${cmd%%"{files}"*}${files# }${cmd#*"{files}"}"
          ;;
      esac
      output="$(run_step "$repo" "$timeout" "$cmd" </dev/null)"
      code=$?
      [ "$code" -eq 0 ] && continue
      reason="exit $code"
      [ "$code" -eq 142 ] && reason="timed out after ${timeout}s"
      tail_out="$(printf '%s\n' "$output" | sed $'s/\033\\[[0-9;]*[A-Za-z]//g' | tail -n 60)"
      failed="$step failed in $repo ($reason)
Command: $cmd
$tail_out"
      break
    done
  elif [ -n "$(conf_get "$conf" LINT_CMD "")$(conf_get "$conf" TYPECHECK_CMD "")$(conf_get "$conf" TEST_CMD "")" ]; then
    notes="$notes
Gate commands in $repo are not trusted yet, so lint, typecheck and tests were skipped. Run /tiered-workflow:gate-trust to review and trust them."
  fi

  if [ -z "$failed" ] && [ "$(conf_get "$conf" COMMENT_CHECK 1)" != "0" ]; then
    rel_files=()
    while IFS= read -r f; do [ -n "$f" ] && rel_files+=("$f"); done <<EOF
$turn_files
EOF
    found="$(bash "$scripts_dir/comment-check.sh" "$repo" "$(conf_get "$conf" COMMENT_MAX_LINES 8)" "$(conf_get "$conf" COMMENT_BANNERS 1)" "$state/base" ${rel_files[@]+"${rel_files[@]}"} </dev/null)"
    [ -n "$found" ] && failed="COMMENTS failed in $repo: comments added this turn break the comment rules.
Keep a comment only for a why the code cannot show. Describe the code as it is now. History goes in the commit message. Add 'comment-check: allow' to a comment only when it truly must stay.
$found"
  fi

  # Key the result on the repo as it is after the checks, so files the checks write
  # (coverage, snapshots) do not trigger another run.
  printf '%s\n' "$(compute_turn "$repo" "$state/baseline")" | git hash-object --stdin > "$state/last-key"
  if [ -z "$failed" ]; then
    echo pass > "$state/last-result"
    continue
  fi
  echo fail > "$state/last-result"
  attempts=$(( $(cat "$state/attempts" 2>/dev/null || echo 0) + 1 ))
  echo "$attempts" > "$state/attempts"
  max="$(conf_get "$conf" MAX_ATTEMPTS 3)"
  case "$max" in ''|*[!0-9]*) max=3 ;; esac
  if [ "$attempts" -gt "$max" ]; then
    notes="$notes
Checks still failing in $repo after $max attempts this turn. Stopping so you can look."
  else
    failures="$failures

$failed
Files changed this turn: $(printf '%s\n' "$turn_files" | tr '\n' ' ')
If the failure is outside these files and was there before the turn, say so and stop; never change the user's own work to make a check pass."
  fi
done <<EOF
$(gate_repos)
EOF

if [ -n "$failures" ]; then
  reason="tiered-workflow gate: the checks failed, so the work is not done yet. Fix the cause, not the test expectations, then finish.${failures}"
  reason="${reason:0:8000}"
  printf '{"decision":"block","reason":"%s"}\n' "$(json_escape "$reason")"
  exit 0
fi
if [ -n "$notes" ]; then
  printf '{"systemMessage":"%s"}\n' "$(json_escape "tiered-workflow gate:${notes}")"
fi
exit 0
