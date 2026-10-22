#!/usr/bin/env bash
# tiered-workflow turn start (UserPromptSubmit hook).
#
# Records what each gated repo looks like when the user sends a prompt, so the Stop
# gate checks only what changed during the turn, never the user's own work in
# progress. Prints nothing: on this event plain output would become context.
set -u
[ "${CLAUDE_WORKFLOW_GATE:-on}" = "off" ] && exit 0

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
scripts_dir="$(cd "$(dirname "$0")" && pwd)"
. "$scripts_dir/lib.sh"

session="$(json_field session_id)"
max_copies=500

gate_repos | while IFS= read -r repo; do
  state="$(repo_state_dir "$session" "$repo")"
  mkdir -p "$state" || continue
  rm -rf "$state/base"
  dirty="$(dirty_files "$repo")"
  printf '%s\n' "$dirty" | hash_lines "$repo" > "$state/baseline"
  # Keep a copy of each dirty file so the comment check can tell the user's lines
  # from the lines added during the turn.
  if [ -n "$dirty" ] && [ "$(printf '%s\n' "$dirty" | wc -l)" -le "$max_copies" ]; then
    printf '%s\n' "$dirty" | while IFS= read -r f; do
      [ -f "$repo/$f" ] || continue
      mkdir -p "$state/base/$(dirname "$f")" && cp "$repo/$f" "$state/base/$f"
    done
  fi
  echo 0 > "$state/attempts"
  rm -f "$state/last-key" "$state/last-result"
done

# Session state older than a week is no longer needed.
find "$(state_base)" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null
exit 0
