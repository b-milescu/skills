#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'start-build-ready-gate-push-semantics: FAIL: %s\n' "$*" >&2
  exit 1
}

safety="start-build/SAFETY.md"
router="start-build/BUILD-FLOW.md"
flow="start-build/reference/implementation-flow.md"
schema="start-build/templates/reviewer-lift-schema.md"

if grep -qiE 'Run the (full )?(local )?gate locally before pushing|full Check Gate[^\n]*before pushing|full local gate[^\n]*before pushing' "$safety"; then
  fail "$safety still requires the full gate before pushing instead of before ready/review"
fi

grep -qF "Project's full check gate green before marking ready/requesting review, with exact-SHA Gate coverage classified" "$safety" || \
  fail "$safety missing ready/request-review exact-SHA Gate coverage boundary"

grep -qF 'reference/implementation-flow.md' "$router" || \
  fail "$router missing implementation-flow canonical link"

for phrase in \
  "**Early Draft MR push.**" \
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
grep -qF "does not apply to early Draft MR creation or pre-ready implementation pushes" "$flow" || \
  fail "$flow missing ready coverage scope exclusion for draft/pre-ready pushes"
grep -qF 'Gate coverage` to exactly one of `full-local`, `hybrid`, or `ci-only`' "$flow" || \
  fail "$flow missing full-local/hybrid/ci-only gate coverage enum"
if grep -Eq 'Gate coverage.*full-local.*/.*hybrid.*/.*ci-only.*/.*parent-owned' "$flow" "$schema"; then
  fail "Gate coverage enum includes parent-owned; ownership must be separate"
fi
grep -qF "even if exact-SHA CI is still pending or unavailable" "$flow" || \
  fail "$flow missing full-local pending/unavailable CI handoff rule"
grep -qF "wait for exact-SHA CI success for each uncovered required job" "$flow" || \
  fail "$flow missing hybrid/ci-only exact-SHA CI wait rule"
grep -qF "Failed, canceled, skipped, missing, stale, or wrong-SHA required CI blocks ready handoff" "$flow" || \
  fail "$flow missing CI blocker states before ready handoff"
grep -qF "re-bind evidence after every push" "$flow" || \
  fail "$flow missing exact-SHA evidence invalidation after push"
grep -qF "child records \`Gate owner: parent\`, the parent-owned/not-run local gate contract, and the candidate SHA only as gate evidence" "$flow" || \
  fail "$flow missing parent-owned child no-pass/fail boundary"

for field in "Gate owner" "Gate coverage" "Gate coverage rationale"; do
  grep -qF "| $field |" "$schema" || fail "$schema missing Reviewer Lift field: $field"
done
grep -qF '`PASS` before ready/requesting review is sufficient only when `Gate coverage` is `full-local`' "$schema" || \
  fail "$schema Local gate semantics are not synchronized with ready coverage policy"
grep -qF 'After every push, stale or wrong-SHA CI/local evidence is invalid' "$schema" || \
  fail "$schema missing exact-SHA evidence invalidation after push"
grep -qF 'after any post-ready push, include old SHA → new SHA, reason, changed files, gate rerun, and whether the change is substantive' "$schema" || \
  fail "$schema Delta since last ready push semantics lost post-ready delta requirements"

printf 'start-build-ready-gate-push-semantics: PASS\n'
