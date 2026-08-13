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

# Compact entrypoint owns routing; detailed trigger and exception policy stays in
# child-builder.md and implementation-flow.md.
skill="start-build/SKILL.md"
child="start-build/reference/child-builder.md"
flow="start-build/reference/implementation-flow.md"
schema="start-build/templates/reviewer-lift-schema.md"
review_packet="start-build/templates/review-packet.md"
compact_packet="start-build/templates/review-packet-compact.md"
review_report="start-review/templates/review-report.md"
safety="start-build/SAFETY.md"

canonical='Behavior-touching implementation follows TDD unless impossible or explicitly N/A with rationale in the change request.'
issue_scope='Work-item-driven work with sufficient acceptance criteria does not need a separate user-approval prompt before the first TDD slice.'
missing_scope='Missing or ambiguous behavior scope still routes back to triage with exact unanswered questions.'
runtime_examples='Runtime/operator/safety changes are examples of behavior-touching implementation, not a narrower TDD trigger.'
exception_fake_tests='Exception categories require a recorded rationale and must not allow fake tests or meaningless checks.'
headline_killing_mutation='For behavior-touching work, each headline claim in the MR body must name the mutation that kills its defending assertion.'
headline_scope='This is scoped to headline claims, not every assertion; do not run a full mutation battery per MR.'
incapable_shape='An assertion whose subject cannot be changed by any mutation of the code under test—for example, when no mock can move the observed state—is structurally incapable of failing and is not regression evidence.'
mutation_applied='A named killing mutation counts as evidence only when the harness proves the substitution applied by asserting its anchor matched exactly once before checking the result.'
mutation_failure='The observed failure message must match the guard under test; a non-zero exit alone cannot distinguish a fired guard from a parse or setup error.'

require_text "$skill" 'Behavior-changing work follows `tdd`: one observable RED→GREEN slice at a time.' "$skill missing compact TDD contract"
require_text "$skill" 'Docs/config/mechanical work records `TDD: N/A — <reason>` rather than fake tests.' "$skill missing compact N/A/no-fake-tests contract"
reject_text "$skill" 'For runtime/operator/safety behavior changes, load and follow the `tdd` skill.' "$skill still uses a narrower TDD trigger"

for file in "$child" "$flow"; do
  require_text "$file" "$canonical" "$file missing canonical behavior-touching TDD trigger"
  require_text "$file" "$runtime_examples" "$file missing runtime/operator/safety examples"
  require_text "$file" "$exception_fake_tests" "$file missing exception rationale / no-fake-tests policy"
  require_text "$file" "$issue_scope" "$file missing issue-driven no-extra-approval policy"
  require_text "$file" "$missing_scope" "$file missing missing-scope triage routing policy"
done

for file in "$schema" "$review_packet" "$compact_packet" "$review_report"; do
  require_text "$file" 'behavior-touching implementation' "$file Reviewer Lift RED/GREEN wording missing behavior-touching implementation language"
  require_text "$file" 'N/A with rationale' "$file Reviewer Lift RED/GREEN wording missing N/A rationale requirement"
  require_text "$file" 'do not fake tests' "$file Reviewer Lift RED/GREEN wording missing no-fake-tests guard"
done

require_text "$safety" "$headline_killing_mutation" "$safety missing named killing mutation requirement for headline claims"
require_text "$safety" "$headline_scope" "$safety missing headline-only scope and full-battery guard"
require_text "$safety" "$incapable_shape" "$safety missing structurally-incapable assertion shape"
require_text "$safety" "$mutation_applied" "$safety missing exact-once mutation-application evidence requirement"
require_text "$safety" "$mutation_failure" "$safety missing guard-specific failure-message and non-zero-exit requirement"

printf 'start-build-tdd-trigger-policy: PASS\n'
