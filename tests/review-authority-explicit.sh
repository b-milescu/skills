#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
TEST_NAME=review-authority-explicit
source tests/lib/assertions.sh
source tests/lib/agent-prompt-sets.sh

docs=(
  start-review/REVIEW-FLOW.md
  start-review/SKILL.md
  start-review/templates/review-report.md
  start-review/templates/filling-guide.md
)
for file in "${docs[@]}"; do
  assert_file_contains "$file" 'Approval authority' "$file approval authority"
  assert_file_contains "$file" 'Finish authority' "$file finish authority"
  assert_file_contains "$file" 'default-after-pass' "$file policy-gated approval default"
  assert_file_not_contains "$file" 'Merge authority' "$file retired generic merge authority"
  assert_file_not_contains "$file" 'bound MR' "$file retired bound-MR terminology"
  assert_file_not_contains "$file" 'GitLab Review Report' "$file retired GitLab report terminology"
done

flow=start-review/REVIEW-FLOW.md
assert_file_contains "$flow" 'stable repository policy' "stable approval policy source"
assert_file_contains "$flow" 'Missing Finish authority blocks only' "missing finish authority scope"
assert_file_contains "$flow" 'never judgment or independently permitted approval' "judgment and approval remain independent"
assert_file_contains "$flow" 'Silence never becomes `approval-only`' "silence does not create authority"
assert_file_contains "$flow" 'Finish owner: parent' "parent finish owner"
assert_file_contains "$flow" 'not-approved' "parent takes no approval"
assert_file_contains "$flow" 'finish `none`' "parent takes no finish"
assert_file_contains "$flow" 'forge publish' "durable provider-neutral report publication"
assert_file_contains forge/reference/common-guard.md 'Authority Verification' "common authority guard owner"
assert_file_contains start-review/SKILL.md 'Reviewer Lift row' "Reviewer Lift claims"

for file in $(agent_prompt_paths "${routed_final_reviewer_prompt_names[@]}"); do
  assert_file_contains "$file" 'Canonical development pattern source: `start-review`' "$file start-review source"
  assert_file_contains "$file" '`forge` common-guard authority verification' "$file forge authority source"
  assert_file_contains "$file" 'Reviewer Lift' "$file claims-to-verify seam"
  assert_file_contains "$file" 'Finish owner: parent' "$file parent ownership"
  assert_file_contains "$file" 'approval_action: "not-approved"' "$file parent no approval"
  assert_file_contains "$file" 'finish_action: "none"' "$file parent no finish"
done

assert_file_contains forge/reference/gitlab.md 'gitlab/reference/review-actions.md' "GitLab authority entry point"
assert_file_contains gitlab/reference/authority-verification.md 'Finish owner: parent' "GitLab native authority contract"

for file in start-build/reference/parent-orchestrator.md issue-delivery-loop/SKILL.md; do
  assert_file_contains "$file" 'Finish owner: parent' "$file parent finish owner"
  assert_file_contains "$file" 'parent' "$file parent owns actions"
done

printf '%s\n' "review-authority-explicit: PASS"
