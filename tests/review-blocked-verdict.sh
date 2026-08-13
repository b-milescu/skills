#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
TEST_NAME=review-blocked-verdict
source tests/lib/assertions.sh

normalize_enum() {
  tr '/|' '\n' | sed -E 's/[`"<>]//g; s/^[[:space:]]+//; s/[[:space:]]+$//' | sed '/^$/d'
}

assert_enum() {
  local label=$1 actual=$2 expected=$3
  diff -u <(printf '%s\n' "$expected") <(printf '%s\n' "$actual" | normalize_enum) || fail "$label drifted"
}

report_row() {
  awk -F'|' -v row="$2" '$0 ~ /^\|/ { field=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", field); if (field == row) { value=$3; gsub(/^[[:space:]]+|[[:space:]]+$/, "", value); print value; exit } }' "$1"
}

yaml_field() {
  sed -nE "s/^[[:space:]]+$2:[[:space:]]*\"([^\"]+)\".*/\1/p" "$1" | head -n1
}

verdicts='pass
request-changes
reject
blocked'
blockers='none
missing-authority
stale-or-missing-ci
changed-head-sha
merge-conflict
sha-bound-action-unsupported
preflight-failure
permission-failure
human-decision-needed
partial-review
secret-exposure-suspected
other'
report=start-review/templates/review-report.md
handoff=start-review/templates/reviewer-final-handoff.md

assert_enum "Review Report verdict enum" "$(report_row "$report" 'Review verdict')" "$verdicts"
assert_enum "reviewer handoff verdict enum" "$(yaml_field "$handoff" review_verdict)" "$verdicts"
assert_enum "Review Report blocker enum" "$(report_row "$report" 'Action blocker')" "$blockers"
assert_enum "reviewer handoff blocker enum" "$(yaml_field "$handoff" action_blocker)" "$blockers"


assert_file_contains start-review/SKILL.md 'Keep verdict, approval, finish, action blocker, and next action separate' "separate review decisions"
assert_file_contains start-review/REVIEW-FLOW.md 'human-decision-needed' "human decision routing"
assert_file_contains "$report" 'do not disguise it as a Must Fix' "blocked differs from builder revision work"
assert_file_contains "$report" 'revision-ready' "revision-ready MF"
assert_file_contains "$report" 'bounded remedy direction' "bounded MF remedy"
assert_file_contains start-review/templates/filling-guide.md 'revision-ready' "MF filling guidance"
assert_file_contains start-review/templates/filling-guide.md 'bounded remedy direction' "bounded MF filling remedy"

for field in review_verdict approval_action finish_action action_blocker next_action; do
  assert_file_contains "$handoff" "  $field:" "handoff field $field"
done
for field in 'Review verdict' 'Approval action' 'Finish action' 'Action blocker' 'Next action'; do
  assert_file_contains "$report" "| $field |" "report field $field"
done

printf '%s\n' "review-blocked-verdict: PASS"
