#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'review-blocked-verdict: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

require_absent() {
  local file="$1" pattern="$2" label="$3"
  if grep -Eiq -- "$pattern" "$file"; then
    grep -Ein -- "$pattern" "$file" >&2 || true
    fail "$file still has $label"
  fi
}

review_docs=(
  "start-review/SKILL.md"
  "start-review/REVIEW-FLOW.md"
  "start-review/templates/review-report.md"
  "start-review/templates/reviewer-final-handoff.md"
  "start-review/templates/filling-guide.md"
  "agents/claude/mr-reviewer.md"
  "agents/pi/mr-reviewer.md"
)

for file in "${review_docs[@]}"; do
  require_text "$file" 'pass[[:space:]]*/[[:space:]]*request-changes[[:space:]]*/[[:space:]]*reject[[:space:]]*/[[:space:]]*blocked|pass[[:space:]]*\|[[:space:]]*request-changes[[:space:]]*\|[[:space:]]*reject[[:space:]]*\|[[:space:]]*blocked' 'review verdict enum with blocked'
  require_absent "$file" 'approve[[:space:]]*/[[:space:]]*request-changes[[:space:]]*/[[:space:]]*reject|approve[[:space:]]*\|[[:space:]]*request-changes[[:space:]]*\|[[:space:]]*reject' 'approve-based review verdict enum'
done

for field in 'Approval action' 'Finish action' 'Action blocker' 'Next action'; do
  require_text "start-review/templates/review-report.md" "$field" "Review Report $field field"
done

for field in 'review_verdict' 'approval_action' 'finish_action' 'action_blocker' 'next_action'; do
  require_text "start-review/templates/reviewer-final-handoff.md" "^[[:space:]]+$field:" "reviewer final handoff $field field"
done

routing_docs=(
  "start-review/SKILL.md"
  "start-review/REVIEW-FLOW.md"
  "start-review/templates/filling-guide.md"
  "agents/claude/mr-reviewer.md"
  "agents/pi/mr-reviewer.md"
)

for file in "${routing_docs[@]}"; do
  for blocker in \
    'missing-authority' \
    'stale-or-missing-ci' \
    'changed-head-sha' \
    'sha-bound-action-unsupported' \
    'preflight-failure' \
    'permission-failure' \
    'human-decision-needed'; do
    require_text "$file" "$blocker" "$blocker blocked routing"
  done
  require_text "$file" 'Approval action' 'approval action routing'
  require_text "$file" 'Finish action' 'finish action routing'
  require_text "$file" 'Action blocker' 'action blocker routing'
done

printf 'review-blocked-verdict: PASS\n'
