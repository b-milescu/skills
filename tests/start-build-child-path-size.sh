#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'start-build-child-path-size: FAIL: %s\n' "$*" >&2
  exit 1
}

child_doc="start-build/reference/child-builder.md"
skill="start-build/SKILL.md"

# Baseline captured from origin/main before issue #129 split:
#   wc -l -w start-build/BUILD-FLOW.md
#        363    4254 start-build/BUILD-FLOW.md
baseline_lines=363
baseline_words=4254
max_lines=$((baseline_lines * 60 / 100))
max_words=$((baseline_words * 60 / 100))

[ -f "$child_doc" ] || fail "missing child-builder path doc: $child_doc"

child_lines="$(wc -l < "$child_doc" | tr -d ' ')"
child_words="$(wc -w < "$child_doc" | tr -d ' ')"

[ "$child_lines" -le "$max_lines" ] || \
  fail "$child_doc has $child_lines lines; expected <= $max_lines (60% of legacy BUILD-FLOW.md $baseline_lines lines)"
[ "$child_words" -le "$max_words" ] || \
  fail "$child_doc has $child_words words; expected <= $max_words (60% of legacy BUILD-FLOW.md $baseline_words words)"

grep -qF 'parent orchestrator owns the mandatory review gate' "$child_doc" || \
  fail "$child_doc missing parent-owned review gate boundary"
grep -qF 'must not start a reviewer' "$child_doc" || \
  fail "$child_doc missing child no-reviewer-launch rule"

if grep -qF 'subagent({ action: "list" })' "$child_doc"; then
  fail "$child_doc contains runtime-specific subagent discovery text"
fi

child_row="$(grep -F '| Child `mr-builder` |' "$skill" || true)"
[ -n "$child_row" ] || fail "$skill missing child mr-builder read-matrix row"
printf '%s' "$child_row" | grep -qF 'reference/child-builder.md' || \
  fail "$skill child row does not point to the child-builder path doc"

printf 'start-build-child-path-size: PASS (%s lines, %s words; legacy BUILD-FLOW.md baseline %s lines, %s words)\n' \
  "$child_lines" "$child_words" "$baseline_lines" "$baseline_words"
