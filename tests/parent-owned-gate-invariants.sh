#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
TEST_NAME=parent-owned-gate-invariants
source tests/lib/assertions.sh

gate=start-build/reference/parent-owned-gate.md
for token in 'local_gate_owner: "parent"' builder_gate_status 'status: "not-run"' 'not_run_reason: "parent-owned"' 'ready_transition_owner: "parent"' 'must not claim local gate PASS/FAIL' 'parent posts the Gate Receipt and marks ready' gate_receipt.kind=gate-receipt change_id issue_id checkout_commit 'result: "PASS"' preflight_checks evidence observed_at 'Parent verification checklist' 'Gate coverage is `full-local`, `hybrid`, or `ci-only`' waiver 'byte-for-byte' 'delta-only' 'stale evidence' 'new exact-commit Gate Receipt'; do
  assert_file_contains "$gate" "$token" "parent gate token $token"
done
for token in parent-owned-gate.md gate_receipt.kind=gate-receipt parent-owned; do
  assert_file_contains start-build/templates/delivery-schema.md "$token" "schema parent gate token"
done
for file in start-build/templates/builder-final-handoff.md start-build/templates/review-packet.md start-build/templates/review-packet-compact.md start-review/templates/review-report.md; do
  assert_file_contains "$file" parent-owned-gate.md "$file parent gate pointer"
done
assert_file_contains issue-delivery-loop/SKILL.md "parent-owned" "delivery-loop parent-owned routing"
assert_file_contains docs/agents/check-gate.md "tests/parent-owned-gate-invariants.sh" "test inventory"
printf '%s\n' "parent-owned-gate-invariants: PASS"
