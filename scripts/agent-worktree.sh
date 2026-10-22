#!/usr/bin/env bash
# tiered-workflow agent worktrees (docs/workflow-v1.1.0.md, section 2): each parallel
# agent edits its own copy of a repo, so agents cannot see each other's work and the
# Stop gate never checks a half-finished edit.
#   agent-worktree.sh create <repo> <name>   detached worktree at <repo>.agent-<name>, from HEAD
#   agent-worktree.sh collect <repo> <name>  copy its changes into <repo> uncommitted, then remove it
# Nothing is committed. A collect that clashes with changes in <repo> stops and keeps the worktree.
set -u

usage() { echo "usage: agent-worktree.sh create|collect <repo> <name>" >&2; exit 2; }
[ $# -eq 3 ] || usage
action="$1"
repo="$(cd "$2" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" || { echo "not a git repo: $2" >&2; exit 2; }
name="$3"
case "$name" in ''|*[!A-Za-z0-9-]*) echo "the name may hold only letters, digits and dashes: $name" >&2; exit 2 ;; esac
wt="$repo.agent-$name"

case "$action" in
  create)
    [ -e "$wt" ] && { echo "already exists: $wt" >&2; exit 1; }
    git -C "$repo" worktree add -q --detach "$wt" HEAD || exit 1
    git -C "$wt" rev-parse HEAD > "$(git -C "$wt" rev-parse --absolute-git-dir)/tiered-workflow-agent-base"
    dirty="$(git -C "$repo" status --porcelain | wc -l | tr -d ' ')"
    echo "Agent worktree: $wt (from $(git -C "$repo" rev-parse --short HEAD))"
    [ "$dirty" = 0 ] || echo "Note: $dirty uncommitted change(s) in $repo are not in the worktree."
    ;;
  collect)
    [ -d "$wt" ] || { echo "no agent worktree at $wt" >&2; exit 1; }
    # Diff from the commit the worktree started at, so a commit the agent made is still collected.
    base="$(cat "$(git -C "$wt" rev-parse --absolute-git-dir)/tiered-workflow-agent-base" 2>/dev/null)"
    [ -n "$base" ] || base="$(git -C "$wt" rev-parse HEAD)"
    git -C "$wt" add -A
    patch="$(mktemp "${TMPDIR:-/tmp}/agent-worktree.XXXXXX")"
    trap 'rm -f "$patch"' EXIT
    git -C "$wt" diff --cached --binary "$base" > "$patch"
    files="$(git -C "$wt" diff --cached --name-status "$base")"
    if [ -s "$patch" ]; then
      if ! git -C "$repo" apply --check "$patch" 2>/dev/null; then
        echo "The changes in $wt do not apply to $repo (a file changed in both). The worktree is kept; compare and copy by hand:" >&2
        git -C "$repo" apply --check "$patch" >&2
        exit 1
      fi
      git -C "$repo" apply "$patch" || exit 1
    fi
    git -C "$repo" worktree remove --force "$wt" || exit 1
    echo "Collected into $repo, uncommitted:"
    if [ -n "$files" ]; then printf '%s\n' "$files"; else echo "(no changes)"; fi
    ;;
  *) usage ;;
esac
