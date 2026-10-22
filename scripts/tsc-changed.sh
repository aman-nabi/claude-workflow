#!/usr/bin/env bash
# tiered-workflow typecheck helper: runs the project's tsc in the current folder and
# fails only on errors in the given files, so errors that already exist elsewhere do
# not block the turn. Errors the change causes in other files are not caught here;
# the full typecheck at review catches them. Fails too when tsc cannot run, when its
# output cannot be read, and when it checked no file in this folder.
# Usage, from a gate command: "$TIERED_WORKFLOW_SCRIPTS/tsc-changed.sh" [tsc args] -- {files}
set -u

args=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do args+=("$1"); shift; done
if [ "${1:-}" != "--" ]; then
  echo 'usage: tsc-changed.sh [tsc args] -- <files>' >&2
  exit 2
fi
shift
[ $# -gt 0 ] || exit 0

files=""
for f in "$@"; do
  dir="$(cd "$(dirname "$f")" 2>/dev/null && pwd -P)" || continue
  files="$files$dir/$(basename "$f")
"
done

out="$(npx --no-install tsc ${args[@]+"${args[@]}"} --noEmit --pretty false --listFiles 2>&1)"
status=$?

if [ "$status" -ne 0 ] && ! printf '%s\n' "$out" | grep -q 'error TS[0-9]'; then
  printf 'tsc did not run:\n%s\n' "$(printf '%s\n' "$out" | tail -n 20)"
  exit 1
fi

# The file list goes through the environment: awk -v rejects values with newlines.
printf '%s\n' "$out" | TSC_CHANGED_FILES="$files" awk -v here="$(pwd -P)" '
  function norm(p,   n, parts, i, depth, stack, out) {
    if (p !~ /^\//) p = here "/" p
    n = split(p, parts, "/"); depth = 0
    for (i = 1; i <= n; i++) {
      if (parts[i] == "" || parts[i] == ".") continue
      if (parts[i] == "..") { if (depth > 0) depth--; continue }
      stack[++depth] = parts[i]
    }
    out = ""
    for (i = 1; i <= depth; i++) out = out "/" stack[i]
    return out
  }
  BEGIN {
    n = split(ENVIRON["TSC_CHANGED_FILES"], list, "\n")
    for (i = 1; i <= n; i++) if (list[i] != "") want[list[i]] = 1
  }
  /^[^ \t].*error TS[0-9]/ { total++ }
  /^[^ \t].*\([0-9]+,[0-9]+\): error TS[0-9]/ {
    read++
    path = $0; sub(/\([0-9]+,[0-9]+\): error TS.*/, "", path)
    keep = (norm(path) in want)
    if (keep) { print; found++ }
    next
  }
  /^error TS[0-9]/ { read++; print; found++; keep = 0; next }
  /^[ \t]/ { if (keep) print; next }
  /^\// { keep = 0; if (index($0, here "/") == 1 && $0 !~ /\/node_modules\//) own++; next }
  { keep = 0 }
  END {
    if (found > 0) exit 1
    if (total > read) { print "tsc-changed: could not read the tsc output; take --pretty and other output flags out of the command."; exit 1 }
    if (own == 0) { print "tsc-changed: tsc checked no file in " here ". Point -p at a tsconfig that includes the source files; a solution-style tsconfig checks nothing."; exit 1 }
    exit 0
  }
'
