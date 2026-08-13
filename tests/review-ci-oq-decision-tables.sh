#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
TEST_NAME=review-ci-oq-decision-tables
source tests/lib/assertions.sh

flow=start-review/REVIEW-FLOW.md
assert_file_contains "$flow" '## CI and Open Question decision tables' "canonical CI/OQ owner"
for token in \
  'success on the exact reviewed commit or provider-proven integration candidate' \
  'pass/approval eligible when every other guard passes' \
  'pending/running' \
  'selected-provider proof of protected policy and exact binding' \
  'conditionally required job absent' \
  'target-repo Check Gate or `project_profile` declares it not applicable' \
  'rules-omitted is absent, not skipped' \
  'every applicable required job succeeds' \
  'Absent conditionally required CI for any other reason blocks' \
  'failed/canceled/skipped applicable CI' \
  'missing/incomplete/unknown/wrong binding' \
  'authorized written waiver' \
  'recorded scope/provenance' \
  'reviewer cannot self-waive' \
  'never substitutes for CI' \
  'never grants approval'; do
  assert_file_contains "$flow" "$token" "CI policy: $token"
done
for token in \
  'answered from evidence' \
  'no blocker' \
  'builder evidence gap' \
  '`request-changes` with a bounded remedy' \
  'human/product/security decision' \
  '`blocked`; no approval' \
  'non-blocking' \
  '`C-N`, follow-up, or recorded rationale'; do
  assert_file_contains "$flow" "$token" "OQ policy: $token"
done
section=$(sed -n '/^## CI and Open Question decision tables$/,/^## Finish authority source precedence$/p' "$flow")
if grep -Eq 'headRefOid|lastMergeCommit|GitLab' <<<"$section"; then fail "provider mapping in generic table"; fi

assert_file_contains start-review/SKILL.md 'REVIEW-FLOW.md' "skill canonical policy pointer"
assert_file_contains start-review/templates/filling-guide.md 'CI and Open Question decision tables' "filling-guide canonical table pointer"
for file in start-review/SKILL.md start-review/templates/filling-guide.md; do
  if grep -Eq 'rules-omitted|conditionally required job absent|reviewer cannot self-waive' "$file"; then fail "$file duplicates CI matrix"; fi
done

printf '%s\n' "review-ci-oq-decision-tables: PASS"
