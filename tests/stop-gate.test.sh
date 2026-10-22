#!/usr/bin/env bash
# Tests for scripts/turn-start.sh, stop-gate.sh, comment-check.sh, gate-trust.sh,
# test-lock.sh and agent-worktree.sh. Run: bash tests/stop-gate.test.sh [path-to-bash]
# Each case builds throwaway git repos in a temp folder, feeds the hooks their JSON
# input, and checks the gate's stdout.
set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
gate="$here/scripts/stop-gate.sh"
start="$here/scripts/turn-start.sh"
trust_script="$here/scripts/gate-trust.sh"
shell="${1:-bash}"
work="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/stop-gate-test.XXXXXX")" && pwd -P)"
trap 'rm -rf "$work"' EXIT
export CLAUDE_PLUGIN_DATA="$work/data"
export CLAUDE_CONFIG_DIR="$work/config"
unset CLAUDE_WORKFLOW_GATE

pass=0
fail=0
ok() { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL %s\n     %s\n' "$1" "$2"; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "out=$out"; fi; }

new_repo() { # dir
  mkdir -p "$1/.claude"
  git -C "$1" init -q
  git -C "$1" config user.email test@example.test
  git -C "$1" config user.name test
  printf 'clean\n' > "$1/app.ts"
  # check.sh fails when any file it is given contains BUG, and reports its arguments.
  cat > "$1/check.sh" <<'SH'
#!/usr/bin/env bash
echo "args=$#"
for f in "$@"; do echo "file=[$f]"; done
found=0
for f in "$@"; do [ -f "$f" ] && grep -q BUG "$f" && found=1; done
if [ "$found" = 1 ]; then echo 'expected "clean" but got \"BUG\" \ end'; printf '\033[31mred text\033[0m\n'; exit 1; fi
exit 0
SH
  chmod +x "$1/check.sh"
  git -C "$1" add -A
  git -C "$1" commit -q -m init
}
trust() { # dir -> trusts the config as it is now
  bash "$trust_script" "$1" "$(git hash-object -- "$1/.claude/workflow-gate.conf")" >/dev/null
}
set_conf() { # dir text -> writes, commits and trusts the config
  printf '%s\n' "$2" > "$1/.claude/workflow-gate.conf"
  git -C "$1" add -A; git -C "$1" commit -q -m conf
  trust "$1"
}
hook_input() { printf '{"session_id":"%s","cwd":"%s","hook_event_name":"%s","stop_hook_active":%s}' "$1" "$2" "$3" "$4"; }
start_turn() { # project session [cwd]
  hook_input "$2" "${3:-$1}" UserPromptSubmit false | CLAUDE_PROJECT_DIR="$1" "$shell" "$start"
}
run_gate() { # project session active [cwd] -> sets out, code
  out="$(hook_input "$2" "${4:-$1}" Stop "$3" | CLAUDE_PROJECT_DIR="$1" "$shell" "$gate")"
  code=$?
}
valid_json() { printf '%s' "$1" | /usr/bin/env python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; }

# 1. No config: silent.
r="$work/r1"; new_repo "$r"; start_turn "$r" s1; printf 'BUG\n' > "$r/app.ts"; run_gate "$r" s1 false
check "no config is silent" '[ "$code" = 0 ] && [ -z "$out" ]'

# 2. No changes in the turn: silent.
r="$work/r2"; new_repo "$r"; set_conf "$r" 'TEST_CMD=./check.sh {files}'; start_turn "$r" s2; run_gate "$r" s2 false
check "no changes is silent" '[ "$code" = 0 ] && [ -z "$out" ]'

# 3. A clean change passes, and the same content is not checked twice.
r="$work/r3"; new_repo "$r"; set_conf "$r" "TEST_CMD=./check.sh {files}; date >> $work/runs3.log"
start_turn "$r" s3; printf 'clean change\n' > "$r/app.ts"
run_gate "$r" s3 false; first="$code|$out"; run_gate "$r" s3 false
runs="$(wc -l < "$work/runs3.log" | tr -d ' ')"
check "clean change passes once" '[ "$first" = "0|" ] && [ -z "$out" ] && [ "$runs" = 1 ]'

# 4. A failing test blocks with valid JSON naming the step, the output and the turn's files.
r="$work/r4"; new_repo "$r"; set_conf "$r" 'TEST_CMD=./check.sh {files}'
start_turn "$r" s4; printf 'BUG one\n' > "$r/app.ts"; run_gate "$r" s4 false
check "failure blocks with valid JSON" 'case "$out" in *"\"decision\":\"block\""*"TEST failed"*"expected"*"Files changed this turn: app.ts"*) valid_json "$out" ;; *) false ;; esac'
check "ANSI codes are stripped" 'case "$out" in *$'"'"'\033'"'"'*) false ;; *) true ;; esac'

# 5. Claude stops again without changing anything: no block, but the user is told.
run_gate "$r" s4 true
check "unchanged after a block tells the user and does not block" 'case "$out" in *"systemMessage"*"still failing"*) valid_json "$out" ;; *) false ;; esac'

# 6. Attempt cap per user turn; the next prompt resets it.
r="$work/r6"; new_repo "$r"; set_conf "$r" "$(printf 'TEST_CMD=./check.sh {files}\nMAX_ATTEMPTS=2')"
start_turn "$r" s6
printf 'BUG 1\n' > "$r/app.ts"; run_gate "$r" s6 false; a1="$out"
printf 'BUG 2\n' > "$r/app.ts"; run_gate "$r" s6 true; a2="$out"
printf 'BUG 3\n' > "$r/app.ts"; run_gate "$r" s6 true; a3="$out"
start_turn "$r" s6; printf 'BUG 4\n' > "$r/app.ts"; run_gate "$r" s6 false; a4="$out"
out="$a1|$a2|$a3|$a4"
check "attempt cap, and a new prompt resets it" 'case "$out" in *"\"decision\":\"block\""*"|"*"\"decision\":\"block\""*"|"*"after 2 attempts"*"|"*"\"decision\":\"block\""*) true ;; *) false ;; esac'

# 7. Paths with spaces are one argument each; untracked files count.
r="$work/r 7 with space"; new_repo "$r"; set_conf "$r" 'TEST_CMD=./check.sh {files}'
start_turn "$r" s7; mkdir -p "$r/src dir"; printf 'BUG new\n' > "$r/src dir/new file.ts"; run_gate "$r" s7 false
check "spaced path is one argument, untracked file counted" 'case "$out" in *"args=1"*"file=[$r/src dir/new file.ts]"*) true ;; *) false ;; esac'

# 8. A timeout kills the whole process group, including children holding the output pipe.
r="$work/r8"; new_repo "$r"; set_conf "$r" "$(printf 'STEP_TIMEOUT=1\nTEST_CMD=sleep 30 & wait')"
start_turn "$r" s8; printf 'clean slow\n' > "$r/app.ts"
t0=$(date +%s); run_gate "$r" s8 false; took=$(( $(date +%s) - t0 ))
check "timeout kills children too" 'case "$out" in *"timed out after 1s"*) [ "$took" -lt 10 ] ;; *) false ;; esac'

# 9. Only non-matching files changed: {files} steps are skipped, other steps run.
r="$work/r9"; new_repo "$r"; set_conf "$r" "$(printf 'LINT_CMD=exit 1 {files}\nTYPECHECK_CMD=date >> %s' "$work/tc9.log")"
start_turn "$r" s9; printf 'notes\n' > "$r/README.md"; run_gate "$r" s9 false
check "file-scoped step skipped, plain step runs" '[ -z "$out" ] && [ -f "$work/tc9.log" ]'

# 10. A host folder lists its repos; a host that is itself a git repo is not checked.
p="$work/host"; mkdir -p "$p/.claude"; printf 'REPOS=a b\n' > "$p/.claude/workflow-gate.conf"
new_repo "$p/a"; new_repo "$p/b"; set_conf "$p/a" 'TEST_CMD=./check.sh {files}'; set_conf "$p/b" 'TEST_CMD=./check.sh {files}'
start_turn "$p" s10; printf 'BUG in b\n' > "$p/b/app.ts"; run_gate "$p" s10 false
check "REPOS are checked from a host folder" 'case "$out" in *"TEST failed in $p/b"*) true ;; *) false ;; esac'
h="$work/hostrepo"; new_repo "$h"; printf 'REPOS=sub\n// previously we did this\n' > "$h/.claude/workflow-gate.conf"
git -C "$h" add -A; git -C "$h" commit -q -m host
start_turn "$h" s10b; printf '// previously we did it by hand\n' > "$h/host.ts"; run_gate "$h" s10b false
check "a host that is a git repo is not checked itself" '[ -z "$out" ]'

# 11. Off switches.
r="$work/r11"; new_repo "$r"; set_conf "$r" "$(printf 'GATE_ENABLED=0\nTEST_CMD=./check.sh {files}')"
start_turn "$r" s11; printf 'BUG\n' > "$r/app.ts"; run_gate "$r" s11 false
check "GATE_ENABLED=0 turns it off" '[ -z "$out" ]'
r="$work/r11b"; new_repo "$r"; set_conf "$r" 'TEST_CMD=./check.sh {files}'
start_turn "$r" s11b; printf 'BUG\n' > "$r/app.ts"
out="$(hook_input s11b "$r" Stop false | CLAUDE_WORKFLOW_GATE=off CLAUDE_PROJECT_DIR="$r" "$shell" "$gate")"
check "CLAUDE_WORKFLOW_GATE=off turns it off" '[ -z "$out" ]'

# 12. The user's own work in progress is never checked.
r="$work/r12"; new_repo "$r"; set_conf "$r" 'TEST_CMD=./check.sh {files}'
printf 'BUG user work\n' > "$r/user.ts"; printf 'BUG edited\n' > "$r/app.ts"
start_turn "$r" s12; printf 'clean claude\n' > "$r/claude.ts"; run_gate "$r" s12 false
check "files dirty before the prompt are not checked" '[ -z "$out" ]'
r="$work/r12b"; new_repo "$r"; set_conf "$r" 'TEST_CMD=./check.sh {files}'
printf 'BUG\n' > "$r/app.ts"; run_gate "$r" s12b false
check "with no turn-start record the gate does not guess" '[ -z "$out" ]'

# 13. Commands run only after the user trusts the config, and again after it changes.
r="$work/r13"; new_repo "$r"; printf 'TEST_CMD=./check.sh {files}\n' > "$r/.claude/workflow-gate.conf"; git -C "$r" add -A; git -C "$r" commit -q -m conf
start_turn "$r" s13; printf 'BUG\n' > "$r/app.ts"; run_gate "$r" s13 false
check "untrusted commands are skipped and the user is told" 'case "$out" in *"systemMessage"*"not trusted"*) valid_json "$out" ;; *) false ;; esac'
trust "$r"
start_turn "$r" s13; printf 'BUG again\n' > "$r/app.ts"; run_gate "$r" s13 false
check "trusted commands run" 'case "$out" in *"\"decision\":\"block\""*) true ;; *) false ;; esac'
printf 'TEST_CMD=./check.sh {files}\nSTEP_TIMEOUT=60\n' > "$r/.claude/workflow-gate.conf"
start_turn "$r" s13; printf 'BUG third\n' > "$r/app.ts"; run_gate "$r" s13 false
check "a changed config needs trusting again" 'case "$out" in *"not trusted"*) true ;; *) false ;; esac'

# 14. The pause marker skips one turn and is removed.
r="$work/r14"; new_repo "$r"; set_conf "$r" 'TEST_CMD=./check.sh {files}'
start_turn "$r" s14; printf 'BUG red on purpose\n' > "$r/app.ts"
touch "$(git -C "$r" rev-parse --absolute-git-dir)/tiered-workflow-pause"; run_gate "$r" s14 false
check "pause marker skips the turn and tells the user" 'case "$out" in *"systemMessage"*"paused"*) [ ! -f "$(git -C "$r" rev-parse --absolute-git-dir)/tiered-workflow-pause" ] ;; *) false ;; esac'
start_turn "$r" s14; printf 'BUG next turn\n' > "$r/app.ts"; run_gate "$r" s14 false
check "the next turn is checked again" 'case "$out" in *"\"decision\":\"block\""*) true ;; *) false ;; esac'

# 15. Config values: a quote inside a command survives, CRLF endings are ignored.
r="$work/r15"; new_repo "$r"; set_conf "$r" "$(printf 'TEST_CMD=./check.sh {files} "smoke tag"\r\nMAX_ATTEMPTS=1\r')"
start_turn "$r" s15; printf 'clean\nmore\n' > "$r/app.ts"; run_gate "$r" s15 false
check "a command ending in a quote still runs" '[ -z "$out" ]'
printf 'BUG a\n' > "$r/app.ts"; run_gate "$r" s15 true; b1="$out"
printf 'BUG b\n' > "$r/app.ts"; run_gate "$r" s15 true
out="$b1|$out"
check "MAX_ATTEMPTS with a CRLF ending still caps" 'case "$out" in *"\"decision\":\"block\""*"|"*"after 1 attempts"*) true ;; *) false ;; esac'

# Comment check.
comment_repo() { # dir conf-text
  new_repo "$1"
  printf '// The rate limit comes from the provider contract, see ID-12.\n// previously we used a fixed window\nexport const a = 1;\n' > "$1/legacy.ts"
  set_conf "$1" "$2"
}
r="$work/c1"; comment_repo "$r" 'TEST_CMD='; start_turn "$r" c1
printf '// The rate limit comes from the provider contract, see ID-12.\n// previously we used a fixed window\nexport const a = 1;\n// Updated to use a sliding window as requested\nexport const b = 2;\n' > "$r/legacy.ts"
run_gate "$r" c1 false
check "a history comment added this turn is flagged with its line" 'case "$out" in *"COMMENTS failed"*"legacy.ts:4: comment talks about history"*) true ;; *) false ;; esac'
check "an old comment that was not touched is not flagged" 'case "$out" in *"legacy.ts:2:"*) false ;; *) true ;; esac'

r="$work/c2"; comment_repo "$r" 'TEST_CMD='
printf '// previously we parsed by hand\nexport const u = 1;\n' > "$r/user.ts"
start_turn "$r" c2
printf '// previously we parsed by hand\nexport const u = 1;\nexport const v = 2;\n' > "$r/user.ts"
run_gate "$r" c2 false
check "the user's own comment in a file Claude edits is not flagged" '[ -z "$out" ]'

r="$work/c3"; comment_repo "$r" 'COMMENT_MAX_LINES=0'; start_turn "$r" c3
printf 'export function f() {\n  // TODO handle the empty case\n  // TODO(ID-37) handle the linked account\n  // FIXME see https://example.test/issue/9\n  return 1;\n}\n' > "$r/todo.ts"
run_gate "$r" c3 false
check "TODO needs a ticket; ticket IDs and links pass" 'case "$out" in *"todo.ts:2: TODO without a ticket"*) case "$out" in *"todo.ts:3:"*|*"todo.ts:4:"*) false ;; *) true ;; esac ;; *) false ;; esac'

r="$work/c4"; comment_repo "$r" 'TEST_CMD='; start_turn "$r" c4
{ printf '/**\n'; for i in 1 2 3 4 5 6 7 8 9; do printf ' * line %s\n' "$i"; done; printf ' */\nexport const c = 3;\n// ==========\n'; } > "$r/block.ts"
run_gate "$r" c4 false
check "long blocks and banners are flagged" 'case "$out" in *"block.ts:3: comment block longer than 2 lines"*"block.ts:13: banner or divider"*) true ;; *) false ;; esac'

r="$work/c5"; comment_repo "$r" "$(printf 'COMMENT_MAX_LINES=0\nCOMMENT_MAX_PER_FILE=0')"; start_turn "$r" c5
{ printf '/**\n'; for i in 1 2 3 4 5 6 7 8 9; do printf ' * line %s\n' "$i"; done; printf ' */\nexport const c = 3;\n'; } > "$r/block.ts"
run_gate "$r" c5 false
check "COMMENT_MAX_LINES=0 allows long blocks" '[ -z "$out" ]'

r="$work/c6"; comment_repo "$r" 'TEST_CMD='; start_turn "$r" c6
printf 'class A {\n  #count = 0;\n  // Retries stop at 3 because the provider bans the account after 5 failures.\n  inc() { return ++this.#count; }\n}\n' > "$r/clean.ts"
printf '#!/usr/bin/env python3\n# previously we parsed by hand\nx = 1\n' > "$r/tool.py"
run_gate "$r" c6 false
check "why-comments and #private fields pass" 'case "$out" in *"clean.ts:"*) false ;; *) true ;; esac'
check "hash comments are checked in Python, the shebang is not" 'case "$out" in *"tool.py:2: comment talks about history"*) true ;; *) false ;; esac'

r="$work/c7"; comment_repo "$r" "$(printf 'COMMENT_BANNERS=0\nCOMMENT_MAX_LINES=0\nCOMMENT_MAX_PER_FILE=0')"; start_turn "$r" c7
printf '%s\n' '// ---------------------------------- fixtures' '// A seat holder no longer assigned gets the one 404.' '// Rebuild when the API changed or the UI updated.' '// Restore the previously focused element (WCAG 2.4.3).' '// Pinned to Stripe API version 2024-06-20.' '// Phone mask XXX-XXX-XXXX.' '// Walk fixes 22 Oct 2026: the label is kept.' '// Kept for the audit trail since 3 Mar 2025. comment-check: allow' 'export const e = 5;' > "$r/domain.ts"
printf 'export const View = () => (\n  <div>\n    {/* Updated as requested */}\n  </div>\n);\n' > "$r/view.tsx"
run_gate "$r" c7 false
check "domain words, API dates, masks and allowed banners pass" 'case "$out" in *"domain.ts:1:"*|*"domain.ts:2:"*|*"domain.ts:3:"*|*"domain.ts:4:"*|*"domain.ts:5:"*|*"domain.ts:6:"*|*"domain.ts:8:"*) false ;; *) true ;; esac'
check "dated change notes are flagged" 'case "$out" in *"domain.ts:7: dated change note"*) true ;; *) false ;; esac'
check "JSX comments are checked" 'case "$out" in *"view.tsx:3: comment talks about history"*) true ;; *) false ;; esac'

r="$work/c8"; comment_repo "$r" 'COMMENT_CHECK=0'; start_turn "$r" c8
printf '// previously we used a fixed window\nexport const d = 4;\n' > "$r/off.ts"; run_gate "$r" c8 false
check "COMMENT_CHECK=0 turns the comment check off" '[ -z "$out" ]'

# v1.2.0: comments are rare and short by default.
r="$work/c9"; comment_repo "$r" 'TEST_CMD='; start_turn "$r" c9
printf '%s\n' '// Memberfied pairs by invoice first,' '// so the same order is used here (F2 D2.9).' 'export const p = 1;' '// One' '// two' '// three' 'export const q = 2;' > "$r/short.ts"
run_gate "$r" c9 false
check "a two-line why passes and a third line is flagged" 'case "$out" in *"short.ts:6: comment block longer than 2 lines"*) case "$out" in *"short.ts:2:"*|*"short.ts:5:"*) false ;; *) true ;; esac ;; *) false ;; esac'

r="$work/c10"; comment_repo "$r" 'TEST_CMD='; start_turn "$r" c10
{ for i in 1 2 3 4; do printf '// Rule %s from the provider contract,\n// see ID-%s.\nexport const v%s = %s;\n' "$i" "$i" "$i" "$i"; done; } > "$r/many.ts"
run_gate "$r" c10 false
check "more than 6 new comment lines in one file are flagged once" 'case "$out" in *"many.ts:10: 7 comment lines added in this file"*) case "$out" in *"many.ts:11: 8 comment"*) false ;; *) true ;; esac ;; *) false ;; esac'

r="$work/c11"; comment_repo "$r" 'COMMENT_MAX_PER_FILE=0'; start_turn "$r" c11
{ for i in 1 2 3 4; do printf '// Rule %s from the provider contract,\n// see ID-%s.\nexport const v%s = %s;\n' "$i" "$i" "$i" "$i"; done; } > "$r/many.ts"
run_gate "$r" c11 false
check "COMMENT_MAX_PER_FILE=0 allows any number of short comments" '[ -z "$out" ]'

# v1.2.0: locked acceptance tests (scripts/test-lock.sh, a PreToolUse hook).
lock="$here/scripts/test-lock.sh"
pre_input() { printf '{"session_id":"l","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":{"%s":"%s","old_string":"a"}}' "$1" "$2" "$3" "$4"; }
run_lock() { out="$(pre_input "$@" | "$shell" "$lock")"; code=$?; }
r="$work/l1"; new_repo "$r"; mkdir -p "$r/tests"; printf 'x\n' > "$r/tests/a.test.ts"
printf 'tests/a.test.ts\n' > "$(git -C "$r" rev-parse --absolute-git-dir)/tiered-workflow-locked-tests"
run_lock "$r" Edit file_path "$r/tests/a.test.ts"
check "an edit to a locked test is refused with valid JSON" '[ "$code" = 0 ] && case "$out" in *"\"permissionDecision\":\"deny\""*"tests/a.test.ts"*) valid_json "$out" ;; *) false ;; esac'
run_lock "$r" Edit file_path "$r/app.ts"
check "an edit to a file that is not locked is allowed" '[ "$code" = 0 ] && [ -z "$out" ]'
run_lock "$r" Write file_path "$r/tests/new/b.test.ts"
check "a new file in a new folder is allowed" '[ "$code" = 0 ] && [ -z "$out" ]'
run_lock "$r" NotebookEdit notebook_path "$r/tests/a.test.ts"
check "a notebook edit to a locked path is refused" 'case "$out" in *"\"permissionDecision\":\"deny\""*) true ;; *) false ;; esac'
run_lock "$work" Edit file_path "$work/outside.ts"
check "a file outside any repo is allowed" '[ "$code" = 0 ] && [ -z "$out" ]'
set_conf "$r" 'TEST_CMD='; start_turn "$r" l1
touch "$(git -C "$r" rev-parse --absolute-git-dir)/tiered-workflow-tests-unlocked"
run_lock "$r" Edit file_path "$r/tests/a.test.ts"
check "the user's unlock allows the edit" '[ "$code" = 0 ] && [ -z "$out" ]'
printf 'y\n' > "$r/tests/a.test.ts"; run_gate "$r" l1 false
check "the gate ends the unlock and tells the user" 'case "$out" in *"systemMessage"*"Locked tests were unlocked for this turn"*"tests/a.test.ts"*) [ ! -f "$(git -C "$r" rev-parse --absolute-git-dir)/tiered-workflow-tests-unlocked" ] ;; *) false ;; esac'
run_lock "$r" Edit file_path "$r/tests/a.test.ts"
check "the lock holds again after the unlocked turn" 'case "$out" in *"\"permissionDecision\":\"deny\""*) true ;; *) false ;; esac'
run_lock "$r" Write file_path "$r/tests/a.test.ts"
check "a Write over a locked test is refused" 'case "$out" in *"\"permissionDecision\":\"deny\""*) true ;; *) false ;; esac'
run_lock "$r" Write file_path "$(git -C "$r" rev-parse --absolute-git-dir)/tiered-workflow-tests-unlocked"
check "Claude cannot write the unlock file" 'case "$out" in *"\"permissionDecision\":\"deny\""*"Only the user"*) valid_json "$out" ;; *) false ;; esac'
r="$work/l2"; new_repo "$r"; printf 'x\n' > "$r/b.test.ts"
printf 'b.test.ts\r\n' > "$(git -C "$r" rev-parse --absolute-git-dir)/tiered-workflow-locked-tests"
run_lock "$r" Edit file_path "$r/b.test.ts"
check "a lock file with CRLF endings still locks" 'case "$out" in *"\"permissionDecision\":\"deny\""*) true ;; *) false ;; esac'
touch "$(git -C "$r" rev-parse --absolute-git-dir)/tiered-workflow-tests-unlocked"
run_gate "$r" l2 false
check "the unlock ends in a repo with no gate config" 'case "$out" in *"Locked tests were unlocked"*"b.test.ts"*) [ ! -f "$(git -C "$r" rev-parse --absolute-git-dir)/tiered-workflow-tests-unlocked" ] ;; *) false ;; esac'
touch "$(git -C "$r" rev-parse --absolute-git-dir)/tiered-workflow-tests-unlocked"
out="$(hook_input l2 "$r" Stop false | CLAUDE_PROJECT_DIR="$r" CLAUDE_WORKFLOW_GATE=off "$shell" "$gate")"
check "the unlock ends with the gate off" 'case "$out" in *"Locked tests were unlocked"*) valid_json "$out" && [ ! -f "$(git -C "$r" rev-parse --absolute-git-dir)/tiered-workflow-tests-unlocked" ] ;; *) false ;; esac'
r="$work/l3"; new_repo "$r"; set_conf "$r" 'TEST_CMD=./check.sh {files}'; start_turn "$r" l3
touch "$(git -C "$r" rev-parse --absolute-git-dir)/tiered-workflow-tests-unlocked"
printf 'BUG\n' > "$r/app.ts"; run_gate "$r" l3 false
check "a block still tells the user the unlock ended" 'case "$out" in *"\"decision\":\"block\""*"\"systemMessage\""*"Locked: none"*) valid_json "$out" ;; *) false ;; esac'
check "an unlock with no lock file prints no shell error" 'case "$out" in *"No such file"*) false ;; *) true ;; esac'

# v1.2.0: agent worktrees for parallel work (scripts/agent-worktree.sh).
aw="$here/scripts/agent-worktree.sh"
r="$work/w1/repo"; mkdir -p "$work/w1"; new_repo "$r"
out="$("$shell" "$aw" create "$r" tests)"; code=$?
wt="$work/w1/repo.agent-tests"
check "create makes a detached worktree beside the repo" '[ "$code" = 0 ] && [ -d "$wt" ] && [ "$(git -C "$wt" rev-parse HEAD)" = "$(git -C "$r" rev-parse HEAD)" ] && case "$out" in *"$wt"*) true ;; *) false ;; esac'
printf 'changed\n' > "$wt/app.ts"; mkdir -p "$wt/tests"; printf 'new test\n' > "$wt/tests/n.test.ts"
out="$("$shell" "$aw" collect "$r" tests)"; code=$?
check "collect copies changed and new files into the repo and removes the worktree" '[ "$code" = 0 ] && [ "$(cat "$r/app.ts")" = changed ] && [ "$(cat "$r/tests/n.test.ts")" = "new test" ] && [ ! -d "$wt" ] && case "$out" in *"tests/n.test.ts"*) true ;; *) false ;; esac'
check "collect leaves the changes uncommitted" '[ "$(git -C "$r" rev-list --count HEAD)" = 1 ]'
"$shell" "$aw" create "$r" build >/dev/null; wt="$work/w1/repo.agent-build"
printf 'theirs\n' > "$wt/app.ts"; printf 'ours\n' > "$r/app.ts"
out="$("$shell" "$aw" collect "$r" build 2>&1)"; code=$?
check "collect refuses a clash and keeps the worktree" '[ "$code" = 1 ] && [ -d "$wt" ] && [ "$(cat "$r/app.ts")" = ours ] && case "$out" in *"does not apply"*) true ;; *) false ;; esac'
out="$("$shell" "$aw" create "$r" "../x" 2>&1)"; code=$?
check "create refuses a name that is not letters, digits and dashes" '[ "$code" = 2 ]'
r="$work/w2/repo"; mkdir -p "$work/w2"; new_repo "$r"; "$shell" "$aw" create "$r" c >/dev/null; wt="$work/w2/repo.agent-c"
printf 'committed\n' > "$wt/app.ts"; git -C "$wt" commit -q -am "agent commit"; printf '\000\001\002' > "$wt/blob.bin"
out="$("$shell" "$aw" collect "$r" c)"; code=$?
check "collect keeps a change the agent committed, and a binary file" '[ "$code" = 0 ] && [ "$(cat "$r/app.ts")" = committed ] && cmp -s "$r/blob.bin" <(printf "\000\001\002") && [ "$(git -C "$r" rev-list --count HEAD)" = 1 ]'

# v1.1.0: named steps, {files:<folder>}, REPOS patterns, trust per git folder, the typecheck helper.
r="$work/m1"; new_repo "$r"; mkdir -p "$r/be" "$r/fe"
set_conf "$r" "$(printf 'STEPS=BE FE BOTH\nBE_CMD=echo BE {files:be/} >> %s\nFE_CMD=echo FE {files:fe/} >> %s\nBOTH_CMD=echo BOTH {files:be/} AND {files} >> %s' "$work/m1.log" "$work/m1.log" "$work/m1.log")"
start_turn "$r" m1; printf 'x\n' > "$r/be/a.ts"; run_gate "$r" m1 false
log="$(cat "$work/m1.log" 2>/dev/null)"
check "named steps run, and a prefix passes only its own files" 'case "$log" in *"BE $r/be/a.ts"*) case "$log" in *"FE "*) false ;; *) true ;; esac ;; *) false ;; esac'
check "every placeholder in a command is filled" 'case "$log" in *"BOTH $r/be/a.ts AND $r/be/a.ts"*) true ;; *) false ;; esac'

r="$work/m2"; new_repo "$r"; mkdir -p "$r/be" "$r/bend"
set_conf "$r" "$(printf 'STEPS=BE\nBE_CMD=echo BE {files:be} >> %s' "$work/m2.log")"
start_turn "$r" m2; printf 'x\n' > "$r/be/a.ts"; printf 'x\n' > "$r/bend/b.ts"; run_gate "$r" m2 false
log="$(cat "$work/m2.log" 2>/dev/null)"
check "a folder prefix does not match a longer folder name" 'case "$log" in *"BE $r/be/a.ts"*) case "$log" in *bend*) false ;; *) true ;; esac ;; *) false ;; esac'

# With the old sed reader this step name made BSD sed write $trap/p (GNU sed could run commands).
r="$work/m3"; new_repo "$r"; trap_dir="$work/m3-written_CMD[[:space:]]*=[[:space:]]*"; mkdir -p "$trap_dir"
set_conf "$r" "$(printf 'STEPS=x//;w%s\nTEST_CMD=./check.sh {files}' "$work/m3-written")"
start_turn "$r" m3; printf 'x\n' > "$r/app.ts"; run_gate "$r" m3 false
check "a step name is never run as a sed command" '[ ! -e "$trap_dir/p" ]'

p="$work/host2"; mkdir -p "$p/.claude" "$p/tmp/w1" "$p/tmp/w2"; printf 'REPOS=tmp/*/svc\n' > "$p/.claude/workflow-gate.conf"
new_repo "$p/tmp/w1/svc"; new_repo "$p/tmp/w2/svc"
set_conf "$p/tmp/w1/svc" 'TEST_CMD=./check.sh {files}'; set_conf "$p/tmp/w2/svc" 'TEST_CMD=./check.sh {files}'
start_turn "$p" g1; printf 'BUG in w2\n' > "$p/tmp/w2/svc/app.ts"; run_gate "$p" g1 false
check "REPOS patterns reach every matching worktree" 'case "$out" in *"TEST failed in $p/tmp/w2/svc"*) true ;; *) false ;; esac'

a="$work/o1"; new_repo "$a"; git -C "$a" remote add origin git@example.test:team/product.git
set_conf "$a" 'TEST_CMD=./check.sh {files}'
w="$work/o1-worktree"; git -C "$a" worktree add -q "$w" 2>/dev/null
start_turn "$w" o1; printf 'BUG in the worktree\n' > "$w/app.ts"; run_gate "$w" o1 false
check "trust covers every worktree of the trusted repo" 'case "$out" in *"\"decision\":\"block\""*) true ;; *) false ;; esac'
b="$work/o2"; git clone -q "$a" "$b"; git -C "$b" remote set-url origin git@example.test:team/product.git
start_turn "$b" o2; printf 'BUG in a separate clone\n' > "$b/app.ts"; run_gate "$b" o2 false
check "a separate clone claiming the same origin is not trusted" 'case "$out" in *"not trusted"*) true ;; *) false ;; esac'

r="$work/t1"; new_repo "$r"
printf 'STEPS=LINT EXTRA\nLINT_CMD=./check.sh {files}\nEXTRA_CMD=echo extra\n' > "$r/.claude/workflow-gate.conf"; git -C "$r" add -A; git -C "$r" commit -q -m conf
out="$(bash "$trust_script" --show "$r")"
check "--show lists every step's command and the folder the trust covers" 'case "$out" in *"LINT_CMD: ./check.sh {files}"*"EXTRA_CMD: echo extra"*) case "$out" in *"Trust covers every worktree of: $r/.git"*) true ;; *) false ;; esac ;; *) false ;; esac'
check "--show records nothing" '! bash "$trust_script" --list | grep -q -F "$r/.git"'
old_id="$(git hash-object -- "$r/.claude/workflow-gate.conf")"
printf 'STEPS=LINT EXTRA\nLINT_CMD=./check.sh {files}\nEXTRA_CMD=echo changed\n' > "$r/.claude/workflow-gate.conf"
out="$(bash "$trust_script" "$r" "$old_id" 2>&1)"; code=$?
check "trust is refused when the config changed after --show" '[ "$code" = 1 ] && case "$out" in *"does not match"*) true ;; *) false ;; esac'

r="$work/e1"; new_repo "$r"; set_conf "$r" 'TEST_CMD=test -x "$TIERED_WORKFLOW_SCRIPTS/tsc-changed.sh"'
start_turn "$r" e1; printf 'x\n' > "$r/app.ts"; run_gate "$r" e1 false
check "commands can reach the plugin's helper scripts" '[ -z "$out" ]'

# tsc-changed.sh with a stand-in npx that prints tsc-style errors and its file list.
fake="$work/fakebin"; mkdir -p "$fake"
cat > "$fake/npx" <<'SH'
#!/usr/bin/env bash
listed() { printf '%s\n' "$PWD/node_modules/typescript/lib/lib.d.ts" "$PWD/src/a.ts" "$PWD/src/b.ts"; }
case "${FAKE_TSC:-}" in
  errors) printf 'src/a.ts(1,5): error TS2322: Type "x" is not assignable.\n  More detail for a.\n../shared/x.ts(2,1): error TS2304: Cannot find name "z".\nsrc/old.ts(3,1): error TS2304: Cannot find name "y".\n'; listed; exit 2 ;;
  pretty) printf 'src/a.ts:1:5 - error TS2322: Type "x" is not assignable.\n'; listed; exit 2 ;;
  nofiles) printf '%s\n' "$PWD/node_modules/typescript/lib/lib.d.ts"; exit 0 ;;
  broken) echo "npm ERR! could not determine executable to run"; exit 1 ;;
  *) listed; exit 0 ;;
esac
SH
chmod +x "$fake/npx"
d="$work/tsc"; mkdir -p "$d/app/src" "$d/shared"; dd="$(cd "$d" && pwd -P)"
tsc_run() { (cd "$d/app" && PATH="$fake:$PATH" FAKE_TSC="$1" bash "$here/scripts/tsc-changed.sh" -p tsconfig.json -- "${@:2}"); }
out="$(tsc_run errors "$dd/app/src/a.ts")"; code=$?
check "typecheck helper fails on errors in the changed files" '[ "$code" = 1 ] && case "$out" in *"src/a.ts(1,5)"*"More detail for a."*) case "$out" in *old.ts*) false ;; *) true ;; esac ;; *) false ;; esac'
out="$(tsc_run errors "$dd/app/src/b.ts" "$dd/app/src/a.ts")"; code=$?
check "typecheck helper handles several changed files" '[ "$code" = 1 ] && case "$out" in *"src/a.ts(1,5)"*) true ;; *) false ;; esac'
out="$(tsc_run errors "$dd/shared/x.ts")"; code=$?
check "typecheck helper matches errors reported with ../ paths" '[ "$code" = 1 ] && case "$out" in *"../shared/x.ts(2,1)"*) true ;; *) false ;; esac'
out="$(tsc_run errors "$dd/app/src/b.ts")"; code=$?
check "typecheck helper ignores errors that are only in other files" '[ "$code" = 0 ]'
out="$(tsc_run broken "$dd/app/src/a.ts")"; code=$?
check "typecheck helper fails when tsc cannot run at all" '[ "$code" = 1 ] && case "$out" in *"could not determine"*) true ;; *) false ;; esac'
out="$(tsc_run pretty "$dd/app/src/b.ts")"; code=$?
check "typecheck helper fails when it cannot read the tsc output" '[ "$code" = 1 ] && case "$out" in *"could not read"*) true ;; *) false ;; esac'
out="$(tsc_run nofiles "$dd/app/src/a.ts")"; code=$?
check "typecheck helper fails when tsc checked no file in the folder" '[ "$code" = 1 ] && case "$out" in *"checked no file"*) true ;; *) false ;; esac'
out="$(cd "$d/app" && PATH="$fake:$PATH" bash "$here/scripts/tsc-changed.sh" -p tsconfig.json "$dd/app/src/a.ts" 2>&1)"; code=$?
check "typecheck helper refuses a command without --" '[ "$code" = 2 ]'

printf '\n%s passed, %s failed (shell: %s, %s)\n' "$pass" "$fail" "$shell" "$("$shell" -c 'echo $BASH_VERSION')"
[ "$fail" = 0 ]
