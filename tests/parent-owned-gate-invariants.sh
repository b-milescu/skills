#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'parent-owned-gate-invariants: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eq -- "$pattern" "$file" || fail "$file missing $label"
}

reject_text() {
  local file="$1" pattern="$2" label="$3"
  if grep -Eq -- "$pattern" "$file"; then
    grep -En -- "$pattern" "$file" >&2 || true
    fail "$file contains $label"
  fi
}

child_doc="start-build/reference/child-builder.md"
parent_doc="start-build/reference/parent-orchestrator.md"
review_flow="start-review/REVIEW-FLOW.md"
delivery_schema="start-build/templates/gitlab-delivery-schema.md"
builder_handoff="start-build/templates/builder-final-handoff.md"
reviewer_lift="start-build/templates/reviewer-lift-schema.md"
check_gate_doc="docs/agents/check-gate.md"

require_text "$child_doc" 'local_gate_owner:[[:space:]]*parent' 'parent-owned local gate contract'
require_text "$child_doc" 'builder_gate_status\.status:[[:space:]]*not-run' 'builder not-run gate status contract'
require_text "$child_doc" 'not_run_reason:[[:space:]]*parent-owned' 'parent-owned not-run reason'
require_text "$child_doc" 'ready_transition_owner:[[:space:]]*parent' 'parent-owned ready transition contract'
require_text "$child_doc" 'must not claim gate pass/fail' 'child pass/fail claim prohibition'
require_text "$child_doc" 'must not mark ready' 'child ready-marking prohibition'

require_text "$parent_doc" 'gate_receipt\.kind=gate-receipt' 'parent Gate Receipt posting contract'
require_text "$parent_doc" 'exact SHA' 'exact-SHA gate binding'
require_text "$parent_doc" 'tracked files changed' 'tracked-file mutation blocker'
require_text "$parent_doc" 'waiver' 'tracked-file waiver escape hatch'

require_text "$delivery_schema" 'gate_receipt\.kind=gate-receipt' 'Gate Receipt schema anchor'
require_text "$delivery_schema" 'owner' 'Gate Receipt owner field'
require_text "$delivery_schema" 'mr_iid' 'Gate Receipt MR IID field'
require_text "$delivery_schema" 'issue_iid' 'Gate Receipt issue IID field'
require_text "$delivery_schema" 'checkout_path' 'Gate Receipt checkout path field'
require_text "$delivery_schema" 'checkout_sha' 'Gate Receipt checkout SHA field'
require_text "$delivery_schema" 'status_before' 'Gate Receipt status before field'
require_text "$delivery_schema" 'status_after' 'Gate Receipt status after field'
require_text "$delivery_schema" 'command' 'Gate Receipt command field'
require_text "$delivery_schema" 'result' 'Gate Receipt result field'
require_text "$delivery_schema" 'summary' 'Gate Receipt summary field'
require_text "$delivery_schema" 'preflight_checks' 'Gate Receipt preflight checks field'
require_text "$delivery_schema" 'evidence' 'Gate Receipt evidence field'
require_text "$delivery_schema" 'observed_at' 'Gate Receipt optional observation timestamp'
require_text "$delivery_schema" 'parent-owned' 'parent-owned not_run_reason enum'
reject_text "$delivery_schema" 'parent-owned-final-gate' 'legacy parent-owned-final-gate not_run_reason'

require_text "$reviewer_lift" 'not-run' 'Reviewer Lift local gate not-run status'
require_text "$builder_handoff" 'local_gate_owner' 'builder handoff gate owner field'
require_text "$builder_handoff" 'builder_gate_status' 'builder handoff builder gate status field'
require_text "$builder_handoff" 'ready_transition_owner' 'builder handoff ready transition owner field'

require_text "$review_flow" 'Gate Receipt' 'reviewer Gate Receipt guidance'
require_text "$review_flow" 'claim/source pointer' 'Gate Receipt claim/source pointer rule'
require_text "$review_flow" 'safety-critical SHA' 'reviewer safety-critical SHA verification rule'
require_text "$review_flow" 'CI, local gate, and authority' 'reviewer CI/local gate/authority verification rule'

require_text "$check_gate_doc" 'tests/parent-owned-gate-invariants\.sh' 'check gate inventory entry'

printf 'parent-owned-gate-invariants: PASS\n'
