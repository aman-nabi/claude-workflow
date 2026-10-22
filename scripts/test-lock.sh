#!/usr/bin/env bash
# tiered-workflow test lock (docs/workflow-v1.1.0.md, section 4): a PreToolUse hook that
# refuses edits to the acceptance tests listed in <git-dir>/tiered-workflow-locked-tests,
# one repo-relative path per line, so a test is never changed to match the code.
# A file named tiered-workflow-tests-unlocked in the same git dir lifts the lock until
# the Stop gate ends the turn. Edits made through the shell are not seen by this hook.
set -u

input="$(cat)"
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

deny() { # reason
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$(json_escape "$1")"
  exit 0
}

path="$(json_field file_path)"
[ -n "$path" ] || path="$(json_field notebook_path)"
[ -n "$path" ] || exit 0
case "$path" in /*) ;; *) path="$(json_field cwd)/$path" ;; esac

case "$(basename "$path")" in
  "$LOCKED_TESTS_FILE"|"$TESTS_UNLOCKED_FILE")
    deny "$(basename "$path") belongs to the tiered-workflow test lock. Only the user creates the unlock; ask them." ;;
esac

# The file, or even its folder, may not exist yet: resolve the nearest existing folder.
dir="$(dirname "$path")"
rest="$(basename "$path")"
while [ ! -d "$dir" ]; do
  rest="$(basename "$dir")/$rest"
  dir="$(dirname "$dir")"
done
dir="$(cd "$dir" && pwd -P)" || exit 0
top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || exit 0
git_dir="$(git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null)" || exit 0
[ -f "$git_dir/$LOCKED_TESTS_FILE" ] || exit 0
[ -f "$git_dir/$TESTS_UNLOCKED_FILE" ] && exit 0

full="$dir/$rest"
rel="${full#"$top"/}"
tr -d '\r' < "$git_dir/$LOCKED_TESTS_FILE" | grep -q -x -F -- "$rel" || exit 0

deny "$rel is a locked acceptance test (tiered-workflow test lock). Fix the code, not the test. If the test setup is wrong or an expectation looks wrong, stop and ask the user; only the user unlocks it."
