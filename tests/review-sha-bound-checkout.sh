#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'review-sha-bound-checkout: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

reject_text() {
  local file="$1" pattern="$2" label="$3"
  ! grep -Eiq -- "$pattern" "$file" || fail "$file contains $label"
}

offset_of() {
  local file="$1" pattern="$2" label="$3" offset
  offset="$(LC_ALL=C grep -Eibom1 -- "$pattern" "$file" | cut -d: -f1 || true)"
  [[ -n "$offset" ]] || fail "$file missing ordered text: $label"
  printf '%s' "$offset"
}

flow="start-review/REVIEW-FLOW.md"
report="start-review/templates/review-report.md"
checkout_section="$(awk '
  /^## Single-change request checkout mode$/ { in_section=1; next }
  in_section && /^## / { exit }
  in_section { print }
' "$flow")"
guide="start-review/templates/filling-guide.md"
provider="forge/reference/gitlab.md"

checkout_offset="$(offset_of "$flow" '^##[[:space:]]+Single-change request checkout mode' 'checkout binding')"
checks_offset="$(offset_of "$flow" 'run targeted checks' 'targeted checks')"
(( checkout_offset < checks_offset )) || fail 'checkout binding must precede targeted checks'

require_text "$flow" 'git rev-parse HEAD' 'observed checkout commit'
require_text "$flow" 'exact reviewed commit from a fresh' 'fresh-snapshot commit binding'
require_text "$flow" '`forge snapshot`' 'fresh snapshot source'
require_text "$flow" 'detached isolated' 'detached checkout'
require_text "$flow" 'recreates a detached isolated' 'worktree fallback'
require_text "$flow" 'selected provider branch' 'provider ownership'
require_text "$flow" 'materializes that exact commit' 'provider-owned commit materialization'
require_text "$flow" 'Never run an arbitrary `git pull`' 'git pull ban'
require_text "$flow" 'each change request' 'per-request isolation'
require_text "$flow" 'own isolated checkout and fresh' 'multiple-request isolation'
! grep -Eiq 'refs/merge-requests|refs/tmp/review/mr-|<iid>|gitlab' <<<"$checkout_section" || fail "$flow checkout section contains provider-specific mechanics"

require_text "$report" 'isolated checkout path[^.]*observed commit' 'report checkout evidence'
require_text "$report" 'matches the reviewed commit' 'report commit match'
require_text "$report" 'Not run — <rationale>' 'report not-run rationale'
require_text "$guide" 'isolated checkout path[^.]*observed commit' 'guide checkout evidence'
require_text "$guide" 'matches the reviewed commit' 'guide commit match'
require_text "$guide" 'Not run — <rationale>' 'guide not-run rationale'
require_text "$provider" 'snapshot|commit|fetch|checkout' 'GitLab provider fetch/materialization route'

printf 'review-sha-bound-checkout: PASS\n'
