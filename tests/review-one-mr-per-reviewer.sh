#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'review-one-mr-per-reviewer: FAIL: %s\n' "$*" >&2
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

flow="start-review/REVIEW-FLOW.md"
skill="start-review/SKILL.md"
report="start-review/templates/review-report.md"
handoff="start-review/templates/reviewer-final-handoff.md"

for file in "$skill" "$flow"; do
  require_text "$file" 'one change' 'one-change policy'
  require_text "$file" 'request per fresh reviewer session' 'fresh reviewer policy'
  reject_text "$file" 'batch-approve|batch approve|batch-approval|batch approval' 'batch approval policy'
done
require_text "$flow" 'parent/harness proves the Decoupling' 'parent-proven Decoupling Contract'
require_text "$flow" 'each change request' 'per-change isolation'
require_text "$flow" 'own isolated checkout and fresh' 'isolated checkout and fresh reviewer'
require_text "$flow" 'never batches decisions, comments, or actions' 'serialized no-batch rule'
require_text "$flow" 'git rev-parse HEAD[^.]*exact reviewed commit' 'exact reviewed-commit checkout'
require_text "$flow" 'one durable non-blocking report' 'one durable report publication'
require_text "$report" '^# Review Report$' 'canonical Review Report template'
require_text "$report" 'Review verdict' 'per-change verdict'
require_text "$handoff" '^# Reviewer Final Handoff$' 'canonical reviewer handoff'
require_text "$handoff" 'review_verdict' 'per-change handoff verdict'

printf 'review-one-mr-per-reviewer: PASS\n'
