# Shared by turn-start.sh, stop-gate.sh and test-lock.sh. Sourced, never run on its own.
# Callers set: input (the hook's JSON on stdin), and project_dir before using the repo lists.

LOCKED_TESTS_FILE=tiered-workflow-locked-tests
TESTS_UNLOCKED_FILE=tiered-workflow-tests-unlocked

json_field() { # name -> first string value of that field in the hook input
  printf '%s' "$input" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/}"
  s="${s//$'\t'/  }"
  printf '%s' "$s" | LC_ALL=C tr -d '\000-\010\013\014\016-\037'
}

# The key is matched as plain text, never as a pattern: step names come from the
# config itself, before it is trusted.
conf_get() { # file key default -> value, with \r removed and one pair of surrounding quotes removed
  local value
  value="$(KEY="$2" awk '
    { line = $0; sub(/^[ \t]+/, "", line)
      if (substr(line, 1, length(ENVIRON["KEY"])) != ENVIRON["KEY"]) next
      rest = substr(line, length(ENVIRON["KEY"]) + 1); sub(/^[ \t]+/, "", rest)
      if (substr(rest, 1, 1) != "=") next
      rest = substr(rest, 2); sub(/^[ \t]+/, "", rest); value = rest; seen = 1 }
    END { if (seen) printf "%s", value }' "$1" 2>/dev/null | tr -d '\r')"
  case "$value" in
    \"*\") value="${value#\"}"; value="${value%\"}" ;;
  esac
  if [ -n "$value" ]; then printf '%s' "$value"; else printf '%s' "$3"; fi
}

state_base() {
  local base="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/tiered-workflow}"
  printf '%s/stop-gate' "${base%/}"
}

trust_file() {
  printf '%s/tiered-workflow/trusted-gates' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
}

# Trust follows the repo's shared git folder, so one trust covers every worktree of
# it. A separate clone needs its own trust: an origin URL is local config that any
# folder can claim.
trust_id() { # repo
  (cd "$1" && cd "$(git rev-parse --git-common-dir)" && pwd -P)
}

repo_state_dir() { # session repo
  printf '%s/%s/%s' "$(state_base)" "${1:-no-session}" "$(printf '%s' "$2" | git hash-object --stdin)"
}

# Prints every repo the turn can reach, once each: the project, the hook's cwd, and any
# REPOS that the project's config lists (patterns such as tmp/*/app allowed).
candidate_repos() {
  local dir top rel conf seen=" "
  {
    for dir in "$project_dir" "$(json_field cwd)"; do
      [ -n "$dir" ] && git -C "$dir" rev-parse --show-toplevel 2>/dev/null
    done
    conf="$project_dir/.claude/workflow-gate.conf"
    if [ -f "$conf" ]; then
      # Unquoted on purpose: each pattern expands from the project folder.
      (cd "$project_dir" && for rel in $(conf_get "$conf" REPOS ""); do
        [ -d "$rel" ] && git -C "$rel" rev-parse --show-toplevel 2>/dev/null
      done)
    fi
  } | while IFS= read -r top; do
    case "$seen" in *" $top "*) continue ;; esac
    seen="$seen$top "
    printf '%s\n' "$top"
  done
}

# The repos to check: candidate repos with a gate config that is on. A repo whose own
# config sets REPOS is a host folder and is never checked itself.
gate_repos() {
  local top conf
  candidate_repos | while IFS= read -r top; do
    conf="$top/.claude/workflow-gate.conf"
    [ -f "$conf" ] || continue
    [ -n "$(conf_get "$conf" REPOS "")" ] && continue
    [ "$(conf_get "$conf" GATE_ENABLED 1)" = "0" ] && continue
    printf '%s\n' "$top"
  done
}

dirty_files() { # repo -> changed tracked files and untracked files, relative paths
  { git -C "$1" -c core.quotePath=false diff --name-only HEAD 2>/dev/null
    git -C "$1" -c core.quotePath=false ls-files --others --exclude-standard 2>/dev/null
  } | sort -u
}

hash_lines() { # repo, paths on stdin -> "<hash> <path>" per existing file, "deleted <path>" otherwise
  local repo="$1" list existing hashes
  list="$(cat)"
  [ -n "$list" ] || return 0
  existing="$(printf '%s\n' "$list" | while IFS= read -r f; do [ -f "$repo/$f" ] && printf '%s\n' "$f"; done)"
  if [ -n "$existing" ]; then
    hashes="$(printf '%s\n' "$existing" | (cd "$repo" && git hash-object --stdin-paths))"
    paste -d ' ' <(printf '%s\n' "$hashes") <(printf '%s\n' "$existing")
  fi
  printf '%s\n' "$list" | while IFS= read -r f; do [ -f "$repo/$f" ] || printf 'deleted %s\n' "$f"; done
}
