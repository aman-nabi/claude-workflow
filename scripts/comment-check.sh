#!/usr/bin/env bash
# tiered-workflow comment check (docs/workflow-v1.1.0.md, section 5): flags added
# comments that break the comment rules, because prompt rules alone fade over a
# long session. Phrases that are also ordinary domain words are left out on purpose.
# Usage: comment-check.sh <repo> <max-block-lines> <banners 1|0> <max-lines-per-file> <base-dir> <file>...
# A limit of 0 means no limit. Each file is compared with its turn-start copy in
# <base-dir>, else HEAD, else nothing. Prints one finding per line and exits 1 when there are any.
set -u

repo="$1"
max_block="$2"
check_banners="$3"
max_file="$4"
base_dir="$5"
shift 5
tmp="$(mktemp -d "${TMPDIR:-/tmp}/comment-check.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

n=0
for f in "$@"; do
  [ -f "$repo/$f" ] || continue
  n=$((n + 1))
  if [ -n "$base_dir" ] && [ -f "$base_dir/$f" ]; then
    before="$base_dir/$f"
  elif git -C "$repo" cat-file -e "HEAD:$f" 2>/dev/null; then
    before="$tmp/$n"
    git -C "$repo" show "HEAD:$f" > "$before"
  else
    before=/dev/null
  fi
  (cd "$repo" && git -c core.quotePath=false diff --no-index --no-color --no-ext-diff -U0 -- "$before" "$f")
done | LC_ALL=C awk -v max_block="$max_block" -v check_banners="$check_banners" -v max_file="$max_file" '
  function ext_of(path,   k, parts) { k = split(path, parts, "."); return k > 1 ? tolower(parts[k]) : "" }
  function report(msg) { findings++; if (findings <= 40) print file ":" line ": " msg }
  /^diff --git / { header = 1; next }
  header && /^\+\+\+ / {
    header = 0
    file = substr($0, 5)
    sub(/\t.*$/, "", file)
    if (file ~ /^".*"$/) file = substr(file, 2, length(file) - 2)
    sub(/^b\//, "", file)
    in_file = 0
    e = ext_of(file)
    style = ""
    if (e ~ /^(ts|tsx|js|jsx|mjs|cjs|java|kt|kts|go|rs|c|h|cc|cpp|hpp|cs|swift|php|scala|dart|css|scss|less)$/) style = "slash"
    else if (e ~ /^(py|sh|bash|zsh|rb|pl|yml|yaml|toml|r|ex|exs)$/) style = "hash"
    next
  }
  header { next }
  /^@@ / {
    if (match($0, /\+[0-9]+/)) line = substr($0, RSTART + 1, RLENGTH - 1) + 0
    block = 0
    next
  }
  /^\+/ {
    text = substr($0, 2)
    trimmed = text; sub(/^[ \t]+/, "", trimmed)
    is_comment = 0
    if (style == "slash" && (trimmed ~ /^\/\// || trimmed ~ /^\/\*/ || trimmed ~ /^\*/ || trimmed ~ /^\{\/\*/)) is_comment = 1
    if (style == "hash" && trimmed ~ /^#/ && trimmed !~ /^#!/) is_comment = 1
    if (!is_comment) { block = 0; line++; next }
    block++
    lower = tolower(trimmed)
    if (lower ~ /comment-check: *allow/) { line++; next }
    in_file++
    if (max_block > 0 && block == max_block + 1) report("comment block longer than " max_block " lines; keep the why, move the rest to docs or the commit message")
    if (max_file > 0 && in_file == max_file + 1) report(in_file " comment lines added in this file, more than " max_file "; keep only the whys the code cannot show")
    if (lower ~ /(^|[^a-z])(previously (we|this|it|the code|used|was|did|had)|was changed|now uses|as requested|as you asked|per your request|the user asked|you asked for|we decided|fixed the bug|the old code|the new code)([^a-z]|$)/ || lower ~ /(^|[^a-z])i (added|changed|updated|removed)([^a-z]|$)/)
      report("comment talks about history or the session; describe the code as it is now, put history in the commit message")
    else if (lower ~ /(^|[^0-9])[0-9][0-9]? (jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]* 20[0-9][0-9]/ || lower ~ /(^|[^a-z])(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]* [0-9][0-9]?, 20[0-9][0-9]/)
      report("dated change note; put when and why it changed in the commit message, keep only the rule here")
    if (trimmed ~ /(^|[^A-Za-z])(TODO|FIXME|HACK)([^A-Za-z]|$)/ && trimmed !~ /([A-Z][A-Z0-9]+-[0-9]+|#[0-9]+|https?:\/\/)/)
      report("TODO without a ticket reference; add the ticket or remove it")
    if (check_banners != "0" && trimmed ~ /^(\/\/|\/\*|\*|#)[ \t]*[-=*#_~+][-=*#_~+][-=*#_~+][-=*#_~+][-=*#_~+][-=*#_~+]/)
      report("banner or divider comment; remove it")
    line++
    next
  }
  END { if (findings > 40) print "... " findings - 40 " more"; exit findings > 0 ? 1 : 0 }
'
