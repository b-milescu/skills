#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'review-authority-explicit: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

review_authority_docs=(
  "start-review/REVIEW-FLOW.md"
  "start-review/SKILL.md"
  "start-review/templates/review-report.md"
  "start-review/templates/filling-guide.md"
  "agents/claude/mr-reviewer.md"
  "agents/pi/mr-reviewer.md"
)

# Reviewer-facing guidance must default approval after pass while keeping merge
# authority explicit. Missing merge authority must not silently become
# approval-only finish authority.
for file in "${review_authority_docs[@]}"; do
  require_text \
    "$file" \
    'approval[^.]*default|default[^.]*approval|default-after-pass' \
    'default approval-after-pass policy'
  require_text \
    "$file" \
    'approval[^.]*distinct[^.]*merge|merge[^.]*distinct[^.]*approval|separate[^.]*Approval action[^.]*Finish action|missing merge authority[^.]*not default approval' \
    'approval authority separated from merge authority'
  if grep -Ein -- \
    'missing[^.]*Merge authority[^.]*approval-only|default[^.]*approval-only|approval-only[^.]*(if absent|when absent|if missing|when missing)' \
    "$file" |
    grep -Eiv -- 'do not default|not default|not approval-only|blocks finish|finish[^.]*only'; then
    grep -Ein -- \
      'missing[^.]*Merge authority[^.]*approval-only|default[^.]*approval-only|approval-only[^.]*(if absent|when absent|if missing|when missing)' \
      "$file" >&2 || true
    fail "$file implies missing Merge authority may default to approval-only finish authority"
  fi
done

require_text \
  "start-review/REVIEW-FLOW.md" \
  'Reviewer approval is allowed by default after a passing review unless explicitly restricted' \
  'canonical default approval-after-pass policy'
require_text \
  "start-review/REVIEW-FLOW.md" \
  'Missing merge authority/source blocks finish, not the review judgment or default approval by itself|block only the finish action' \
  'missing merge authority blocks finish but not default approval'
require_text \
  "start-review/templates/review-report.md" \
  'Approval authority.*default-after-pass|default-after-pass.*Approval authority' \
  'Review Report Approval authority row'
require_text \
  "start-review/templates/review-report.md" \
  'Merge authority.*finish|finish-authority.*Merge authority' \
  'Review Report Merge authority row scoped to finish actions'
require_text \
  "start-review/templates/filling-guide.md" \
  'Missing Merge authority[^.]*blocks finish actions[^.]*not default approval|missing merge authority[^.]*blocks finish[^.]*not default approval' \
  'filling-guide missing merge authority finish-only blocker'

for file in agents/claude/mr-reviewer.md agents/pi/mr-reviewer.md; do
  require_text \
    "$file" \
    'approval is allowed by default after a passing review' \
    'agent prompt default approval-after-pass policy'
  require_text \
    "$file" \
    'If merge authority is missing[^.]*do not merge[^.]*not as a reason to withhold default approval' \
    'agent prompt missing merge authority finish-only blocker'
done

printf 'review-authority-explicit: PASS\n'
