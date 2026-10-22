# Shared by turn-start.sh and stop-gate.sh. Sourced, never run on its own.
# Callers set: input (the hook's JSON on stdin) and project_dir.

json_field() { # name -> first string value of that field in the hook input
  printf '%s' "$input" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1
}

conf_get() { # file key default -> value, with \r removed and one pair of surrounding quotes removed
  local value
  value="$(sed -n "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*//p" "$1" 2>/dev/null | tail -n 1 | tr -d '\r')"
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

repo_state_dir() { # session repo
  printf '%s/%s/%s' "$(state_base)" "${1:-no-session}" "$(printf '%s' "$2" | git hash-object --stdin)"
}

# Prints the repos to check, one per line: the project, the hook's cwd, and any
# REPOS that the project's config lists. A repo whose own config sets REPOS is a
# host folder and is never checked itself.
gate_repos() {
  local dir top rel conf seen=" "
  {
    for dir in "$project_dir" "$(json_field cwd)"; do
      [ -n "$dir" ] && git -C "$dir" rev-parse --show-toplevel 2>/dev/null
    done
    conf="$project_dir/.claude/workflow-gate.conf"
    if [ -f "$conf" ]; then
      for rel in $(conf_get "$conf" REPOS ""); do
        git -C "$project_dir/$rel" rev-parse --show-toplevel 2>/dev/null
      done
    fi
  } | while IFS= read -r top; do
    case "$seen" in *" $top "*) continue ;; esac
    seen="$seen$top "
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
