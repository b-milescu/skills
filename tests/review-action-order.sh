#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
TEST_NAME=review-action-order
source tests/lib/assertions.sh

section=$(mktemp)
trap 'rm -f "$section"' EXIT
awk '
  /^## Publication and actions$/ { active=1; next }
  active && /^## / { exit }
  active { print }
' start-review/REVIEW-FLOW.md > "$section"
[[ -s "$section" ]] || fail "Publication and actions section is empty"

offset() {
  local pattern=$1 label=$2 value
  value=$(LC_ALL=C grep -Einm1 -- "$pattern" "$section" | cut -d: -f1 || true)
  [[ -n $value ]] || fail "missing ordered action step: $label"
  printf '%s' "$value"
}

previous=-1
for spec in \
  'Draft the Review Report|draft report' \
  'final provider-native change-request|final snapshot' \
  'guard fails, convert.*blocked|guard failure to blocked' \
  'forge publish|durable report publication' \
  'fresh `forge snapshot`|fresh pre-action snapshot' \
  'exactly one authorized `forge act`|one authorized action' \
  'provider-native post-read|post-read and handoff'; do
  pattern=${spec%%|*}; label=${spec#*|}; current=$(offset "$pattern" "$label")
  (( current > previous )) || fail "action step out of order: $label"
  previous=$current
done

assert_file_contains "$section" 'safe-body' "safe body publication"
assert_file_contains "$section" 'byte-for-byte' "publication readback"
assert_file_contains "$section" 'head changed after publication' "changed-head handling"
assert_file_contains "$section" 'skip' "changed-head skips action"
assert_file_contains "$section" 'stale-commit' "stale commit result"
assert_file_contains "$section" 'action result' "action result"
assert_file_contains "$section" 'final' "final handoff"
assert_file_contains "$section" 'Finish owner: parent' "parent finish owner"
assert_file_contains "$section" 'not-approved' "parent no approval"
assert_file_contains "$section" 'finish `none`' "parent no finish"

assert_file_contains start-review/templates/review-report.md 'intended action' "intended action field"
assert_file_contains start-review/templates/review-report.md 'completed action' "completed action field"
assert_file_contains start-review/templates/filling-guide.md 'action failure' "post-pass action failure guidance"
assert_file_contains start-review/templates/filling-guide.md 'pass verdict' "pass verdict remains separate"

printf '%s\n' "review-action-order: PASS"
