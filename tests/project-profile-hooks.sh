#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
TEST_NAME=project-profile-hooks
source tests/lib/assertions.sh

schema=start-build/templates/delivery-schema.md
for field in provider repository profile_path gate_policy_ref label_profile_ref acceptance_surfaces_ref language_families auxiliary_index_policy branch_naming ci_jobs domain_docs release_deploy_policy manual_validation_rules; do
  assert_file_contains "$schema" "$field" "neutral profile field $field"
done
for copy in start-build/templates/builder-final-handoff.md start-review/templates/reviewer-final-handoff.md; do
  for field in provider: repository: profile_path gate_policy_ref label_profile_ref acceptance_surfaces_ref language_families auxiliary_index_policy branch_naming ci_jobs domain_docs release_deploy_policy manual_validation_rules; do
    assert_file_contains "$copy" "$field" "$copy profile field $field"
  done
done
for file in setup-dev-skills/SKILL.md setup-dev-skills/dev-workflows-generic.md docs/agents/dev-workflows.md; do
  assert_file_contains "$file" forge "$file forge binding"
  assert_file_contains "$file" provider "$file provider profile"
done
for token in GitLab GitHub "Azure DevOps"; do
  assert_file_contains setup-dev-skills/SKILL.md "$token" "setup supports $token"
done
node tests/setup-provider-detector.mjs
assert_file_contains setup-dev-skills/SKILL.md "skill://setup-dev-skills/scripts/detect-provider.mjs" "setup consumes executable provider detector"
assert_file_contains setup-dev-skills/reference/project-profile-facts.json "provider_detection" "facts point to provider detector"
assert_file_contains setup-dev-skills/dev-workflows-generic.md auxiliary-index "neutral seed auxiliary index policy"
assert_file_contains issue-delivery-loop/SKILL.md "must not copy auxiliary-index artifacts" "coordinator isolation"
printf '%s\n' "project-profile-hooks: PASS"
