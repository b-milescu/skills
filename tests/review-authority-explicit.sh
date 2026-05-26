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

# Reviewer-facing guidance must not silently turn omitted authority into
# approval-only. Explicit approval-only is valid; missing authority is not.
for file in "${review_authority_docs[@]}"; do
  if grep -Ein -- \
    'default[^.]*approval-only|approval-only[^.]*(if absent|when absent|if missing|when missing)|missing[^.]*approval-only' \
    "$file" |
    grep -Eiv -- 'do not default|not default|not approval-only'; then
    grep -Ein -- \
      'default[^.]*approval-only|approval-only[^.]*(if absent|when absent|if missing|when missing)|missing[^.]*approval-only' \
      "$file" >&2 || true
    fail "$file implies missing Merge authority may default to approval-only"
  fi
done

require_text \
  "start-review/REVIEW-FLOW.md" \
  'Merge authority is explicit; if (it is )?missing[^.]*block|missing[^.]*Merge authority[^.]*block' \
  'handoff integrity rule that missing Merge authority blocks approval actions'
require_text \
  "start-review/REVIEW-FLOW.md" \
  'explicit `approval-only`[^.]*valid|`approval-only`[^.]*valid' \
  'statement that explicit approval-only remains valid'
require_text \
  "start-review/templates/review-report.md" \
  'Merge authority.*(missing[^`|]*= blocker|blocker[^`|]*if missing|explicit value)' \
  'Review Report Merge authority row that treats missing authority as a blocker'
require_text \
  "start-review/templates/filling-guide.md" \
  'missing[^.]*Merge authority[^.]*(block|no approval)|Merge authority[^.]*missing[^.]*(block|no approval)' \
  'filling-guide no-default authority instruction'

for file in agents/claude/mr-reviewer.md agents/pi/mr-reviewer.md; do
  require_text \
    "$file" \
    '`approval-only`[^.]*permit|approval-only[^.]*permit' \
    'agent prompt statement that explicit approval-only permits approval-only handling'
  require_text \
    "$file" \
    'authority is missing[^.]*do not approve|missing[^.]*do not approve|missing[^.]*no approval' \
    'agent prompt missing-authority blocker'
done

printf 'review-authority-explicit: PASS\n'
