#!/usr/bin/env bash
# tiered-workflow gate trust. The Stop gate runs a repo's commands only after the
# user has trusted that repo's .claude/workflow-gate.conf. Trust is recorded per git
# folder and config content, so it covers every worktree of the repo and any change
# to the config needs trusting again.
#
# Usage: gate-trust.sh --show <repo>        print what trusting would allow, change nothing
#        gate-trust.sh <repo> <config-id>   trust that config; refused if it changed since --show
#        gate-trust.sh --revoke <repo>      remove the repo's trust record
#        gate-trust.sh --list               show the trusted repos
set -u
scripts_dir="$(cd "$(dirname "$0")" && pwd)"
input=""
project_dir="$PWD"
. "$scripts_dir/lib.sh"

file="$(trust_file)"
mkdir -p "$(dirname "$file")"
touch "$file"

case "${1:-}" in
  --list)
    cat "$file"
    exit 0
    ;;
  --revoke)
    top="$(git -C "${2:?repo path}" rev-parse --show-toplevel)" || exit 1
    id="$(trust_id "$top")"
    awk -F '\t' -v t="$id" '$1 != t' "$file" > "$file.tmp"; mv "$file.tmp" "$file"
    echo "Revoked: $id"
    exit 0
    ;;
esac

show=0
if [ "${1:-}" = "--show" ]; then show=1; shift; fi
top="$(git -C "${1:?repo path}" rev-parse --show-toplevel)" || exit 1
conf="$top/.claude/workflow-gate.conf"
[ -f "$conf" ] || { echo "No config at $conf" >&2; exit 1; }
sha="$(git hash-object -- "$conf")"
id="$(trust_id "$top")"

if [ "$show" = 1 ]; then
  echo "Config: $conf"
  echo "Config id: $sha"
  echo "Trust covers every worktree of: $id"
  echo "The Stop gate would run, in this order:"
  for step in $(conf_get "$conf" STEPS "LINT TYPECHECK TEST"); do
    printf '  %s_CMD: %s\n' "$step" "$(conf_get "$conf" "${step}_CMD" "(none)")"
  done
  exit 0
fi

if [ "${2:-}" != "$sha" ]; then
  echo "Not trusted: the config id does not match. Run --show again and review what it prints." >&2
  exit 1
fi
awk -F '\t' -v t="$id" '$1 != t' "$file" > "$file.tmp"; mv "$file.tmp" "$file"
printf '%s\t%s\n' "$id" "$sha" >> "$file"
echo "Trusted: $id"
