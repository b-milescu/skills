#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
TEST_NAME="delivery-schema"
source tests/lib/assertions.sh

schema=start-build/templates/delivery-schema.md
assert_path_readable "$schema" "change delivery schema"
assert_path_absent start-build/templates/gitlab-delivery-schema.md "retired schema"
for token in 'kind: "change-delivery"' provider repository issue change_request commit ci local_gate tdd authority handoff_contract evidence blockers "opaque strings"; do
  assert_file_contains "$schema" "$token" "schema token $token"
done
for copy in start-build/templates/builder-final-handoff.md start-review/templates/reviewer-final-handoff.md; do
  assert_file_contains "$copy" "Change-request locator:" "$copy locator line"
  assert_file_contains "$copy" "Durable note id:" "$copy note-id line"
  assert_file_not_contains "$copy" 'CHANGE-DELIVERY-SCHEMA:BEGIN' "$copy has no generated-copy marker"
  assert_file_not_contains "$copy" '```yaml' "$copy has no YAML fence"
done
if grep -R -n -E 'gitlab-delivery|gitlab-delivery-schema|GITLAB-DELIVERY-(SCHEMA|FIELDS)' \
  start-build start-review issue-delivery-loop setup-dev-skills docs/agents retro agents README.md; then
  fail "retired schema name or marker remains"
fi
if grep -Eq '\b(iid|mr|pipeline|source_branch|target_branch|sha)\b' "$schema"; then
  fail "provider-specific GitLab record names remain in neutral schema"
fi
printf '%s\n' "delivery-schema: PASS"
