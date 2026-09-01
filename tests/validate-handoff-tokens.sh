#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
TEST_NAME=validate-handoff-tokens
source tests/lib/assertions.sh

validator=start-review/scripts/validate-handoff-tokens.mjs
fixtures=tests/fixtures/handoff-tokens

expect_pass() {
  local fixture=$1 output
  if ! output=$(node "$validator" --handoff "$fixture" 2>&1); then
    fail "$fixture unexpectedly failed: $output"
  fi
  assert_text_contains "$output" 'handoff token validation: PASS' "$fixture pass result"
}

expect_fail() {
  local fixture=$1 expected=$2 output
  if output=$(node "$validator" --handoff "$fixture" 2>&1); then
    fail "$fixture unexpectedly passed: $output"
  fi
  assert_text_contains "$output" "$expected" "$fixture failure reason"
}

expect_pass "$fixtures/valid-builder.yaml"
expect_pass "$fixtures/valid-reviewer.yaml"

expect_fail "$fixtures/unknown-review-verdict.yaml" 'agent_handoff.review_verdict'
expect_fail "$fixtures/missing-review-verdict.yaml" 'agent_handoff.review_verdict'
expect_fail "$fixtures/unknown-action-blocker.yaml" 'agent_handoff.action_blocker'
expect_fail "$fixtures/missing-action-blocker.yaml" 'agent_handoff.action_blocker'
expect_fail "$fixtures/unknown-next-action.yaml" 'agent_handoff.next_action'
expect_fail "$fixtures/missing-next-action.yaml" 'agent_handoff.next_action'
expect_fail "$fixtures/unknown-builder-blocker-token.yaml" 'agent_handoff.delivery.handoff_contract.blocker_token'
expect_fail "$fixtures/missing-builder-blocker-token.yaml" 'agent_handoff.delivery.handoff_contract.blocker_token'
expect_fail "$fixtures/unknown-reviewer-blocker-token.yaml" 'agent_handoff.delivery.handoff_contract.blocker_token'
expect_fail "$fixtures/missing-reviewer-blocker-token.yaml" 'agent_handoff.delivery.handoff_contract.blocker_token'
expect_fail "$fixtures/builder-other-missing-detail.yaml" 'agent_handoff.blocker_detail'
expect_fail "$fixtures/reviewer-action-other-missing-detail.yaml" 'agent_handoff.blocker_detail'
expect_fail "$fixtures/reviewer-blocker-other-empty-detail.yaml" 'agent_handoff.blocker_detail'
expect_fail start-review/templates/reviewer-final-handoff.md 'agent_handoff.review_verdict'

printf '%s\n' 'validate-handoff-tokens: PASS'
