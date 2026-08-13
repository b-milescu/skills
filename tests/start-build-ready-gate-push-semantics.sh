#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'start-build-ready-gate-push-semantics: FAIL: %s\n' "$*" >&2
  exit 1
}

safety="start-build/SAFETY.md"
flow="start-build/reference/implementation-flow.md"
schema="start-build/templates/reviewer-lift-schema.md"
delivery="issue-delivery-loop/SKILL.md"
parent="start-build/reference/parent-orchestrator.md"
parent_gate="start-build/reference/parent-owned-gate.md"
parent_gate_card="start-build/reference/parent-owned-gate-card.md"

if grep -qiE 'Run the (full )?(local )?gate locally before pushing|full Check Gate[^\n]*before pushing|full local gate[^\n]*before pushing' "$safety"; then
  fail "$safety still requires the full gate before pushing instead of before ready/review"
fi

grep -qF "Project's full check gate green before marking ready/requesting review, with exact-SHA Gate coverage classified" "$safety" || \
  fail "$safety missing ready/request-review exact-SHA Gate coverage boundary"

# Issue #316 deleted the start-build/BUILD-FLOW.md redirect layer; the
# implementation-flow content is validated only at its canonical owner ($flow).
for phrase in \
  "**Early Draft change-request push.**" \
  "**Implementation pushes before ready.**" \
  "**Ready-marking gate.**" \
  "**Gate coverage classification.**" \
  "**Full-local coverage.**" \
  "**Hybrid or CI-only coverage.**" \
  "**Parent-owned gate mode.**" \
  "**Post-ready push protocol.**"; do
  grep -qF "$phrase" "$flow" || fail "$flow missing push/gate phase: $phrase"
done

grep -qF "does not require the full local gate" "$flow" || \
  fail "$flow missing early Draft push exemption from the full local gate"
grep -qF "does not apply to early Draft change-request creation or pre-ready implementation pushes" "$flow" || \
  fail "$flow missing ready coverage scope exclusion for draft/pre-ready pushes"
grep -qF 'Gate coverage` to exactly one of `full-local`, `hybrid`, or `ci-only`' "$flow" || \
  fail "$flow missing full-local/hybrid/ci-only gate coverage enum"
if grep -Eq 'Gate coverage.*full-local.*/.*hybrid.*/.*ci-only.*/.*parent-owned' "$flow" "$schema"; then
  fail "Gate coverage enum includes parent-owned; ownership must be separate"
fi
for source in "$delivery" "$parent"; do
  grep -qF "in parallel with CI" "$source" || \
    fail "$source missing parallel reviewer-launch rule"
done
grep -qF "Review launch does not wait for terminal-success exact-commit CI" "$flow" || \
  fail "$flow missing hybrid/ci-only parallel reviewer-launch rule"
grep -qF "Failed, canceled, skipped, missing, stale, or wrong-commit required CI blocks pass eligibility and every finish action" "$flow" || \
  fail "$flow missing exact-commit CI fail-closed pass/finish guard"
if grep -qF "wait for exact-SHA CI success for each uncovered required job before marking ready/requesting review" "$flow"; then
  fail "$flow still pins the stale serial CI wait before review"
fi
grep -qF "exact candidate plus a passing parent Gate Receipt is sufficient to mark" "$parent_gate" || \
  fail "$parent_gate missing ready/review Gate Receipt boundary"
grep -qF "launch independent review while correctly bound required CI is" "$parent_gate" || \
  fail "$parent_gate missing pending-CI review-launch boundary"
grep -qF "wrong-commit required CI" "$parent_gate" || \
  fail "$parent_gate missing wrong-commit CI guard"
grep -qF "blocks pass eligibility and every finish action" "$parent_gate" || \
  fail "$parent_gate missing CI fail-closed action boundary"
grep -qF "review may launch while bound exact-commit CI is pending" "$parent_gate_card" || \
  fail "$parent_gate_card missing pending-CI review-launch pointer"
grep -qF "re-bind evidence after every push" "$flow" || \
  fail "$flow missing exact-SHA evidence invalidation after push"
grep -qF "child records \`Gate owner: parent\`, the parent-owned/not-run local gate contract, and the candidate commit only as gate evidence" "$flow" || \
  fail "$flow missing parent-owned child no-pass/fail boundary"

for field in "Gate owner" "Gate coverage" "Gate coverage rationale"; do
  grep -qF "| $field |" "$schema" || fail "$schema missing Reviewer Lift field: $field"
done
grep -qF '`hybrid`/`ci-only` review may start while exact-SHA CI is pending' "$schema" || \
  fail "$schema Local gate semantics still pin terminal-success CI before review"
grep -qF 'After every push, stale or wrong-SHA CI/local evidence is invalid' "$schema" || \
  fail "$schema missing exact-SHA evidence invalidation after push"
grep -qF 'after any post-ready push, include old SHA → new SHA, reason, changed files, gate rerun, and whether the change is substantive' "$schema" || \
  fail "$schema Delta since last ready push semantics lost post-ready delta requirements"

printf 'start-build-ready-gate-push-semantics: PASS\n'
