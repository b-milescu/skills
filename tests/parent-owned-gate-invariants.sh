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
gate_doc="start-build/reference/parent-owned-gate.md"
parent_doc="start-build/reference/parent-orchestrator.md"
review_flow="start-review/REVIEW-FLOW.md"
delivery_schema="start-build/templates/gitlab-delivery-schema.md"
builder_handoff="start-build/templates/builder-final-handoff.md"
reviewer_lift="start-build/templates/reviewer-lift-schema.md"
check_gate_doc="docs/agents/check-gate.md"
gate_card="start-build/reference/parent-owned-gate-card.md"
review_packet="start-build/templates/review-packet.md"
compact_packet="start-build/templates/review-packet-compact.md"
filling_guide="start-build/templates/filling-guide.md"
review_report="start-review/templates/review-report.md"
delivery_loop="issue-delivery-loop/SKILL.md"

require_text "$gate_doc" 'local_gate_owner:[[:space:]]*"parent"' 'canonical parent-owned local gate owner'
require_text "$gate_doc" 'builder_gate_status' 'canonical builder gate status object'
require_text "$gate_doc" 'status:[[:space:]]*"not-run"' 'canonical builder not-run gate status'
require_text "$gate_doc" 'not_run_reason:[[:space:]]*"parent-owned"' 'canonical parent-owned not-run reason'
require_text "$gate_doc" 'ready_transition_owner:[[:space:]]*"parent"' 'canonical ready transition owner'
require_text "$gate_doc" '[Cc]hild builders.*must not claim' 'canonical child pass/fail claim prohibition'
require_text "$gate_doc" 'parent posts the Gate Receipt and marks ready' 'canonical parent ready ownership'
require_text "$gate_doc" 'skill://start-build/reference/parent-owned-gate\.md' 'cross-project skill resource ref'
require_text "$gate_doc" 'docs/agents/check-gate\.md' 'target repo Check Gate ref'

require_text "$child_doc" 'parent-owned-gate\.md#ownership-contract' 'child points at canonical ownership contract'
require_text "$child_doc" 'must not claim gate pass/fail' 'child pass/fail claim prohibition'
require_text "$child_doc" 'must not mark ready' 'child ready-marking prohibition'
reject_text "$child_doc" 'builder_gate_status\.status:[[:space:]]*not-run' 'duplicated dotted parent-owned gate value definition'

require_text "$parent_doc" 'parent-owned-gate\.md' 'parent points at canonical Gate Receipt seam'
require_text "$gate_doc" 'Parent verification checklist' 'canonical parent verification checklist'
require_text "$gate_doc" 'exact candidate SHA' 'exact-SHA gate binding'
require_text "$gate_doc" 'tracked files changed' 'tracked-file mutation blocker'
require_text "$gate_doc" 'waiver' 'tracked-file waiver escape hatch'
require_text "$gate_doc" 'A single parent ready-transition check is enough' 'single ready-transition check condition'

require_text "$gate_doc" 'gate_receipt\.kind=gate-receipt' 'Gate Receipt schema anchor'
require_text "$gate_doc" 'owner' 'Gate Receipt owner field'
require_text "$gate_doc" 'mr_iid' 'Gate Receipt MR IID field'
require_text "$gate_doc" 'issue_iid' 'Gate Receipt issue IID field'
require_text "$gate_doc" 'checkout_path' 'Gate Receipt checkout path field'
require_text "$gate_doc" 'checkout_sha' 'Gate Receipt checkout SHA field'
require_text "$gate_doc" 'status_before' 'Gate Receipt status before field'
require_text "$gate_doc" 'status_after' 'Gate Receipt status after field'
require_text "$gate_doc" 'command' 'Gate Receipt command field'
require_text "$gate_doc" 'result' 'Gate Receipt result field'
require_text "$gate_doc" 'summary' 'Gate Receipt summary field'
require_text "$gate_doc" 'preflight_checks' 'Gate Receipt preflight checks field'
require_text "$gate_doc" 'evidence' 'Gate Receipt evidence field'
require_text "$gate_doc" 'observed_at' 'Gate Receipt optional observation timestamp'
require_text "$gate_doc" 'Evidence-ready handoff tokens' 'Gate Receipt evidence-ready token section'
require_text "$gate_doc" 'gate-receipt-exact-sha-pass' 'exact-SHA pass evidence token'
require_text "$gate_doc" 'ready-transition-post-reread' 'ready transition post-read evidence token'

require_text "$delivery_schema" 'parent-owned-gate\.md' 'delivery schema canonical seam pointer'
require_text "$delivery_schema" 'gate_receipt\.kind=gate-receipt' 'delivery schema receipt anchor pointer'
require_text "$delivery_schema" 'parent-owned' 'parent-owned not_run_reason enum'
reject_text "$delivery_schema" 'parent-owned-final-gate' 'legacy parent-owned-final-gate not_run_reason'

require_text "$reviewer_lift" 'parent-owned-gate\.md' 'Reviewer Lift parent-owned seam pointer'
require_text "$builder_handoff" 'local_gate_owner' 'builder handoff gate owner field'
require_text "$builder_handoff" 'builder_gate_status' 'builder handoff builder gate status field'
require_text "$builder_handoff" 'ready_transition_owner' 'builder handoff ready transition owner field'
require_text "$builder_handoff" 'parent-owned-gate\.md' 'builder handoff canonical seam pointer'
require_text "$review_packet" 'parent-owned-gate\.md' 'review packet canonical seam pointer'
require_text "$compact_packet" 'parent-owned-gate\.md' 'compact review packet canonical seam pointer'
require_text "$filling_guide" 'parent-owned-gate\.md' 'template filling guide canonical seam pointer'

require_text "$child_doc" 'delivery\.handoff_contract' 'child handoff routing contract guidance'
require_text "$builder_handoff" 'handoff_contract' 'builder handoff routing block'
require_text "$parent_doc" 'expected handoff schema' 'parent minimal prompt handoff schema token'
require_text "$parent_doc" 'minimum evidence pointers' 'parent minimal prompt evidence pointer token'
require_text "$delivery_loop" 'parent-owned-gate\.md' 'delivery-loop canonical seam pointer'
require_text "$gate_card" 'parent-owned-gate\.md' 'gate mode card canonical seam pointer'

require_text "$review_flow" 'Gate Receipt' 'reviewer Gate Receipt guidance'
require_text "$review_flow" 'claim/source pointer' 'Gate Receipt claim/source pointer rule'
require_text "$review_flow" 'parent-owned-gate\.md' 'reviewer canonical seam pointer'
require_text "$review_flow" 'safety-critical SHA' 'reviewer safety-critical SHA verification rule'
require_text "$review_flow" 'CI, local gate, and authority' 'reviewer CI/local gate/authority verification rule'
require_text "$review_report" 'parent-owned-gate\.md' 'review report canonical seam pointer'

require_text "$check_gate_doc" 'tests/parent-owned-gate-invariants\.sh' 'check gate inventory entry'

printf 'parent-owned-gate-invariants: PASS\n'
