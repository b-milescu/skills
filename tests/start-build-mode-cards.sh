#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() { printf 'start-build-mode-cards: FAIL: %s\n' "$*" >&2; exit 1; }
require() { grep -Eiq -- "$2" "$1" || fail "$1 missing $3"; }
reject() { ! grep -Eiq -- "$2" "$1" || fail "$1 contains $3"; }

deleted=(
  start-build/reference/child-builder-card.md
  start-build/reference/parent-owned-gate-card.md
  start-build/reference/revision-card.md
  start-build/reference/parent-orchestrator-card.md
)

for card in "${deleted[@]}"; do
  [[ ! -e "$card" ]] || fail "$card must be deleted"
done

canonical=(
  start-build/reference/child-builder.md
  start-build/reference/parent-owned-gate.md
  start-build/reference/implementation-flow.md
  start-build/reference/parent-orchestrator.md
)

for file in "${canonical[@]}"; do
  [[ -f "$file" ]] || fail "missing canonical $file"
  require start-build/SKILL.md "skill://start-build/reference/$(basename "$file")" "$(basename "$file") discoverability"
done

reject start-build/SKILL.md 'child-builder-card|parent-owned-gate-card|revision-card|parent-orchestrator-card' 'deleted mode-card path'
reject start-build/SKILL.md 'Compact pointer maps' 'retired pointer-map framing'

printf 'start-build-mode-cards: PASS\n'
