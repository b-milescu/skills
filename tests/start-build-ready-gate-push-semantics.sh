#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'start-build-ready-gate-push-semantics: FAIL: %s\n' "$*" >&2
  exit 1
}

safety="start-build/SAFETY.md"
flow="start-build/BUILD-FLOW.md"
schema="start-build/templates/reviewer-lift-schema.md"

if grep -qiE 'Run the (full )?(local )?gate locally before pushing|full Check Gate[^\n]*before pushing|full local gate[^\n]*before pushing' "$safety"; then
  fail "$safety still requires the full gate before pushing instead of before ready/review"
fi

grep -qF "Project's full check gate green before marking ready/requesting review" "$safety" || \
  fail "$safety missing ready/request-review gate boundary"

for phrase in \
  "**Early Draft MR push.**" \
  "**Implementation pushes before ready.**" \
  "**Ready-marking gate.**" \
  "**Post-ready push protocol.**"; do
  grep -qF "$phrase" "$flow" || fail "$flow missing push phase: $phrase"
done

grep -qF "does not require the full local gate" "$flow" || \
  fail "$flow missing early Draft push exemption from the full local gate"
grep -qF "full local gate is required before marking ready or requesting review" "$flow" || \
  fail "$flow missing ready/request-review gate requirement"

grep -qF '`PASS` is required before marking ready/requesting review unless `N/A` explains why only CI can provide the gate' "$schema" || \
  fail "$schema Local gate semantics are not synchronized with ready-marking boundary"
grep -qF 'after any post-ready push, include old SHA → new SHA, reason, changed files, gate rerun, and whether the change is substantive' "$schema" || \
  fail "$schema Delta since last ready push semantics lost post-ready delta requirements"

printf 'start-build-ready-gate-push-semantics: PASS\n'
