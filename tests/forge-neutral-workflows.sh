#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
TEST_NAME="forge-neutral-workflows"
source tests/lib/assertions.sh

assert_path_readable forge/SKILL.md "forge skill"
for ref in common-guard gitlab github azure-devops; do
  assert_path_readable "forge/reference/$ref.md" "$ref provider contract"
done

forge=$(<forge/SKILL.md)
for operation in preflight snapshot publish act post_merge_snapshot; do
  assert_text_contains "$forge" "$operation" "forge operation $operation"
done
assert_text_contains "$forge" "model-invoked" "model invocation contract"
assert_text_contains "$forge" "fail closed" "binding failure contract"
assert_text_contains "$forge" "generic callers do not branch on provider" "single provider selection"

common=$(<forge/reference/common-guard.md)
for phase in \
  "provider/repository binding" \
  "current target re-read" \
  "reviewed commit binding" \
  "CI evidence" \
  "action-specific authority" \
  "caller identity/context" \
  "safe body validation" \
  "provider-specific fallback eligibility" \
  "exactly one mutation" \
  "provider-native post-mutation re-read"; do
  assert_text_contains "$common" "$phase" "ordered common guard phase: $phase"
done

assert_file_contains forge/reference/gitlab.md "MCP first" "GitLab MCP-first rule"
assert_file_contains forge/reference/gitlab.md "help-first" "GitLab guarded fallback rule"

for token in headRefOid commit_id "Checks and classic statuses" expectedHeadOid "merge queue" "closingIssuesReferences" incomplete-pagination; do
  assert_file_contains forge/reference/github.md "$token" "GitHub contract token $token"
done
for token in lastMergeSourceCommit lastMergeCommit "current PR iteration" "policy input" sha-bound-action-unsupported "state category"; do
  assert_file_contains forge/reference/azure-devops.md "$token" "Azure DevOps contract token $token"
done

schema=start-build/templates/delivery-schema.md
assert_path_readable "$schema" "neutral delivery schema"
assert_path_absent start-build/templates/gitlab-delivery-schema.md "retired GitLab delivery schema"
for token in 'kind: "change-delivery"' provider repository issue change_request commit ci local_gate tdd authority handoff_contract evidence blockers "opaque strings"; do
  assert_file_contains "$schema" "$token" "delivery schema token $token"
done
if grep -R -n -E 'gitlab-delivery|gitlab-delivery-schema|GITLAB-DELIVERY-SCHEMA' \
  start-build start-review issue-delivery-loop setup-dev-skills docs/agents retro agents README.md; then
  fail "retired GitLab delivery schema remains in an active shared surface"
fi

for workflow in start-build/SKILL.md start-review/SKILL.md issue-delivery-loop/SKILL.md gitlab-to-issues/SKILL.md retro/SKILL.md; do
  assert_file_contains "$workflow" "forge" "$workflow invokes forge"
  assert_file_not_contains "$workflow" 'skill://gitlab' "$workflow has no unconditional GitLab dependency"
done
for shared in \
  start-build/reference/standalone-gate.md \
  start-build/reference/multiple-worktrees.md \
  start-build/templates/revision-packet.md \
  start-build/templates/stuck-packet.md \
  start-review/templates/unblock-response.md; do
  assert_file_contains "$shared" "forge" "$shared provider-neutral forge seam"
  for forbidden in GitLab "MR URL" "MR comment" "MR IID" merge_commit_sha squash_commit_sha; do
    assert_file_not_contains "$shared" "$forbidden" "$shared excludes $forbidden"
  done
done

for agent in agents/claude/mr-*.md agents/omp/mr-*.md; do
  assert_file_contains "$agent" "bound provider" "$agent provider selection"
  assert_file_contains "$agent" "forge" "$agent forge autoload/prompt"
  assert_file_not_contains "$agent" "for GitLab issue" "$agent generic route wording"
done

setup=$(<setup-dev-skills/SKILL.md)
for provider in GitLab GitHub "Azure DevOps"; do
  assert_text_contains "$setup" "$provider" "setup provider $provider"
done
assert_text_not_contains "$setup" 'do not add `/start-build`' "retired non-GitLab disablement"

printf '%s\n' "forge-neutral-workflows: PASS"
