#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'start-build-tdd-trigger-policy: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1"
  local needle="$2"
  local message="$3"
  grep -qF "$needle" "$file" || fail "$message"
}

reject_text() {
  local file="$1"
  local needle="$2"
  local message="$3"
  if grep -qF "$needle" "$file"; then
    fail "$message"
  fi
}

# Issue #316 deleted start-build/BUILD-FLOW.md; the canonical behavior-touching
# TDD trigger sentence is validated at SKILL.md, child-builder.md, and
# implementation-flow.md (its canonical owners).
skill="start-build/SKILL.md"
child="start-build/reference/child-builder.md"
flow="start-build/reference/implementation-flow.md"
schema="start-build/templates/reviewer-lift-schema.md"
review_packet="start-build/templates/review-packet.md"
compact_packet="start-build/templates/review-packet-compact.md"
review_report="start-review/templates/review-report.md"

canonical='Behavior-touching implementation follows TDD unless impossible or explicitly N/A with rationale in the MR.'
issue_scope='Issue-driven work with sufficient acceptance criteria does not need a separate user-approval prompt before the first TDD slice.'
missing_scope='Missing or ambiguous behavior scope still routes back to triage with exact unanswered questions.'
runtime_examples='Runtime/operator/safety changes are examples of behavior-touching implementation, not a narrower TDD trigger.'
exception_fake_tests='Exception categories require MR rationale and must not allow fake tests or meaningless checks.'

for file in "$skill" "$child" "$flow"; do
  require_text "$file" "$canonical" "$file missing canonical behavior-touching TDD trigger"
done

require_text "$skill" "$runtime_examples" "$skill missing runtime/operator/safety-as-examples wording"
reject_text "$skill" 'For runtime/operator/safety behavior changes, load and follow the `tdd` skill.' "$skill still uses runtime/operator/safety as the narrower TDD trigger"

for file in "$skill" "$child" "$flow"; do
  require_text "$file" "$exception_fake_tests" "$file missing exception rationale / no-fake-tests policy"
  require_text "$file" "$issue_scope" "$file missing issue-driven no-extra-approval policy"
  require_text "$file" "$missing_scope" "$file missing missing-scope triage routing policy"
done

for file in "$schema" "$review_packet" "$compact_packet" "$review_report"; do
  require_text "$file" 'behavior-touching implementation' "$file Reviewer Lift RED/GREEN wording missing behavior-touching implementation language"
  require_text "$file" 'N/A with rationale' "$file Reviewer Lift RED/GREEN wording missing N/A rationale requirement"
  require_text "$file" 'do not fake tests' "$file Reviewer Lift RED/GREEN wording missing no-fake-tests guard"
done

printf 'start-build-tdd-trigger-policy: PASS\n'
