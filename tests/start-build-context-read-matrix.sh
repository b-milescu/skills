#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'start-build-context-read-matrix: FAIL: %s\n' "$*" >&2
  exit 1
}

skill="start-build/SKILL.md"

matrix_start="$(grep -n '^## Mode routing context read matrix$' "$skill" | cut -d: -f1 || true)"
quick_start="$(grep -n '^## Quick start$' "$skill" | cut -d: -f1 || true)"

[ -n "$matrix_start" ] || fail "$skill missing Mode routing context read matrix section"
[ -n "$quick_start" ] || fail "$skill missing Quick start section"
[ "$matrix_start" -lt "$quick_start" ] || fail "read matrix must appear before Quick start"
[ $((quick_start - matrix_start)) -le 80 ] || fail "read matrix must stay near Quick start"

matrix_block="$(sed -n "${matrix_start},$((quick_start - 1))p" "$skill")"

printf '%s\n' "$matrix_block" | grep -qF '| Mode | Required files / sections | Optional expansion | Stop / avoid |' || \
  fail "read matrix missing required/optional/avoid table headers"

for mode in \
  'Parent orchestrator' \
  'Standalone builder' \
  'Child `mr-builder`' \
  'Revision builder' \
  'Docs-only/config-only builder' \
  'Multi-issue coordinator'
do
  row="$(printf '%s\n' "$matrix_block" | grep -F "| ${mode} |" || true)"
  [ -n "$row" ] || fail "read matrix missing mode row: $mode"
  cell_count="$(printf '%s' "$row" | awk -F'|' '{ print NF - 2 }')"
  [ "$cell_count" -eq 4 ] || fail "mode row must have four cells: $mode"
  if printf '%s' "$row" | grep -qE '\|[[:space:]]*\|'; then
    fail "mode row has empty cell: $mode"
  fi
done

child_row="$(printf '%s\n' "$matrix_block" | grep -F '| Child `mr-builder` |')"
# Issue #316 deleted start-build/BUILD-FLOW.md and repointed the child row's
# compatibility anchors to their canonical reference owners: the child-mode
# anchor is now reference/child-builder.md, and the post-merge-verifier anchor
# is now reference/post-merge-verifier.md.
for required_anchor in \
  'reference/child-builder.md' \
  'templates/reviewer-lift-schema.md' \
  'templates/builder-final-handoff.md' \
  'reference/parent-orchestrator.md#parent-loop' \
  'reference/standalone-gate.md#reviewer-launch-protocol' \
  'reference/post-merge-verifier.md'
do
  printf '%s' "$child_row" | grep -qF "$required_anchor" || fail "child row missing anchor: $required_anchor"
done

for phrase in 'merge/finish' 'unless parent changes role scope'; do
  printf '%s' "$child_row" | grep -qF "$phrase" || fail "child row missing avoid-list phrase: $phrase"
done

# Child required context must be smaller than the old BUILD-FLOW path: parent and
# standalone gate details are avoid-list/optional, not required reads.
child_required_cell="$(printf '%s' "$child_row" | awk -F'|' '{ print $3 }')"
if printf '%s' "$child_required_cell" | grep -qF 'reference/parent-orchestrator.md'; then
  fail "child required cell includes parent-orchestrator detail"
fi
if printf '%s' "$child_required_cell" | grep -qF 'reference/standalone-gate.md'; then
  fail "child required cell includes standalone gate detail"
fi

# Issue-pickup policy is canonical in one reference; every mode that selects or
# accepts issues must point to it instead of carrying a partial local copy.
pickup_policy="start-build/reference/issue-pickup.md"
for phrase in \
  'read the issue description and all current issue notes before planning or editing.' \
  'notes carry the current state' \
  'source precedence' \
  'human escalation'
do
  grep -qF "$phrase" "$pickup_policy" || fail "issue-pickup policy missing phrase: $phrase"
done

for mode in \
  'Parent orchestrator' \
  'Standalone builder' \
  'Child `mr-builder`' \
  'Multi-issue coordinator'
do
  row="$(printf '%s\n' "$matrix_block" | grep -F "| ${mode} |")"
  printf '%s' "$row" | grep -qF 'reference/issue-pickup.md' || \
    fail "issue-picking mode missing canonical issue-pickup pointer: $mode"
done

docs_row="$(printf '%s\n' "$matrix_block" | grep -F '| Docs-only/config-only builder |')"
for phrase in 'templates/review-packet-compact.md' 'Check Gate' 'TDD: N/A' 'unless behavior becomes touched'; do
  printf '%s' "$docs_row" | grep -qF "$phrase" || fail "docs-only row missing phrase: $phrase"
done

printf 'start-build-context-read-matrix: PASS\n'
