#!/usr/bin/env bash
# tiered-workflow gate trust. The Stop gate runs a repo's lint, typecheck and test
# commands only after the user has trusted that repo's .claude/workflow-gate.conf.
# Trust is recorded per repo path and config content, so any change to the config
# needs trusting again.
#
# Usage: gate-trust.sh <repo>            trust the repo's current config
#        gate-trust.sh --revoke <repo>   remove every trust record for the repo
#        gate-trust.sh --list            show the trusted repos
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
    awk -F '\t' -v t="$top" '$1 != t' "$file" > "$file.tmp"; mv "$file.tmp" "$file"
    echo "Revoked: $top"
    exit 0
    ;;
esac

top="$(git -C "${1:?repo path}" rev-parse --show-toplevel)" || exit 1
conf="$top/.claude/workflow-gate.conf"
[ -f "$conf" ] || { echo "No config at $conf" >&2; exit 1; }
sha="$(git hash-object -- "$conf")"
awk -F '\t' -v t="$top" '$1 != t' "$file" > "$file.tmp"; mv "$file.tmp" "$file"
printf '%s\t%s\n' "$top" "$sha" >> "$file"
echo "Trusted: $top"
for key in LINT_CMD TYPECHECK_CMD TEST_CMD; do
  printf '  %s: %s\n' "$key" "$(conf_get "$conf" "$key" "(none)")"
done
