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

require_text "$gate_doc" 'child records only the parent-owned/not-run contract' 'child gate evidence limited to parent-owned/not-run contract'
require_text "$gate_doc" 'candidate SHA is the only child-provided gate evidence' 'child candidate-SHA-only gate evidence boundary'
require_text "$gate_doc" 'must not claim local gate `PASS`/`FAIL`' 'child must not claim local gate pass/fail'
require_text "$child_doc" 'parent-owned-gate\.md#ownership-contract' 'child points at canonical ownership contract'
require_text "$child_doc" 'do not claim gate pass/fail' 'child pass/fail claim prohibition'
require_text "$child_doc" 'must not mark ready' 'child ready-marking prohibition'
reject_text "$child_doc" 'builder_gate_status\.status:[[:space:]]*not-run' 'duplicated dotted parent-owned gate value definition'

require_text "$parent_doc" 'parent-owned-gate\.md' 'parent points at canonical Gate Receipt seam'
require_text "$gate_doc" 'Parent verification checklist' 'canonical parent verification checklist'
require_text "$gate_doc" 'exact candidate SHA' 'exact-SHA gate binding'
require_text "$gate_doc" 'tracked files changed' 'tracked-file mutation blocker'
require_text "$gate_doc" 'waiver' 'tracked-file waiver escape hatch'
require_text "$gate_doc" 'A single parent ready-transition check is enough' 'single ready-transition check condition'
require_text "$gate_doc" 'Gate coverage is classified as `full-local`, `hybrid`, or `ci-only`' 'parent Gate coverage enum'
require_text "$gate_doc" 'never[[:space:]]+`parent-owned`' 'parent-owned excluded from Gate coverage enum'
require_text "$gate_doc" 'uncovered required CI job' 'parent uncovered CI-only rule'
require_text "$gate_doc" 'wrong-SHA required CI blocks' 'parent wrong-SHA CI blocker'
require_text "$gate_doc" 'result: "PASS"' 'Gate Receipt PASS result binding'

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

# #230 Gate Receipt canonical evidence and delta-sized MR description updates:
# gate_doc must document that the Receipt is canonical and post-receipt updates
# must be delta-only.
require_text "$gate_doc" 'canonical gate evidence' 'Gate Receipt canonical gate evidence statement'
require_text "$gate_doc" 'delta-only' 'delta-only post-receipt MR description update rule'
require_text "$gate_doc" 'Gate Receipt as canonical gate evidence' 'Gate Receipt canonical gate evidence section heading'

# #275 Fail closed on stale Reviewer Lift exact-SHA fields after a revision push.
#
# The post-ready/post-revision refresh contract must name the Gate Receipt
# pointer alongside the other exact-SHA fields (Reviewed SHA, CI pointer, Delta
# since last ready push), and the docs must state that a Gate Receipt bound to an
# older SHA is stale evidence for a new reviewed SHA until a new exact-SHA Gate
# Receipt exists. Without these, a revision push can leave stale exact-SHA Lift /
# Gate Receipt pointers behind and push cleanup onto the reviewer.

# The canonical parent-owned gate seam must declare older-SHA Gate Receipts stale
# for a new reviewed SHA until a new exact-SHA receipt is posted.
require_text "$gate_doc" 'older[[:space:]]+SHA' 'parent-owned gate older-SHA staleness rule'
require_text "$gate_doc" 'stale evidence' 'parent-owned gate stale-evidence statement'
require_text "$gate_doc" 'until a new exact-SHA Gate Receipt' 'parent-owned gate new-receipt freshness condition'
# The seam must require refreshing the Gate Receipt pointer on post-ready pushes
# in parent-owned mode, not only Reviewed SHA / CI.
require_text "$gate_doc" 'Gate Receipt pointer' 'parent-owned gate post-revision Gate Receipt pointer refresh'

# The post-ready push refresh lists in the build flows must name the Gate Receipt
# pointer (parent-owned mode) in addition to Reviewed SHA, CI, and Delta.
impl_flow="start-build/reference/implementation-flow.md"
require_text "$impl_flow" 'Gate Receipt pointer' 'implementation-flow post-ready Gate Receipt pointer refresh'
require_text "$child_doc" 'Gate Receipt pointer' 'child-builder post-ready Gate Receipt pointer refresh'

# The Reviewer Lift schema freshness semantics must name the Gate Receipt pointer
# as one of the exact-SHA fields that goes stale on a push.
require_text "$reviewer_lift" 'Gate Receipt pointer' 'reviewer-lift schema Gate Receipt pointer freshness'

printf 'parent-owned-gate-invariants: PASS\n'
