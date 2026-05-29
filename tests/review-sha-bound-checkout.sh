#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FLOW="$REPO_ROOT/start-review/REVIEW-FLOW.md"
REPORT="$REPO_ROOT/start-review/templates/review-report.md"
GUIDE="$REPO_ROOT/start-review/templates/filling-guide.md"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

fail() {
  printf 'review-sha-bound-checkout: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

offset_of() {
  local file="$1" pattern="$2" label="$3" offset
  offset="$(LC_ALL=C grep -Eibom1 -- "$pattern" "$file" | head -n1 | cut -d: -f1 || true)"
  [[ -n "$offset" ]] || fail "$file missing ordered text: $label"
  printf '%s' "$offset"
}

procedure="$TMPDIR/procedure.md"
awk '
  /^##[[:space:]]+Procedure[[:space:]]*$/ { in_section=1; next }
  in_section && /^##[[:space:]]+/ { exit }
  in_section { print }
' "$FLOW" > "$procedure"

[[ -s "$procedure" ]] || fail 'start-review/REVIEW-FLOW.md Procedure section is empty'

single_offset="$(offset_of "$FLOW" '^##[[:space:]]+Single MR checkout mode[[:space:]]*$' 'Single MR checkout mode section')"
procedure_local_offset="$(offset_of "$FLOW" 'When local execution is needed|run targeted tests' 'local test execution guidance')"
if (( single_offset >= procedure_local_offset )); then
  fail 'Single MR checkout mode must appear before local test execution guidance'
fi

procedure_single_offset="$(offset_of "$procedure" 'Single MR checkout mode' 'Procedure single-MR checkout reference')"
procedure_test_offset="$(offset_of "$procedure" 'run targeted tests|targeted tests' 'Procedure targeted-test execution')"
if (( procedure_single_offset >= procedure_test_offset )); then
  fail 'Procedure must enter Single MR checkout mode before running targeted tests'
fi

require_text "$FLOW" 'git status --porcelain.*(empty|clean)|clean.*git status --porcelain' 'clean current-checkout status requirement'
require_text "$FLOW" 'git rev-parse HEAD.*(reviewed_sha|Reviewed SHA|MR metadata|current MR SHA)' 'current checkout exact SHA requirement'
require_text "$FLOW" 'refs/tmp/review/mr-<iid>|refs/tmp/review/mr-[^`[:space:]]+' 'temp review ref for MR head'
require_text "$FLOW" 'refs/merge-requests/<iid>/head:refs/tmp/review/mr-<iid>|refs/merge-requests/\$?\{?iid\}?/head:refs/tmp/review/mr-' 'MR head fetch to temp ref'
require_text "$FLOW" 'git worktree add --detach' 'detached worktree fallback'
require_text "$FLOW" 'git -C <path> rev-parse HEAD.*(MR metadata|metadata.*sha|current MR SHA)' 'detached worktree metadata SHA verification'
require_text "$FLOW" 'Do not run `git pull`|Never run `git pull`|arbitrary `git pull`' 'ban on arbitrary git pull during review'

if grep -Eiq -- 'Pull and run targeted tests|pull and run targeted tests' "$FLOW"; then
  fail 'unsafe Pull and run targeted tests wording remains'
fi

require_text "$FLOW" 'Code I Ran.*(checkout path|path).*(SHA|sha)|checkout path.*(SHA|sha).*Code I Ran' 'Review Report checkout path/SHA evidence guidance'
require_text "$REPORT" 'checkout path.*(SHA|sha)|(SHA|sha).*checkout path' 'Review Report Code I Ran checkout path/SHA prompt'
require_text "$GUIDE" 'Code I Ran.*checkout path.*(SHA|sha)|checkout path.*(SHA|sha).*Code I Ran' 'filling guide checkout path/SHA guidance'

printf 'review-sha-bound-checkout: PASS\n'
