#!/usr/bin/env bash
# Table-driven collapse of the token-grep farm and five *-invariants.sh
# scripts. Needles stay; per-script fail/require wrappers go.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"
TEST_NAME=token-grep-invariants
# shellcheck source=tests/lib/assertions.sh
source "$REPO_ROOT/tests/lib/assertions.sh"
# shellcheck source=tests/lib/agent-prompt-sets.sh
source "$REPO_ROOT/tests/lib/agent-prompt-sets.sh"

require_row() {
  local file="$1" row="$2"
  grep -Eq -- "^\|[[:space:]]*${row}[[:space:]]*\|" "$file" || fail "$file missing capsule row: $row"
}

assert_fixed_absent() {
  local file="$1" needle="$2"
  if grep -Fq -- "$needle" "$file"; then
    fail "$file contains forbidden: $needle"
  fi
}

offset_of() {
  local file="$1" pattern="$2" label="$3" offset
  offset="$(LC_ALL=C grep -Eibom1 -- "$pattern" "$file" | cut -d: -f1 || true)"
  [[ -n "$offset" ]] || fail "$file missing ordered text: $label"
  printf '%s' "$offset"
}

extract_section() {
  local file="$1" heading="$2"
  awk -v heading="$heading" '
    $0 == "## " heading { in_section=1; next }
    in_section && /^##[[:space:]]+/ { exit }
    in_section { print }
  ' "$file"
}

# --- token table: kind|file|needle ---
# contain = fixed string present; absent = fixed string forbidden
# re = case-insensitive regex present; nre = case-insensitive regex forbidden
while IFS='|' read -r kind file needle; do
  [[ -n "${kind:-}" && "$kind" != \#* ]] || continue
  case "$kind" in
    contain) assert_file_contains "$file" "$needle" ;;
    absent) assert_fixed_absent "$file" "$needle" ;;
    re) require_text "$file" "$needle" "$needle" ;;
    nre) reject_text "$file" "$needle" "$needle" ;;
    *) fail "unknown table kind: $kind" ;;
  esac
done <<'TABLE'
# safety-floor-tokens
re|forge/reference/common-guard.md|reviewed commit binding
re|forge/reference/common-guard.md|advisory CI observation.*absence, failure, or a binding mismatch is recorded and does not fail the guard
re|forge/reference/common-guard.md|action-specific authority and provenance
re|forge/reference/common-guard.md|exactly one mutation
re|forge/reference/common-guard.md|provider-native post-mutation re-read
re|forge/reference/common-guard.md|blocks without transport fallback
re|start-build/SKILL.md|advisory CI observation
re|start-build/SKILL.md|fresh independent reviewer
re|start-build/SKILL.md|child/parent/reviewer/verifier
re|start-build/SKILL.md|authority guards
re|start-build/SKILL.md|Post-merge
re|start-build/SKILL.md|verification is read-only
re|start-review/REVIEW-FLOW.md|gate-eligible reviewer is fresh
re|start-review/REVIEW-FLOW.md|exact reviewed commit
re|start-review/REVIEW-FLOW.md|commit-bound CI observation
re|start-review/SKILL.md|verdict, approval, finish, action blocker, and next action separate
re|start-review/REVIEW-FLOW.md|Fail-closed review coverage
re|start-review/SKILL.md|Post-merge verification is a
re|start-review/SKILL.md|separate read-only actor
re|issue-delivery-loop/SKILL.md|skill://start-build/reference/parent-orchestrator.md
re|issue-delivery-loop/SKILL.md|independent review
re|issue-delivery-loop/SKILL.md|child/reviewer/verifier boundaries
re|issue-delivery-loop/SKILL.md|provider-native post-read
re|start-build/reference/parent-orchestrator.md|child builders do not spawn reviewers, approve, finish
re|start-build/reference/parent-orchestrator.md|post-merge verifiers stay read-only
# start-build-secret-invariant
re|start-build/SAFETY.md|never paste secrets
re|start-build/SAFETY.md|don't read, print, edit, commit|don't log api keys
re|start-build/SAFETY.md|token-bearing config
re|start-build/SAFETY.md|read[^.]*variable[^.]*without printing|without printing[^.]*variable
re|start-build/reference/child-builder.md|never[^.]*cat[^.]*echo[^.]*token-bearing config
re|start-build/reference/child-builder.md|read[^.]*variable[^.]*without printing|read[^.]*shell variable[^.]*without printing
re|start-build/reference/child-builder.md|redact[^.]*\[REDACTED\]
# start-build-bypass-wording
absent|start-build/reference/standalone-gate.md|or equivalent explicit override
contain|start-build/reference/standalone-gate.md|accepted bypass phrase
contain|start-build/reference/standalone-gate.md|"skip gate"
contain|start-build/reference/standalone-gate.md|"merge unreviewed"
contain|start-build/reference/standalone-gate.md|Ambiguous release language
contain|start-build/reference/standalone-gate.md|does not bypass
contain|start-build/reference/standalone-gate.md|must be clarified
contain|start-build/reference/standalone-gate.md|ship it
contain|start-build/reference/standalone-gate.md|looks fine
contain|start-build/reference/standalone-gate.md|lgtm
contain|start-build/reference/standalone-gate.md|named human
contain|start-build/reference/standalone-gate.md|reason
contain|start-build/reference/standalone-gate.md|bypassed (human override)
contain|start-build/reference/standalone-gate.md|provider-published audit locator
contain|start-build/reference/standalone-gate.md|self-approval
contain|start-build/SAFETY.md|reference/standalone-gate.md#human-bypass-protocol
absent|start-build/SAFETY.md|accepted bypass phrase
contain|start-build/SAFETY.md|self-approval
# start-build-child-path-size tokens
contain|start-build/reference/child-builder.md|parent orchestrator owns the mandatory review gate
contain|start-build/reference/child-builder.md|must not start a reviewer
absent|start-build/reference/child-builder.md|subagent({ action: "list" })
contain|start-build/SKILL.md|skill://start-build/reference/child-builder.md
# handoff-token-validator-wiring (retired scripts; parents read forge snapshot)
contain|start-build/reference/child-builder.md|validate-finding-bindings.mjs
contain|start-review/REVIEW-FLOW.md|two-line final handoff
# start-build-context-read-matrix
re|start-build/SKILL.md|^## Invocation modes$
re|start-build/SKILL.md|\*\*Standalone:\*\*
re|start-build/SKILL.md|\*\*Child `mr-builder`:\*\*
re|start-build/SKILL.md|active mode reference
re|start-build/SKILL.md|skill://start-build/reference/child-builder.md
re|start-build/reference/context-and-planning.md|Read the issue and project rulebook index first
re|start-build/reference/context-and-planning.md|expand only from evidence
re|start-build/reference/context-and-planning.md|Stop expanding once those facts are evidence-backed
re|start-build/reference/context-and-planning.md|instead of guessing requirements or starting edits
re|start-build/reference/context-and-planning.md|active mode-specific flow
re|start-build/reference/context-and-planning.md|child-builder.md
re|start-build/reference/context-and-planning.md|standalone-gate.md
re|start-build/reference/context-and-planning.md|parent-orchestrator.md
re|start-build/reference/context-and-planning.md|compact invocation-mode procedure
re|start-build/reference/issue-pickup.md|read its description and all current discussion before planning or editing
re|start-build/reference/issue-pickup.md|source precedence
re|start-build/reference/issue-pickup.md|human escalation
re|start-build/reference/child-builder.md|parent orchestrator owns the mandatory review gate
re|start-build/reference/child-builder.md|must not start a reviewer
# start-build-discovery-budget pointers
contain|start-build/SKILL.md|skill://start-build/reference/context-and-planning.md
contain|start-build/SKILL.md|skill://start-build/templates/build-plan-packet.md
contain|start-build/SKILL.md|parent owns Gate Receipt and ready
contain|start-build/templates/build-plan-packet.md|## Issue
contain|start-build/templates/build-plan-packet.md|## Intended behavior
contain|start-build/templates/build-plan-packet.md|## Loaded context sources
contain|start-build/templates/build-plan-packet.md|## Affected surfaces
contain|start-build/templates/build-plan-packet.md|## Test plan
contain|start-build/templates/build-plan-packet.md|## Risk
contain|start-build/templates/build-plan-packet.md|## Non-goals
contain|start-build/templates/build-plan-packet.md|why relevant
# start-build-done-criteria
contain|start-build/SKILL.md|skill://start-build/SAFETY.md#done-criteria
contain|start-build/SKILL.md|Done is mode-tiered
contain|start-build/SKILL.md|Builder-owned mode runs the project Check Gate
contain|start-build/SKILL.md|Parent-owned mode records `not-run —
contain|start-build/SKILL.md|leaves Draft
contain|start-build/SKILL.md|hands the candidate to the parent
absent|start-build/SAFETY.md|builder may self-approve
absent|start-build/SAFETY.md|builder may merge its own
# start-build-simplicity-bar
contain|start-build/SAFETY.md|Simplest version of your own change.
contain|start-build/SAFETY.md|within the lines your diff introduces or touches
contain|start-build/SAFETY.md|treat it as surrounding code
contain|start-build/SAFETY.md|Open a separate issue.
absent|start-build/SAFETY.md|cursor/plugins
absent|start-build/SAFETY.md|Measure twice, cut once.
absent|start-build/SKILL.md|cursor/plugins
absent|start-build/SKILL.md|Measure twice, cut once.
# start-build-stale-reviewer-control
contain|start-build/reference/timeout-handling.md|runtime's status/control/interruption mechanism
contain|start-build/reference/timeout-handling.md|escalate instead of launching a duplicate reviewer
contain|start-build/reference/timeout-handling.md|Record the reason before any second reviewer attempt
contain|start-build/reference/timeout-handling.md|failed, stale, interrupted, or unreachable
contain|start-build/reference/timeout-handling.md|still active
contain|start-build/reference/standalone-gate.md|No fixed wall-clock value alone authorizes replacement
contain|start-build/reference/standalone-gate.md|timeout / stale / interrupted are non-completion states
contain|start-build/reference/standalone-gate.md|pass / request-changes / reject / blocked / timeout / stale / interrupted
absent|start-build/reference/standalone-gate.md|approve / request-changes / reject / timeout / stale / interrupted
contain|start-build/reference/parent-orchestrator.md|check the reviewer run status/activity before replacement
contain|start-build/reference/parent-orchestrator.md|Do not start a second reviewer while the first run is still active
contain|start-build/reference/parent-orchestrator.md|escalate instead of launching a duplicate reviewer
absent|start-build/reference/standalone-gate.md|within 10 minutes
absent|start-build/reference/standalone-gate.md|Timeout: 10 minutes per round
absent|start-build/reference/standalone-gate.md|try one fresh reviewer session, then escalate
absent|start-build/reference/standalone-gate.md|Start one fresh reviewer session with the same task prompt
absent|start-build/reference/timeout-handling.md|within 10 minutes
absent|start-build/reference/timeout-handling.md|Timeout: 10 minutes per round
absent|start-build/reference/timeout-handling.md|try one fresh reviewer session, then escalate
absent|start-build/reference/timeout-handling.md|Start one fresh reviewer session with the same task prompt
absent|start-build/reference/parent-orchestrator.md|within 10 minutes
absent|start-build/reference/parent-orchestrator.md|Timeout: 10 minutes per round
absent|start-build/reference/parent-orchestrator.md|try one fresh reviewer session, then escalate
absent|start-build/reference/parent-orchestrator.md|Start one fresh reviewer session with the same task prompt
# start-build-tdd-trigger-policy
contain|start-build/SKILL.md|Behavior-changing work follows `tdd`: one observable RED→GREEN slice at a time.
contain|start-build/SKILL.md|Docs/config/mechanical work records `TDD: N/A — <reason>` rather than fake tests.
absent|start-build/SKILL.md|For runtime/operator/safety behavior changes, load and follow the `tdd` skill.
contain|start-build/reference/child-builder.md|Behavior-touching implementation follows TDD unless impossible or explicitly N/A with rationale in the change request.
contain|start-build/reference/implementation-flow.md|Behavior-touching implementation follows TDD unless impossible or explicitly N/A with rationale in the change request.
contain|start-build/reference/child-builder.md|Runtime/operator/safety changes are examples of behavior-touching implementation, not a narrower TDD trigger.
contain|start-build/reference/implementation-flow.md|Runtime/operator/safety changes are examples of behavior-touching implementation, not a narrower TDD trigger.
contain|start-build/reference/child-builder.md|Exception categories require a recorded rationale and must not allow fake tests or meaningless checks.
contain|start-build/reference/implementation-flow.md|Exception categories require a recorded rationale and must not allow fake tests or meaningless checks.
contain|start-build/reference/child-builder.md|Work-item-driven work with sufficient acceptance criteria does not need a separate user-approval prompt before the first TDD slice.
contain|start-build/reference/implementation-flow.md|Work-item-driven work with sufficient acceptance criteria does not need a separate user-approval prompt before the first TDD slice.
contain|start-build/reference/child-builder.md|Missing or ambiguous behavior scope still routes back to triage with exact unanswered questions.
contain|start-build/reference/implementation-flow.md|Missing or ambiguous behavior scope still routes back to triage with exact unanswered questions.
contain|start-build/templates/reviewer-lift-schema.md|behavior-touching implementation
contain|start-build/templates/review-packet.md|behavior-touching implementation
contain|start-build/templates/review-packet-compact.md|behavior-touching implementation
contain|start-review/templates/review-report.md|behavior-touching implementation
contain|start-build/templates/reviewer-lift-schema.md|N/A with rationale
contain|start-build/templates/review-packet.md|N/A with rationale
contain|start-build/templates/review-packet-compact.md|N/A with rationale
contain|start-review/templates/review-report.md|N/A with rationale
contain|start-build/templates/reviewer-lift-schema.md|do not fake tests
contain|start-build/templates/review-packet.md|do not fake tests
contain|start-build/templates/review-packet-compact.md|do not fake tests
contain|start-review/templates/review-report.md|do not fake tests
contain|start-build/SAFETY.md|For behavior-touching work, each headline claim in the MR body must name the mutation that kills its defending assertion.
contain|start-build/SAFETY.md|This is scoped to headline claims, not every assertion; do not run a full mutation battery per MR.
contain|start-build/SAFETY.md|An assertion whose subject cannot be changed by any mutation of the code under test—for example, when no mock can move the observed state—is structurally incapable of failing and is not regression evidence.
contain|start-build/SAFETY.md|A named killing mutation counts as evidence only when the harness proves the substitution applied by asserting its anchor matched exactly once before checking the result.
contain|start-build/SAFETY.md|The observed failure message must match the guard under test; a non-zero exit alone cannot distinguish a fired guard from a parse or setup error.
# start-build-ready-gate-push-semantics
contain|start-build/SAFETY.md|The exact-candidate local Check Gate is the quality gate before ready/review.
contain|start-build/reference/implementation-flow.md|**Early Draft change-request push.**
contain|start-build/reference/implementation-flow.md|**Implementation pushes before ready.**
contain|start-build/reference/implementation-flow.md|**Ready-marking gate.**
contain|start-build/reference/implementation-flow.md|**Exact-candidate local coverage.**
contain|start-build/reference/implementation-flow.md|**Builder-owned gate mode.**
contain|start-build/reference/implementation-flow.md|**Parent-owned gate mode.**
contain|start-build/reference/implementation-flow.md|**Advisory CI observation.**
contain|start-build/reference/implementation-flow.md|**Post-ready push protocol.**
contain|start-build/reference/implementation-flow.md|does not apply to early Draft change-request creation or pre-ready implementation pushes
contain|start-build/reference/implementation-flow.md|`Gate coverage` to `exact-candidate-local`
contain|issue-delivery-loop/SKILL.md|Provider CI may run in parallel
contain|start-build/reference/parent-orchestrator.md|Provider CI may run in parallel
contain|start-build/reference/implementation-flow.md|never changes review, approval, or finish eligibility
contain|start-build/reference/parent-owned-gate.md|exact candidate plus a passing parent Gate Receipt is sufficient to mark
contain|start-build/reference/parent-owned-gate.md|Provider CI is advisory
contain|start-build/reference/implementation-flow.md|re-bind evidence after every push
contain|start-build/reference/implementation-flow.md|child records `Gate owner: parent`, the parent-owned/not-run contract, and candidate commit only
contain|start-build/templates/reviewer-lift-schema.md|| Gate owner |
contain|start-build/templates/reviewer-lift-schema.md|| Gate coverage |
contain|start-build/templates/reviewer-lift-schema.md|| Gate coverage rationale |
contain|start-build/templates/reviewer-lift-schema.md|never changes verdict or action eligibility
contain|start-build/templates/reviewer-lift-schema.md|after any post-ready push, include old SHA → new SHA, reason, changed files, gate rerun, and whether the change is substantive
# start-review-command-ownership
re|start-review/SKILL.md|forge preflight
re|start-review/SKILL.md|forge snapshot
re|start-review/SKILL.md|provider
re|start-review/SKILL.md|fail(s|ed)? closed|blocks?|Stop on ambiguity
re|start-review/SKILL.md|provider-native (post-)?readback|provider-native post-read
re|start-review/SKILL.md|reviewed commit|reviewed-commit
re|start-review/REVIEW-FLOW.md|forge preflight
re|start-review/REVIEW-FLOW.md|forge snapshot
re|start-review/REVIEW-FLOW.md|provider
re|start-review/REVIEW-FLOW.md|fail(s|ed)? closed|blocks?|Stop on ambiguity
re|start-review/REVIEW-FLOW.md|provider-native (post-)?readback|provider-native post-read
re|start-review/REVIEW-FLOW.md|reviewed commit|reviewed-commit
re|start-review/SKILL.md|ordered common
re|start-review/SKILL.md|forge post_merge_snapshot
re|start-review/SKILL.md|separate read-only actor
re|start-review/REVIEW-FLOW.md|provider-proven
re|start-review/REVIEW-FLOW.md|selected `/forge`
re|start-review/REVIEW-FLOW.md|provider reference
# start-review-project-binding
re|start-review/REVIEW-FLOW.md|canonical repository
re|start-review/REVIEW-FLOW.md|default
re|start-review/REVIEW-FLOW.md|branch, opaque change-request
re|start-review/REVIEW-FLOW.md|opaque change-request
re|start-review/REVIEW-FLOW.md|identifier/locator
re|start-review/REVIEW-FLOW.md|source/target
re|start-review/REVIEW-FLOW.md|current commit
re|start-review/REVIEW-FLOW.md|caller identity
re|start-review/REVIEW-FLOW.md|before snapshot, publication, or
re|start-review/REVIEW-FLOW.md|action
re|start-review/REVIEW-FLOW.md|Ambiguity, profile mismatch, or a bare cross-repository identifier
re|start-review/REVIEW-FLOW.md|fail(s|ed) closed|blocks
re|start-review/SKILL.md|canonical repository
re|start-review/SKILL.md|default
re|start-review/SKILL.md|branch, opaque change-request
re|start-review/SKILL.md|opaque change-request
re|start-review/SKILL.md|identifier/locator
re|start-review/SKILL.md|source/target
re|start-review/SKILL.md|current commit
re|start-review/SKILL.md|caller identity
re|start-review/SKILL.md|before snapshot, publication, or
re|start-review/SKILL.md|action
re|start-review/SKILL.md|Ambiguity, profile mismatch, or a bare cross-repository identifier
re|start-review/SKILL.md|fail(s|ed) closed|blocks
re|start-review/REVIEW-FLOW.md|Local checkout, remote source, Reviewer Lift reviewed commit
re|start-review/REVIEW-FLOW.md|Gate Receipt candidate must agree
re|start-review/REVIEW-FLOW.md|Missing, stale, wrong-commit
re|start-review/templates/review-report.md|^\| Change request \|
re|start-review/templates/review-report.md|^\| Repository \|
re|start-review/templates/review-report.md|^\| Reviewed commit \|
re|start-review/templates/reviewer-final-handoff.md|Change-request locator:
re|start-review/templates/reviewer-final-handoff.md|Durable note id:
re|start-review/templates/reviewer-final-handoff.md|Review Report note id
nre|start-review/REVIEW-FLOW.md|(glab|gh)[[:space:]]+(mr|pr|issue)[[:space:]]+(view|comment|approve|merge|close)[[:space:]]+<id>([[:space:]`]|$)
nre|start-review/SKILL.md|(glab|gh)[[:space:]]+(mr|pr|issue)[[:space:]]+(view|comment|approve|merge|close)[[:space:]]+<id>([[:space:]`]|$)
nre|start-review/templates/filling-guide.md|(glab|gh)[[:space:]]+(mr|pr|issue)[[:space:]]+(view|comment|approve|merge|close)[[:space:]]+<id>([[:space:]`]|$)
nre|start-review/REVIEW-FLOW.md|az[[:space:]]+repos[[:space:]]+pr[[:space:]]+(show|update)[^\n]*--id[[:space:]]+<id>
nre|start-review/SKILL.md|az[[:space:]]+repos[[:space:]]+pr[[:space:]]+(show|update)[^\n]*--id[[:space:]]+<id>
nre|start-review/templates/filling-guide.md|az[[:space:]]+repos[[:space:]]+pr[[:space:]]+(show|update)[^\n]*--id[[:space:]]+<id>
# review-authority-explicit
contain|start-review/REVIEW-FLOW.md|Approval authority
contain|start-review/SKILL.md|Approval authority
contain|start-review/templates/review-report.md|Approval authority
contain|start-review/templates/filling-guide.md|Approval authority
contain|start-review/REVIEW-FLOW.md|Finish authority
contain|start-review/SKILL.md|Finish authority
contain|start-review/templates/review-report.md|Finish authority
contain|start-review/templates/filling-guide.md|Finish authority
contain|start-review/REVIEW-FLOW.md|default-after-pass
contain|start-review/SKILL.md|default-after-pass
contain|start-review/templates/review-report.md|default-after-pass
contain|start-review/templates/filling-guide.md|default-after-pass
absent|start-review/REVIEW-FLOW.md|Merge authority
absent|start-review/SKILL.md|Merge authority
absent|start-review/templates/review-report.md|Merge authority
absent|start-review/templates/filling-guide.md|Merge authority
absent|start-review/REVIEW-FLOW.md|bound MR
absent|start-review/SKILL.md|bound MR
absent|start-review/templates/review-report.md|bound MR
absent|start-review/templates/filling-guide.md|bound MR
absent|start-review/REVIEW-FLOW.md|GitLab Review Report
absent|start-review/SKILL.md|GitLab Review Report
absent|start-review/templates/review-report.md|GitLab Review Report
absent|start-review/templates/filling-guide.md|GitLab Review Report
contain|start-review/REVIEW-FLOW.md|stable repository policy
contain|start-review/REVIEW-FLOW.md|Missing Finish authority blocks only
contain|start-review/REVIEW-FLOW.md|never judgment or independently permitted approval
contain|start-review/REVIEW-FLOW.md|Silence never becomes `approval-only`
contain|start-review/REVIEW-FLOW.md|Finish owner: parent
contain|start-review/REVIEW-FLOW.md|not-approved
contain|start-review/REVIEW-FLOW.md|finish `none`
contain|start-review/REVIEW-FLOW.md|forge publish
contain|forge/reference/common-guard.md|Authority Verification
contain|start-review/SKILL.md|Reviewer Lift row
contain|forge/reference/gitlab.md|gitlab/reference/authority-verification.md
contain|gitlab/reference/authority-verification.md|Finish owner: parent
contain|start-build/reference/parent-orchestrator.md|Finish owner: parent
contain|issue-delivery-loop/SKILL.md|Finish owner: parent
contain|start-build/reference/parent-orchestrator.md|parent
contain|issue-delivery-loop/SKILL.md|parent
# review-authority-provenance
contain|start-build/templates/reviewer-lift-schema.md|| Approval authority |
contain|start-build/templates/reviewer-lift-schema.md|| Approval authority source |
contain|start-build/templates/reviewer-lift-schema.md|| Finish authority |
contain|start-build/templates/reviewer-lift-schema.md|| Finish authority source |
contain|start-build/templates/review-packet.md|| Approval authority |
contain|start-build/templates/review-packet.md|| Approval authority source |
contain|start-build/templates/review-packet.md|| Finish authority |
contain|start-build/templates/review-packet.md|| Finish authority source |
contain|start-build/templates/review-packet-compact.md|| Approval authority |
contain|start-build/templates/review-packet-compact.md|| Approval authority source |
contain|start-build/templates/review-packet-compact.md|| Finish authority |
contain|start-build/templates/review-packet-compact.md|| Finish authority source |
contain|start-review/templates/review-report.md|| Approval authority |
contain|start-review/templates/review-report.md|| Approval authority source |
contain|start-review/templates/review-report.md|| Finish authority |
contain|start-review/templates/review-report.md|| Finish authority source |
absent|start-build/templates/review-packet.md|| Merge authority
absent|start-build/templates/review-packet-compact.md|| Merge authority
absent|start-review/templates/review-report.md|| Merge authority
contain|start-review/REVIEW-FLOW.md|source
contain|start-review/SKILL.md|source
contain|start-review/templates/filling-guide.md|source
contain|start-review/REVIEW-FLOW.md|Explicit human/provider restrictions precede defaults
contain|forge/reference/common-guard.md|take precedence
contain|start-build/reference/child-builder.md|Finish authority
contain|start-build/reference/context-and-planning.md|Finish authority
contain|start-build/templates/filling-guide.md|Finish authority
contain|start-build/reference/child-builder.md|source
contain|start-build/reference/context-and-planning.md|source
contain|start-build/templates/filling-guide.md|source
absent|start-build/reference/child-builder.md|Merge authority
absent|start-build/reference/context-and-planning.md|Merge authority
absent|start-build/templates/filling-guide.md|Merge authority
contain|start-build/reference/child-builder.md|builders cannot grant authority
contain|start-build/reference/context-and-planning.md|not a builder grant
contain|start-build/templates/filling-guide.md|Do not write builder-local interpretation as authority
contain|start-build/templates/builder-final-handoff.md|Authority Verification
contain|start-review/templates/reviewer-final-handoff.md|Authority Verification
# review-blocked-verdict tokens
contain|start-review/SKILL.md|Keep verdict, approval, finish, action blocker, and next action separate
contain|start-review/REVIEW-FLOW.md|human-decision-needed
contain|start-review/templates/review-report.md|do not disguise it as a Must Fix
contain|start-review/templates/review-report.md|revision-ready
contain|start-review/templates/review-report.md|bounded remedy direction
contain|start-review/templates/filling-guide.md|revision-ready
contain|start-review/templates/filling-guide.md|bounded remedy direction
contain|start-review/templates/reviewer-final-handoff.md|review_verdict:
contain|start-review/templates/reviewer-final-handoff.md|action_blocker:
contain|start-review/templates/review-report.md|| Review verdict |
contain|start-review/templates/review-report.md|| Approval action |
contain|start-review/templates/review-report.md|| Finish action |
contain|start-review/templates/review-report.md|| Action blocker |
contain|start-review/templates/review-report.md|| Next action |
# review-ci-oq-decision-tables
contain|start-review/REVIEW-FLOW.md|## CI and Open Question decision tables
contain|start-review/REVIEW-FLOW.md|Observed CI classification
contain|start-review/REVIEW-FLOW.md|bound success
contain|start-review/REVIEW-FLOW.md|bound pending/running
contain|start-review/REVIEW-FLOW.md|bound failed/canceled/skipped
contain|start-review/REVIEW-FLOW.md|unavailable or missing
contain|start-review/REVIEW-FLOW.md|stale, wrong-commit, incomplete, or unknown binding
contain|start-review/REVIEW-FLOW.md|Every classification is advisory.
contain|start-review/REVIEW-FLOW.md|No provider CI status changes the review
contain|start-review/REVIEW-FLOW.md|required quality predicate is a passing exact-candidate local Check Gate
contain|start-review/REVIEW-FLOW.md|Independent review
contain|start-review/REVIEW-FLOW.md|authority/caller guards
contain|start-review/REVIEW-FLOW.md|exactly one mutation
contain|start-review/REVIEW-FLOW.md|Native provider protection may refuse a mutation
contain|start-review/REVIEW-FLOW.md|answered from evidence
contain|start-review/REVIEW-FLOW.md|no blocker
contain|start-review/REVIEW-FLOW.md|builder evidence gap
contain|start-review/REVIEW-FLOW.md|`request-changes` with a bounded remedy
contain|start-review/REVIEW-FLOW.md|human/product/security decision
contain|start-review/REVIEW-FLOW.md|`blocked`; no approval
contain|start-review/REVIEW-FLOW.md|non-blocking
contain|start-review/REVIEW-FLOW.md|`C-N`, follow-up, or recorded rationale
contain|start-review/SKILL.md|REVIEW-FLOW.md
contain|start-review/templates/filling-guide.md|CI and Open Question decision tables
# review-context-policy
re|start-build/templates/delivery-schema.md|^## Trust and evidence tiers$
re|start-build/templates/delivery-schema.md|Tier 1[^|]*\|[[:space:]]*Provider-native decision-grade
re|start-build/templates/delivery-schema.md|Tier 2[^|]*\|[[:space:]]*Repository policy/source/tests
re|start-build/templates/delivery-schema.md|Tier 3[^|]*\|[[:space:]]*Unverified routing index
re|start-build/templates/delivery-schema.md|`routing index` is the canonical term for unverified handoff data
re|start-build/templates/delivery-schema.md|rebind it to[[:space:]]*Tier 1 or Tier 2 evidence before action
re|start-build/templates/delivery-schema.md|Artifacts count as evidence only through their verified source and readback
re|start-review/REVIEW-FLOW.md|^## Context Firewall$
re|start-review/REVIEW-FLOW.md|Parent/builder reasoning
re|start-review/REVIEW-FLOW.md|claims or maps, not evidence
re|start-review/REVIEW-FLOW.md|`rerun-review` from a fresh context
re|start-review/REVIEW-FLOW.md|^## Review Context Capsule$
re|start-review/REVIEW-FLOW.md|claim[^.]*reviewer verification[^.]*source
re|start-review/REVIEW-FLOW.md|Tier 1 — required reads
re|start-review/REVIEW-FLOW.md|bounded provider-native decision-grade evidence
re|start-review/REVIEW-FLOW.md|Tier 2 — risk-triggered reads
re|start-review/REVIEW-FLOW.md|bounded repository policy
re|start-review/REVIEW-FLOW.md|Tier 3 — forbidden-by-default broad context
re|start-review/REVIEW-FLOW.md|whole-repository reading
re|start-review/REVIEW-FLOW.md|Reviewer Lift[^.]*map[^.]*not proof|maps, not proof
re|start-review/templates/review-report.md|Reviewer Lift[^.]*map[^.]*not proof|maps, not proof
re|start-review/templates/filling-guide.md|Reviewer Lift[^.]*map[^.]*not proof|maps, not proof
re|start-review/REVIEW-FLOW.md|safety-critical
re|start-review/templates/review-report.md|safety-critical
re|start-review/templates/filling-guide.md|safety-critical
re|start-review/REVIEW-FLOW.md|verification
re|start-review/templates/review-report.md|verification
re|start-review/templates/filling-guide.md|verification
re|start-review/REVIEW-FLOW.md|source
re|start-review/templates/review-report.md|source
re|start-review/templates/filling-guide.md|source
re|start-build/reference/standalone-gate.md|Change request locator[^.]*Reviewer Lift pointer[^.]*project rulebook path
re|start-build/reference/standalone-gate.md|Invoke `start-review` and `forge` through the Skill tool
# review-one-mr-per-reviewer
re|start-review/SKILL.md|one change
re|start-review/REVIEW-FLOW.md|one change
re|start-review/SKILL.md|request per fresh reviewer session
re|start-review/REVIEW-FLOW.md|request per fresh reviewer session
nre|start-review/SKILL.md|batch-approve|batch approve|batch-approval|batch approval
nre|start-review/REVIEW-FLOW.md|batch-approve|batch approve|batch-approval|batch approval
re|start-review/REVIEW-FLOW.md|parent/harness proves the Decoupling
re|start-review/REVIEW-FLOW.md|each change request
re|start-review/REVIEW-FLOW.md|own isolated checkout and fresh
re|start-review/REVIEW-FLOW.md|never batches decisions, comments, or actions
re|start-review/REVIEW-FLOW.md|git rev-parse HEAD[^.]*exact reviewed commit
re|start-review/REVIEW-FLOW.md|one durable non-blocking report
re|start-review/templates/review-report.md|^# Review Report$
re|start-review/templates/review-report.md|Review verdict
re|start-review/templates/reviewer-final-handoff.md|^# Reviewer Final Handoff$
re|start-review/templates/reviewer-final-handoff.md|review_verdict
# review-partial-secret-fail-closed
re|start-review/REVIEW-FLOW.md|partial-review
re|start-review/REVIEW-FLOW.md|cannot inspect all behavior-affecting changed surfaces
re|start-review/REVIEW-FLOW.md|no partial approval|never partially approve
re|start-review/REVIEW-FLOW.md|diff unavailable
re|start-review/REVIEW-FLOW.md|too large for bounded review
re|start-review/REVIEW-FLOW.md|binary/generated artifact without provenance
re|start-review/REVIEW-FLOW.md|hidden dependencies
re|start-review/REVIEW-FLOW.md|missing linked issue/context.*affecting behavior
re|start-review/REVIEW-FLOW.md|tool limits before decision
re|start-review/REVIEW-FLOW.md|request split|request a split
re|start-review/REVIEW-FLOW.md|secret-exposure-suspected
re|start-review/REVIEW-FLOW.md|do not quote.*(secret|credential)|never quote.*(secret|credential)
re|start-review/REVIEW-FLOW.md|redact.*(Review Report|report)
re|start-review/REVIEW-FLOW.md|block.*approval|approval.*block
re|start-review/REVIEW-FLOW.md|remov.*rotat.*purg|rotat.*remov.*purg
re|start-review/REVIEW-FLOW.md|human security escalation|security escalation
re|start-review/REVIEW-FLOW.md|per project policy
re|start-review/templates/review-report.md|partial-review
re|start-review/templates/review-report.md|secret-exposure-suspected
re|start-review/templates/reviewer-final-handoff.md|partial-review
re|start-review/templates/reviewer-final-handoff.md|secret-exposure-suspected
re|start-review/SKILL.md|partial-review
re|start-review/SKILL.md|secret-exposure-suspected
re|start-review/templates/filling-guide.md|do not quote.*(secret|credential)|never quote.*(secret|credential)
re|start-review/templates/filling-guide.md|\[REDACTED\]|redacted
re|start-review/templates/filling-guide.md|without (copying|including) (the )?(sensitive )?(payload|secret|credential)|do not copy.*(secret|credential|payload)
re|start-review/templates/reviewer-final-handoff.md|without secret values|without including secret values|no secret values
# review-reject-non-mutating
re|start-review/REVIEW-FLOW.md|Reject.*(Review Report|report).*(stop|escalat)|Reject.*(stop|escalat).*(Review Report|report)
re|start-review/REVIEW-FLOW.md|reject.*(stop|escalat)|reject.*(Review Report|report)
re|start-review/SKILL.md|reject.*(stop|escalat)|reject.*(Review Report|report)
# review-sha-bound-checkout
re|start-review/REVIEW-FLOW.md|git rev-parse HEAD
re|start-review/REVIEW-FLOW.md|exact reviewed commit from a fresh
re|start-review/REVIEW-FLOW.md|`forge snapshot`
re|start-review/REVIEW-FLOW.md|detached isolated
re|start-review/REVIEW-FLOW.md|recreates a detached isolated
re|start-review/REVIEW-FLOW.md|selected provider branch
re|start-review/REVIEW-FLOW.md|materializes that exact commit
re|start-review/REVIEW-FLOW.md|Never run an arbitrary `git pull`
re|start-review/REVIEW-FLOW.md|each change request
re|start-review/REVIEW-FLOW.md|own isolated checkout and fresh
re|start-review/templates/review-report.md|isolated checkout path[^.]*observed commit
re|start-review/templates/review-report.md|matches the reviewed commit
re|start-review/templates/review-report.md|Not run — <rationale>
re|start-review/templates/filling-guide.md|isolated checkout path[^.]*observed commit
re|start-review/templates/filling-guide.md|matches the reviewed commit
re|start-review/templates/filling-guide.md|Not run — <rationale>
re|forge/reference/gitlab.md|snapshot|commit|fetch|checkout
# review-structural-sweep
contain|start-review/REVIEW-FLOW.md|## Structural maintainability sweep
contain|start-review/REVIEW-FLOW.md|diff-first
contain|start-review/REVIEW-FLOW.md|blast-radius-bounded
contain|start-review/REVIEW-FLOW.md|`<1000`
contain|start-review/REVIEW-FLOW.md|`>1000`
contain|start-review/REVIEW-FLOW.md|presumptive Must Fix
contain|start-review/REVIEW-FLOW.md|compelling decomposition rationale
contain|start-review/REVIEW-FLOW.md|Decision rule:
contain|start-review/REVIEW-FLOW.md|block as `MF-N`
contain|start-review/REVIEW-FLOW.md|Use `C-N`
contain|start-review/REVIEW-FLOW.md|Code-judo simplification
# review-tone
contain|start-review/REVIEW-FLOW.md|## Review tone
contain|start-review/REVIEW-FLOW.md|Tone never moves the bar.
contain|start-review/REVIEW-FLOW.md|Do not request changes for taste
contain|start-review/SKILL.md|Treat style-only preferences as non-blocking
absent|start-review/REVIEW-FLOW.md|cursor/plugins
absent|start-review/REVIEW-FLOW.md|Measure twice, cut once.
absent|start-review/SKILL.md|cursor/plugins
absent|start-review/SKILL.md|Measure twice, cut once.
# review-report-summary-first headings/prompts
re|start-review/templates/filling-guide.md|Decision Summary
re|start-review/SKILL.md|Decision Summary
re|start-review/templates/filling-guide.md|Review verdict
re|start-review/SKILL.md|Review verdict
re|start-review/templates/filling-guide.md|pass[[:space:]]*/[[:space:]]*request-changes[[:space:]]*/[[:space:]]*reject[[:space:]]*/[[:space:]]*blocked
re|start-review/SKILL.md|pass[[:space:]]*/[[:space:]]*request-changes[[:space:]]*/[[:space:]]*reject[[:space:]]*/[[:space:]]*blocked
re|start-review/templates/filling-guide.md|reviewed commit
re|start-review/SKILL.md|reviewed commit
re|start-review/templates/filling-guide.md|Report locator
re|start-review/SKILL.md|Report locator
re|start-review/templates/filling-guide.md|CI[^\n]*(status[[:space:]]*/[[:space:]]*commit|status[^\n]*commit)
re|start-review/SKILL.md|CI[^\n]*(status[[:space:]]*/[[:space:]]*commit|status[^\n]*commit)
re|start-review/templates/filling-guide.md|MF-N[^\n]*SF-N[^\n]*C-N|MF[^\n]*SF[^\n]*C
re|start-review/SKILL.md|MF-N[^\n]*SF-N[^\n]*C-N|MF[^\n]*SF[^\n]*C
re|start-review/templates/filling-guide.md|local checks
re|start-review/SKILL.md|local checks
re|start-review/templates/filling-guide.md|Approval action
re|start-review/SKILL.md|Approval action
re|start-review/templates/filling-guide.md|Finish action
re|start-review/SKILL.md|Finish action
re|start-review/templates/filling-guide.md|Action blocker
re|start-review/SKILL.md|Action blocker
re|start-review/templates/filling-guide.md|request-changes.*Approval action: not-approved.*Finish action: none.*Action blocker: none.*Next action: revise
re|start-review/templates/review-report.md|request-changes.*Approval action: not-approved.*Finish action: none.*Action blocker: none.*Next action: revise
re|start-review/templates/filling-guide.md|Next action
re|start-review/SKILL.md|Next action
re|start-review/templates/filling-guide.md|Context / Snapshot
re|start-review/templates/filling-guide.md|Finding identities
re|start-review/templates/filling-guide.md|Findings
re|start-review/templates/filling-guide.md|Open Questions Addressed
re|start-review/templates/filling-guide.md|Evidence
re|start-review/templates/filling-guide.md|Action / Blocker
re|start-review/templates/filling-guide.md|Optional Annex: Checklists
# retro-invariants
contain|retro/SKILL.md|Never print secrets
contain|retro/SKILL.md|Never paste full session dumps
contain|retro/SKILL.md|redact with `[REDACTED]`
contain|retro/SKILL.md|Proposal-only
contain|retro/SKILL.md|never edits skills, templates, docs, gates, or tests directly
contain|retro/SKILL.md|Route, don't edit
contain|retro/SKILL.md|/plan-to-issues
contain|retro/SKILL.md|Safety floors are not retro material
contain|retro/SKILL.md|classified `human-decision` and stops there
contain|retro/SKILL.md|safety-floor check
contain|retro/SKILL.md|`batch`
contain|retro/SKILL.md|`lookback <date range>`
contain|retro/SKILL.md|Aggregate counts
contain|retro/SKILL.md|Active memory discovery with graceful degradation
contain|retro/SKILL.md|if it is unavailable, say so and continue
contain|retro/SKILL.md|Date-range scoping
contain|retro/SKILL.md|don't-overfit-to-anecdotes rule
contain|retro/SKILL.md|Refute before presenting
contain|retro/SKILL.md|Refute the draft
contain|retro/SKILL.md|read-only refuter subagent
contain|retro/SKILL.md|the harness picks the agent type
contain|retro/reference/refutation.md|Target the finding, not the drafter
contain|retro/reference/refutation.md|Verdicts only
contain|retro/reference/refutation.md|Read-only
contain|retro/reference/refutation.md|safety floor check is the refuter's attestation
contain|retro/templates/retro-report.md|Refutation log
contain|retro/templates/retro-report.md|Refutation:
absent|retro/SKILL.md|memory-retrospective
# cleanup-codebase-invariants
contain|cleanup-codebase/SKILL.md|Planning-only by default
contain|cleanup-codebase/SKILL.md|leave implementation to the build workflow
contain|cleanup-codebase/SKILL.md|DESLOP
contain|cleanup-codebase/SKILL.md|DESTALE
contain|cleanup-codebase/SKILL.md|CLOSED list
contain|cleanup-codebase/SKILL.md|improve-codebase-architecture
contain|cleanup-codebase/SKILL.md|Gate sequence
contain|cleanup-codebase/SKILL.md|Export gate
contain|cleanup-codebase/SKILL.md|Reference gate
contain|cleanup-codebase/SKILL.md|Incidental-contract gate
contain|cleanup-codebase/SKILL.md|Domain gate
contain|cleanup-codebase/SKILL.md|Edge gate
contain|cleanup-codebase/SKILL.md|Survives all five
contain|cleanup-codebase/SKILL.md|Default to a repo-wide sweep when scope is unspecified
contain|cleanup-codebase/SKILL.md|honor any explicit narrower user scope
contain|cleanup-codebase/SKILL.md|the default posture for discovery
contain|cleanup-codebase/SKILL.md|If coverage is incomplete
contain|cleanup-codebase/SKILL.md|known gaps before findings
contain|cleanup-codebase/SKILL.md|every finding **MUST** cite exact file/line/command/doc/test evidence
contain|cleanup-codebase/SKILL.md|Leads without proof are not findings
contain|cleanup-codebase/SKILL.md|pure nits, style, and personal preference are OUT/omitted
contain|cleanup-codebase/SKILL.md|proven deslop/destale candidates only
contain|cleanup-codebase/SKILL.md|single mechanical source of truth
contain|cleanup-codebase/SKILL.md|stale → correct value pair
contain|cleanup-codebase/SKILL.md|Missing owner proof or missing impact proof has exactly one outcome: `Needs info`; neither can be HITL or AFK
contain|cleanup-codebase/SKILL.md|**HITL** — behavior-touching deslop (characterization tests required).
absent|cleanup-codebase/SKILL.md|or any candidate with uncertain ownership/impact
contain|cleanup-codebase/SKILL.md|handoffs
contain|cleanup-codebase/SKILL.md|fallback
# terraform-tofu-invariants
contain|terraform-tofu/SKILL.md|exactly one of `terraform` or `tofu`
contain|terraform-tofu/SKILL.md|Missing, conflicting, ambiguous, or constraint-only evidence blocks work.
contain|terraform-tofu/SKILL.md|unsupported required test feature blocks work
contain|terraform-tofu/SKILL.md|behavior-level `.tftest.hcl` test first
contain|terraform-tofu/SKILL.md|run exactly `terraform test` or `tofu test`
contain|terraform-tofu/SKILL.md|A passing-first test, unrelated error, unexecuted test, parse/setup failure, or external framework is not RED
contain|terraform-tofu/SKILL.md|Do not silently change the engine
contain|terraform-tofu/SKILL.md|Invoke `/forge preflight` exactly once
contain|terraform-tofu/SKILL.md|Use `/forge snapshot` only when issue, change-request, or CI context exists.
contain|terraform-tofu/SKILL.md|record `forge_mode: local-only`
contain|terraform-tofu/SKILL.md|The skill never publishes, approves, merges, queues, or performs post-merge actions.
contain|terraform-tofu/SKILL.md|[authoring rules](reference/authoring.md)
contain|terraform-tofu/SKILL.md|[native-testing rules](reference/native-testing.md)
contain|terraform-tofu/reference/native-testing.md|Set `command = plan` in every safe-workflow run block.
contain|terraform-tofu/reference/native-testing.md|native mock providers
contain|terraform-tofu/reference/native-testing.md|Do not use `command = apply` against real infrastructure by default.
contain|terraform-tofu/reference/native-testing.md|isolated credentials
contain|terraform-tofu/reference/native-testing.md|isolated local state and backend boundaries
contain|terraform-tofu/reference/native-testing.md|deterministic cleanup plus observed cleanup evidence
contain|terraform-tofu/reference/native-testing.md|https://developer.hashicorp.com/terraform/language/tests
contain|terraform-tofu/reference/native-testing.md|https://opentofu.org/docs/cli/commands/test/
contain|terraform-tofu/reference/authoring.md|explicit provider source/version constraints
contain|terraform-tofu/reference/authoring.md|variables precise types
contain|terraform-tofu/reference/authoring.md|Mark secret-bearing variables and outputs `sensitive = true`
contain|terraform-tofu/reference/authoring.md|`for_each` with stable, meaningful keys
contain|terraform-tofu/reference/authoring.md|Add `depends_on` or `lifecycle` only for an intentional behavior
contain|terraform-tofu/reference/authoring.md|Do not add provisioners.
contain|terraform-tofu/reference/authoring.md|Do not change backend or state behavior
contain|terraform-tofu/reference/authoring.md|https://developer.hashicorp.com/terraform/language/style
contain|terraform-tofu/reference/authoring.md|https://opentofu.org/docs/language/syntax/style/
contain|install.sh|[[ -f "$dir/SKILL.md" ]] || continue
# parent-owned-gate-invariants
contain|start-build/reference/parent-owned-gate.md|local_gate_owner: "parent"
contain|start-build/reference/parent-owned-gate.md|builder_gate_status
contain|start-build/reference/parent-owned-gate.md|status: "not-run"
contain|start-build/reference/parent-owned-gate.md|not_run_reason: "parent-owned"
contain|start-build/reference/parent-owned-gate.md|ready_transition_owner: "parent"
contain|start-build/reference/parent-owned-gate.md|must not claim local gate PASS/FAIL
contain|start-build/reference/parent-owned-gate.md|parent posts the Gate Receipt and marks ready
contain|start-build/reference/parent-owned-gate.md|gate_receipt.kind=gate-receipt
contain|start-build/reference/parent-owned-gate.md|change_id
contain|start-build/reference/parent-owned-gate.md|issue_id
contain|start-build/reference/parent-owned-gate.md|checkout_commit
contain|start-build/reference/parent-owned-gate.md|result: "PASS"
contain|start-build/reference/parent-owned-gate.md|preflight_checks
contain|start-build/reference/parent-owned-gate.md|evidence
contain|start-build/reference/parent-owned-gate.md|observed_at
contain|start-build/reference/parent-owned-gate.md|Parent verification checklist
contain|start-build/reference/parent-owned-gate.md|Gate coverage is `exact-candidate-local`
contain|start-build/reference/parent-owned-gate.md|Provider CI
contain|start-build/reference/parent-owned-gate.md|byte-for-byte
contain|start-build/reference/parent-owned-gate.md|delta-only
contain|start-build/reference/parent-owned-gate.md|stale evidence
contain|start-build/reference/parent-owned-gate.md|new exact-commit Gate Receipt
contain|start-build/templates/delivery-schema.md|parent-owned-gate.md
contain|start-build/templates/delivery-schema.md|gate_receipt.kind=gate-receipt
contain|start-build/templates/delivery-schema.md|parent-owned
contain|start-build/templates/builder-final-handoff.md|parent-owned-gate.md
contain|start-build/templates/review-packet.md|parent-owned-gate.md
contain|start-build/templates/review-packet-compact.md|parent-owned-gate.md
contain|start-review/templates/review-report.md|parent-owned-gate.md
contain|docs/agents/check-gate.md|tests/token-grep-invariants.sh
# check-gate-fabricated-home-doc
contain|docs/agents/check-gate.md|fabricated disposable HOME containing stub required external skills
contain|docs/agents/check-gate.md|not the operator's real HOME
contain|docs/agents/check-gate.md|no `AGENT_SKILLS_CHECK_HOME` override
contain|docs/agents/check-gate.md|only that real-HOME operator run detects installed-runtime external-skill drift
# triage-labels-human-decision-exit
contain|docs/agents/triage-labels.md|reconcile the issue body in that same step
contain|docs/agents/triage-labels.md|point it at the durable decision note
contain|docs/agents/triage-labels.md|does not license rewriting issue bodies generally
# issue-delivery-loop-invariants
contain|issue-delivery-loop/SKILL.md|forge preflight
contain|issue-delivery-loop/SKILL.md|default-branch CI health
contain|issue-delivery-loop/SKILL.md|Automatically launch every provably decoupled subset in parallel
contain|issue-delivery-loop/SKILL.md|Coupled members serialize only within their coupled cluster in dependency order
contain|issue-delivery-loop/SKILL.md|Use WIP-1 only when decoupling proof fails or is unknown, or the caller explicitly bounds WIP
contain|issue-delivery-loop/SKILL.md|dependency ordering
contain|issue-delivery-loop/SKILL.md|Decoupling Contract
contain|issue-delivery-loop/SKILL.md|coordinator checkout
contain|issue-delivery-loop/SKILL.md|must not copy auxiliary-index artifacts
contain|issue-delivery-loop/SKILL.md|one default `mr-builder`
contain|issue-delivery-loop/SKILL.md|mr-reviewer-final
contain|issue-delivery-loop/SKILL.md|parent-orchestrator.md
contain|issue-delivery-loop/SKILL.md|runtime notices never become scope stop instructions
contain|issue-delivery-loop/SKILL.md|Event-driven waiting only
contain|issue-delivery-loop/SKILL.md|no CI status changes verdict
contain|issue-delivery-loop/SKILL.md|keep verdict, approval, and finish separate
contain|issue-delivery-loop/SKILL.md|auto-merge queued
contain|issue-delivery-loop/SKILL.md|Provider merge-event evidence
contain|issue-delivery-loop/SKILL.md|post_merge_snapshot.kind=post-merge-snapshot
contain|issue-delivery-loop/SKILL.md|cleanup_pending
contain|issue-delivery-loop/SKILL.md|#380 coordinator-isolation
contain|issue-delivery-loop/SKILL.md|cleanup ordering
contain|issue-delivery-loop/SKILL.md|Project-profile hooks
contain|issue-delivery-loop/SKILL.md|provider-native post-read
contain|issue-delivery-loop/SKILL.md|a defect in the issue as written
contain|issue-delivery-loop/SKILL.md|**`other` tokens used**
contain|retro/templates/retro-report.md|**`other` tokens used**
absent|issue-delivery-loop/SKILL.md|skill://gitlab
absent|issue-delivery-loop/SKILL.md|glab 
# default-builder-route-invariants
contain|docs/agents/dev-workflows.md|internal `mr-builder` and `mr-reviewer-final` routes
absent|docs/agents/dev-workflows.md|mr-builder-trivial
absent|docs/agents/dev-workflows.md|mr-builder-moderate
absent|docs/agents/dev-workflows.md|mr-builder-high-risk
absent|docs/agents/dev-workflows.md|mr-builder-*
absent|issue-delivery-loop/SKILL.md|mr-builder-trivial
absent|issue-delivery-loop/SKILL.md|mr-builder-moderate
absent|issue-delivery-loop/SKILL.md|mr-builder-high-risk
absent|issue-delivery-loop/SKILL.md|mr-builder-*
absent|start-build/reference/parent-orchestrator.md|mr-builder-trivial
absent|start-build/reference/parent-orchestrator.md|mr-builder-moderate
absent|start-build/reference/parent-orchestrator.md|mr-builder-high-risk
absent|start-build/reference/parent-orchestrator.md|mr-builder-*
contain|start-build/reference/parent-orchestrator.md|shared model-free `mr-builder` basename
contain|start-build/reference/parent-orchestrator.md|mr-reviewer-final
contain|start-build/reference/parent-orchestrator.md|Gate owner
contain|start-build/reference/parent-orchestrator.md|Finish owner
contain|start-build/reference/parent-orchestrator.md|coordinator checkout
contain|start-build/reference/parent-orchestrator.md|session-owned worktree ledger
contain|start-build/reference/parent-orchestrator.md|coordinator_path="$(cd "$coordinator_path" && pwd -P)"
contain|start-build/reference/parent-orchestrator.md|child_worktree_path="$(cd "$child_worktree_path" && pwd -P)"
contain|start-build/reference/parent-orchestrator.md|No repository-wide worktree discovery result
contain|start-build/reference/parent-orchestrator.md|`--coordinator-path "$coordinator_path"`
contain|start-build/reference/parent-orchestrator.md|every local-mutating finish call
contain|start-build/reference/parent-orchestrator.md|`--worktree-path "$child_worktree_path"`
contain|start-build/reference/parent-orchestrator.md|residual session-owned worktree
contain|issue-delivery-loop/SKILL.md|session-owned worktree ledger
contain|issue-delivery-loop/SKILL.md|residual session-owned worktree
TABLE

# MF-1/MF-2: planted forbidden needle in an existing file must fail.
planted="$(mktemp)"
printf '%s\n' 'MF1-PLANTED-NEEDLE' > "$planted"
rc=0
grep -Fq -- 'MF1-PLANTED-NEEDLE' "$planted" && rc=1
rm -f "$planted"
[[ "$rc" -eq 1 ]] || fail "planted forbidden needle did not fail"
planted="$(mktemp)"
cp retro/SKILL.md "$planted"
printf '\n%s\n' 'memory-retrospective' >> "$planted"
rc=0
grep -Fq -- 'memory-retrospective' "$planted" && rc=1
rm -f "$planted"
[[ "$rc" -eq 1 ]] || fail "planted memory-retrospective in retro/SKILL.md copy did not fail"

# Default-route mutation: the same fixed-string invariant must reject a
# representative retired concrete route planted in an active routing surface.
planted="$(mktemp)"
cp docs/agents/dev-workflows.md "$planted"
printf '\n%s\n' 'mr-builder-trivial' >> "$planted"
if (assert_fixed_absent "$planted" 'mr-builder-trivial') >/dev/null 2>&1; then
  rm -f "$planted"
  fail "planted retired builder route did not fail"
fi
rm -f "$planted"

# terraform-tofu reject needles (regex, must stay out of the file)
reject_text terraform-tofu/reference/native-testing.md 'default plan-mode|plan-mode default|defaults? to plan' 'wording that implies plan is the native engine default'
reject_text install.sh 'terraform-tofu' 'installer special case'

# start-review-command-ownership raw-mechanic reject across owned files
for file in start-review/SKILL.md start-review/REVIEW-FLOW.md start-review/templates/filling-guide.md $(agent_prompt_paths "${reviewer_prompt_names[@]}"); do
  reject_text "$file" '(^|[[:space:]`])glab[[:space:]]+(issue|mr|ci|repo|api)|Snippet:|gitlab/reference/(review-read|review-actions|ci)[.]md|refs/merge-requests|PRIVATE-TOKEN' 'raw/provider-specific review mechanics'
done

# builder credential needles
for agent in $(agent_prompt_paths "${builder_prompt_names[@]}"); do
  require_text "$agent" 'Credential handling discipline' 'builder credential discipline section'
  require_text "$agent" 'never[^.]*cat[^.]*echo[^.]*token-bearing config' 'builder no-print token config rule'
  require_text "$agent" 'read[^.]*variable[^.]*without printing|read[^.]*shell variable[^.]*without printing' 'builder read-into-variable-without-printing pattern'
  require_text "$agent" 'redact[^.]*\[REDACTED\]' 'builder redacted diagnostic rule'
  assert_file_contains "$agent" 'approve, merge, queue auto-merge' "$agent no self finish"
  assert_file_contains "$agent" 'forge' "$agent provider seam"
done

# reviewer authority needles
for file in $(agent_prompt_paths "${routed_final_reviewer_prompt_names[@]}"); do
  assert_file_contains "$file" 'Canonical development pattern source: `start-review`' "$file start-review source"
  assert_file_contains "$file" '`forge` common-guard authority verification' "$file forge authority source"
  assert_file_contains "$file" 'Reviewer Lift' "$file claims-to-verify seam"
  assert_file_contains "$file" 'Finish owner: parent' "$file parent ownership"
  assert_file_contains "$file" 'approval_action: "not-approved"' "$file parent no approval"
  assert_file_contains "$file" 'finish_action: "none"' "$file parent no finish"
  assert_file_contains "$file" 'start-review` plus `forge` common-guard authority verification' "$file reviewer authority seam"
  assert_file_not_contains "$file" 'start-review` plus `gitlab`' "$file retired GitLab seam"
  require_text "$file" 'Review Report' 'routed reviewer Review Report reference'
  require_text "$file" 'final handoff' 'routed reviewer final handoff reference'
  require_text "$file" 'change-request, reviewed-commit, CI/gate, authority, finding, action, and blocker evidence' 'routed reviewer report/handoff evidence fields'
  require_text "$file" 'verdict, approval action, finish action, action blocker, and next action separate' 'routed reviewer action separation'
done

# handoff retired flat aliases (original used fixed-string '^  …')
for handoff in start-build/templates/builder-final-handoff.md start-review/templates/reviewer-final-handoff.md; do
  assert_file_not_contains "$handoff" '^  merge_authority' "$handoff retired flat alias"
  assert_file_not_contains "$handoff" '^  approval_authority' "$handoff retired flat alias"
done

# child-path size
child_doc=start-build/reference/child-builder.md
assert_path_readable "$child_doc"
child_lines="$(wc -l < "$child_doc" | tr -d ' ')"
child_words="$(wc -w < "$child_doc" | tr -d ' ')"
[[ "$child_lines" -le 217 ]] || fail "$child_doc has $child_lines lines; expected <= 217"
[[ "$child_words" -le 2552 ]] || fail "$child_doc has $child_words words; expected <= 2552"

# discovery-budget section order + block needles
context=start-build/reference/context-and-planning.md
discovery_start="$(grep -n '^## Discovery Budget$' "$context" | cut -d: -f1)"
packet_start="$(grep -n '^## Build Plan Packet$' "$context" | cut -d: -f1)"
check_gate_start="$(grep -n '^## Check gate discovery$' "$context" | cut -d: -f1)"
[[ -n "$discovery_start" && -n "$packet_start" && -n "$check_gate_start" ]] || fail "Discovery Budget headings missing"
[[ "$discovery_start" -lt "$packet_start" ]] || fail "Discovery Budget must precede Build Plan Packet"
[[ "$packet_start" -lt "$check_gate_start" ]] || fail "Build Plan Packet must precede check gate discovery"
discovery_block="$(sed -n "${discovery_start},$((packet_start - 1))p" "$context")"
packet_block="$(sed -n "${packet_start},$((check_gate_start - 1))p" "$context")"
printf '%s\n' "$discovery_block" | grep -q 'bounded' || fail "Discovery Budget block missing bounded exploration language"
printf '%s\n' "$discovery_block" | grep -q 'current behavior, affected surfaces, test entrypoint, safety constraints, and non-goals' || fail "Discovery Budget block missing required facts list"
printf '%s\n' "$discovery_block" | grep -q 'route the issue back to triage' || fail "Discovery Budget block missing triage bounce rule"
printf '%s\n' "$discovery_block" | grep -q 'exact unanswered questions' || fail "Discovery Budget block missing exact-question requirement"
for context_source in 'ADRs' 'architecture docs' 'domain docs' 'CONTEXT.md'; do
  printf '%s\n' "$discovery_block" | grep -qF "$context_source" || fail "Discovery Budget block missing $context_source"
done
for trigger in 'issue links' 'rulebook references' 'changed paths' 'imports/callers' 'tests' 'safety invariants' 'failing checks' 'explicit user/parent prompt'; do
  printf '%s\n' "$discovery_block" | grep -qF "$trigger" || fail "Discovery Budget block missing trigger: $trigger"
done
printf '%s\n' "$packet_block" | grep -q 'issue, intended behavior, affected surfaces, test plan, risk, and non-goals' || fail "Build Plan Packet block missing required fields"
printf '%s\n' "$packet_block" | grep -q '../templates/build-plan-packet.md' || fail "Build Plan Packet block missing template pointer"
printf '%s\n' "$packet_block" | grep -qF 'loaded context sources' || fail "Build Plan Packet block missing loaded-context-source recording"
printf '%s\n' "$packet_block" | grep -qF 'why each source was relevant' || fail "Build Plan Packet block missing context relevance rationale"

# done-criteria section
done_section="$(awk '/^## Done criteria$/ { in_section=1; next } in_section && /^## / { exit } in_section { print }' start-build/SAFETY.md)"
[[ -n "$done_section" ]] || fail "SAFETY.md is missing a '## Done criteria' section"
for needle in builder-ready review-gate-complete finish-merge post-merge-verified \
  reference/child-builder.md reference/standalone-gate.md reference/parent-orchestrator.md \
  reference/post-merge-verifier.md 'final handoff'; do
  printf '%s\n' "$done_section" | grep -Fq "$needle" || fail "Done criteria missing $needle"
done

# ready-gate: no full-gate-before-push; ownership stays separate from coverage
if grep -qiE 'Run the (full )?(local )?gate locally before pushing|full Check Gate[^\n]*before pushing|full local gate[^\n]*before pushing' start-build/SAFETY.md; then
  fail "start-build/SAFETY.md still requires the full gate before pushing"
fi
grep -Fq 'Gate coverage | `exact-candidate-local`' start-build/templates/reviewer-lift-schema.md \
  || fail "Reviewer Lift exact-candidate local coverage missing"

# review-blocked-verdict enums
normalize_enum() {
  sed -E 's/[[:space:]]+— canonical values:.*$//' | tr '/|' '\n' | sed -E 's/[`"<>]//g; s/^[[:space:]]+//; s/[[:space:]]+$//' | sed '/^$/d'
}
assert_enum() {
  local label=$1 actual=$2 expected=$3
  diff -u <(printf '%s\n' "$expected") <(printf '%s\n' "$actual" | normalize_enum) || fail "$label drifted"
}
report_row() {
  awk -F'|' -v row="$2" '$0 ~ /^\|/ { field=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", field); if (field == row) { value=$3; gsub(/^[[:space:]]+|[[:space:]]+$/, "", value); print value; exit } }' "$1"
}
yaml_field() {
  sed -nE "s/^[[:space:]]+$2:[[:space:]]*\"([^\"]+)\".*/\1/p" "$1" | head -n1
}
handoff_token_enum() {
  node --input-type=module - start-review/reference/handoff-tokens.schema.json "$1" <<'NODE'
import fs from "node:fs";
const schema = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
process.stdout.write(schema[process.argv[3]].join("\n"));
NODE
}
verdicts="$(handoff_token_enum review_verdict)"
blockers="$(handoff_token_enum action_blocker)"
assert_enum "Review Report verdict enum" "$(report_row start-review/templates/review-report.md 'Review verdict')" "$verdicts"
assert_enum "reviewer handoff verdict enum" "$(yaml_field start-review/templates/reviewer-final-handoff.md review_verdict)" "$verdicts"
assert_enum "Review Report blocker enum" "$(report_row start-review/templates/review-report.md 'Action blocker')" "$blockers"
assert_enum "reviewer handoff blocker enum" "$(yaml_field start-review/templates/reviewer-final-handoff.md action_blocker)" "$blockers"

# review-ci-oq: no provider mapping in generic table; no matrix copy
section=$(sed -n '/^## CI and Open Question decision tables$/,/^## Finish authority source precedence$/p' start-review/REVIEW-FLOW.md)
[[ -n "$section" ]] || fail "REVIEW-FLOW.md CI decision table section is empty; heading renamed or moved (guard would not fire)"
if grep -Eq 'headRefOid|lastMergeCommit|GitLab' <<<"$section"; then fail "provider mapping in generic table"; fi
for file in start-review/SKILL.md start-review/templates/filling-guide.md; do
  if grep -Eq 'rules-omitted|conditionally required job absent|reviewer cannot self-waive' "$file"; then
    fail "$file duplicates CI matrix"
  fi
done

# review-ci-oq: advisory classifications stay provider-neutral.
ci_section=$(sed -n '/^## CI and Open Question decision tables$/,/^## Finish authority source precedence$/p' start-review/REVIEW-FLOW.md)
[[ -n "$ci_section" ]] || fail "REVIEW-FLOW.md CI decision table section is empty"
if grep -Eq 'headRefOid|lastMergeCommit|GitLab|glab' <<<"$ci_section"; then
  fail "provider mapping in generic advisory table"
fi
for needle in 'Every classification is advisory' 'No provider CI status changes the review' \
  'passing exact-candidate local Check Gate' 'Native provider protection may refuse'; do
  grep -Fq "$needle" <<<"$ci_section" || fail "REVIEW-FLOW.md advisory table missing $needle"
done
require_text gitlab/reference/ci-finish-guards.md 'REVIEW-FLOW\.md#ci-decision-table' 'CI observation table pointer'

# review-context-policy capsule rows + launch prompts
for file in start-review/REVIEW-FLOW.md start-review/templates/review-report.md; do
  for row in 'Repository' 'Change request' 'Authority' 'CI' 'Scope' 'Artifacts' 'Context expansion'; do
    require_row "$file" "$row"
  done
  reject_text "$file" '^\|[[:space:]]*(Repo|MR)[[:space:]]*\|' 'stale capsule alias'
done
parent=start-build/reference/parent-orchestrator.md
reviewer_prompt="$(awk '/^```text$/ { in_block=1; block=""; next } in_block && /^```$/ { if (block ~ /Mode: mr-reviewer/) print block; in_block=0; next } in_block { block=block $0 "\n" }' "$parent")"
builder_prompt="$(awk '/^```text$/ { in_block=1; block=""; next } in_block && /^```$/ { if (block ~ /Mode: child mr-builder/) print block; in_block=0; next } in_block { block=block $0 "\n" }' "$parent")"
[[ -n "$reviewer_prompt" ]] || fail 'reviewer launch prompt not found'
[[ -n "$builder_prompt" ]] || fail 'child-builder launch prompt not found'
printf '%s' "$reviewer_prompt" | grep -Eiq 'Skills: invoke start-review and forge via the Skill tool' || fail 'reviewer prompt missing Skill invocation'
printf '%s' "$builder_prompt" | grep -Eiq 'Skills: invoke start-build and forge via the Skill tool' || fail 'builder prompt missing Skill invocation'
for field in 'Change request locator' 'Reviewer Lift pointer' 'Project rulebook path' 'Stop condition' 'Finish owner'; do
  printf '%s' "$reviewer_prompt" | grep -Eiq "$field" || fail "reviewer prompt missing $field"
done
for prompt in "$reviewer_prompt" "$builder_prompt"; do
  ! printf '%s' "$prompt" | grep -Eiq 'invoke (start-review|start-build) and gitlab|Reading? (an? )?(internal )?reference|MR URL' || fail 'launch prompt owns transport or raw policy reads'
done

# issue #399: launch-prompt Forbidden-actions lines must not bundle a
# prohibition that subsumes an action the same prompt requires.
reviewer_forbidden="$(printf '%s\n' "$reviewer_prompt" | grep -E '^Forbidden actions:')"
builder_forbidden="$(printf '%s\n' "$builder_prompt" | grep -E '^Forbidden actions:')"
[[ -n "$reviewer_forbidden" ]] || fail 'reviewer prompt missing Forbidden actions line'
[[ -n "$builder_forbidden" ]] || fail 'builder prompt missing Forbidden actions line'
# An MR note is a mutation (gitlab/reference/mutation-guard.md), so "mutate
# provider state" subsumed the Review Report publication the same prompt
# requires. The reviewer forbidden line must enumerate the real state-changing
# actions instead. Reintroducing the phrase must FAIL this test.
if printf '%s' "$reviewer_forbidden" | grep -Fq 'mutate provider state'; then
  fail 'reviewer Forbidden actions line still forbids "mutate provider state"; it subsumes the required Review Report publication'
fi
# The parent-owned-gate condition must be its own line, not a trailing clause a
# skim or truncation can drop — dropping it inverted a builder-owned gate into a
# parent-owned one. The Forbidden actions line must not end with that condition.
if printf '%s' "$builder_forbidden" | grep -Eiq 'Gate owner is parent|Gate Receipt|ready transition'; then
  fail 'builder Forbidden actions line still carries the parent-owned-gate conditional as a trailing clause'
fi

# review-reject close-wording scan
while IFS=: read -r file line text; do
  [[ -n "${file:-}" ]] || continue
  lower="$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')"
  if [[ "$lower" != *explicit* || "$lower" != *authority* ]]; then
    fail "$file:$line has MR close wording without explicit authority: $text"
  fi
  if [[ "$lower" != *human* && "$lower" != *project* ]]; then
    fail "$file:$line has MR close authority wording without human/project scope: $text"
  fi
done < <(grep -RIinE 'close (an |the )?mr|close-mr|mr close|closing (an |the )?mr' start-review || true)

# review-sha-bound-checkout order + no provider mechanics in section
flow=start-review/REVIEW-FLOW.md
checkout_section="$(awk '/^## Single-change request checkout mode$/ { in_section=1; next } in_section && /^## / { exit } in_section { print }' "$flow")"
checkout_offset="$(offset_of "$flow" '^##[[:space:]]+Single-change request checkout mode' 'checkout binding')"
checks_offset="$(offset_of "$flow" 'run targeted checks' 'targeted checks')"
(( checkout_offset < checks_offset )) || fail 'checkout binding must precede targeted checks'
! grep -Eiq 'refs/merge-requests|refs/tmp/review/mr-|<iid>|gitlab' <<<"$checkout_section" || fail "$flow checkout section contains provider-specific mechanics"

# review-action-order
action_section=$(mktemp)
trap 'rm -f "$action_section"' EXIT
awk '/^## Publication and actions$/ { active=1; next } active && /^## / { exit } active { print }' "$flow" > "$action_section"
[[ -s "$action_section" ]] || fail "Publication and actions section is empty"
previous=-1
for spec in \
  'Draft the Review Report|draft report' \
  'final provider-native change-request|final snapshot' \
  'forge publish|durable report publication' \
  'fresh `forge snapshot`|fresh pre-action snapshot' \
  'exactly one authorized `forge act`|one authorized action' \
  'provider-native post-read|post-read and handoff'; do
  pattern=${spec%%|*}; label=${spec#*|}; current=$(LC_ALL=C grep -Einm1 -- "$pattern" "$action_section" | cut -d: -f1 || true)
  [[ -n $current ]] || fail "missing ordered action step: $label"
  (( current > previous )) || fail "action step out of order: $label"
  previous=$current
done
assert_file_contains "$action_section" 'safe-body' "safe body publication"
assert_file_contains "$action_section" 'byte-for-byte' "publication readback"
assert_file_contains "$action_section" 'head changed after publication' "changed-head handling"
assert_file_contains "$action_section" 'skip' "changed-head skips action"
assert_file_contains "$action_section" 'action result' "action result"
assert_file_contains "$action_section" 'final' "final handoff"
assert_file_contains "$action_section" 'Finish owner: parent' "parent finish owner"
assert_file_contains "$action_section" 'not-approved' "parent no approval"
assert_file_contains "$action_section" 'finish `none`' "parent no finish"

# review-report-summary-first structural
REPORT=start-review/templates/review-report.md
first_heading="$(awk '/^##[[:space:]]+/ { sub(/^##[[:space:]]+/, ""); print; exit }' "$REPORT")"
[[ "$first_heading" == "Decision Summary" ]] || fail "first Review Report section must be 'Decision Summary', got '${first_heading:-<none>}'"
summary="$(extract_section "$REPORT" "Decision Summary")"
[[ -n "$summary" ]] || fail "Decision Summary section is empty"
for spec in \
  'Review verdict|review verdict field' \
  'pass[[:space:]]*/[[:space:]]*request-changes[[:space:]]*/[[:space:]]*reject[[:space:]]*/[[:space:]]*blocked|blocked-capable verdict enum' \
  'Report locator|stable report locator field' \
  'Reviewed commit|reviewed commit field' \
  'CI status[[:space:]]*/[[:space:]]*commit|CI .*status.*commit|CI status/commit field' \
  'Findings summary|findings summary field' \
  'MF|Must Fix (MF) summary' \
  'SF|Should Fix (SF) summary' \
  'C|Consider (C) summary' \
  'Local checks|local checks field' \
  'Approval action|approval action field' \
  'Finish action|finish action field' \
  'Action blocker|action blocker field' \
  'Next action|next action field' \
  'Report link|report link placeholder'; do
  pattern=${spec%%|*}; label=${spec#*|}
  grep -Eiq "$pattern" <<<"$summary" || fail "Decision Summary missing $label"
done
for heading in 'Context / Snapshot' 'Finding identities' 'Findings' 'Open Questions Addressed' 'Evidence' 'Action / Blocker' 'Optional Annex: Checklists'; do
  grep -Eq "^##[[:space:]]+${heading}[[:space:]]*$" "$REPORT" || fail "Review Report missing $heading"
done
if grep -En 'None\.' "$REPORT"; then
  fail "Review Report template contains hardcoded 'None.' placeholder"
fi
assert_required_sections_placeholder_clean() {
  local file="$1" section content
  for section in 'Findings' 'Open Questions Addressed' 'Evidence' 'Action / Blocker'; do
    content="$(extract_section "$file" "$section")"
    [[ -n "$content" ]] || return 1
    if grep -En '^[[:space:]]*None\.?[[:space:]]*$|None\.' <<<"$content"; then
      return 1
    fi
  done
}
bad_placeholders="$(mktemp)"
trap 'rm -f "$action_section" "$bad_placeholders"' EXIT
cat > "$bad_placeholders" <<'BAD'
# Review Report
## Findings
None.
## Open Questions Addressed
None.
## Evidence
None.
## Action / Blocker
None.
BAD
if assert_required_sections_placeholder_clean "$bad_placeholders" >/dev/null 2>&1; then
  fail "negative fixture with hardcoded None placeholders was not rejected"
fi
assert_required_sections_placeholder_clean "$REPORT" || fail "Review Report required sections contain hardcoded None placeholders"
for old_heading in \
  'Safety Checklist' \
  'State / Migration / Persistence Checklist' \
  'External-System and Credential Checklist' \
  'Praise'; do
  if grep -Eq "^##[[:space:]]+${old_heading}[[:space:]]*$" "$REPORT"; then
    fail "Review Report keeps old required top-level ${old_heading}; move it under optional annex/compact sections"
  fi
done

# terraform frontmatter + RED before GREEN
assert_path_readable terraform-tofu/SKILL.md
assert_path_readable terraform-tofu/reference/authoring.md
assert_path_readable terraform-tofu/reference/native-testing.md
frontmatter="$(awk 'NR == 1 { if ($0 != "---") exit 2; next } $0 == "---" { exit } { print }' terraform-tofu/SKILL.md)"
assert_text_contains "$frontmatter" 'name: terraform-tofu' 'skill name'
assert_text_contains "$frontmatter" 'Author or change Terraform/OpenTofu configuration' 'authoring trigger'
assert_text_contains "$frontmatter" 'another skill needs Terraform/OpenTofu implementation' 'skill-to-skill trigger'
assert_text_not_contains "$frontmatter" 'disable-model-invocation: true' 'disabled model invocation'
red_line="$(grep -n '^## 3\. Prove native RED$' terraform-tofu/SKILL.md | cut -d: -f1)"
green_line="$(grep -n '^## 4\. Make the smallest GREEN change$' terraform-tofu/SKILL.md | cut -d: -f1)"
[[ -n "$red_line" && -n "$green_line" && "$red_line" -lt "$green_line" ]] || fail 'native RED must precede GREEN'

printf '%s: PASS\n' "$TEST_NAME"
