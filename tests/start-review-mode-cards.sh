#!/usr/bin/env bash
# Focus: Deleted `start-review` mode cards stay gone; `SKILL.md` points at
# REVIEW-FLOW, review-report, and reviewer-final-handoff instead of checklist
# cards.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() { printf 'start-review-mode-cards: FAIL: %s\n' "$*" >&2; exit 1; }
require() { grep -Eiq -- "$2" "$1" || fail "$1 missing $3"; }
reject() { ! grep -Eiq -- "$2" "$1" || fail "$1 contains $3"; }

deleted=(
  start-review/reference/single-mr-review-card.md
  start-review/reference/request-changes-rerun-card.md
  start-review/reference/finish-action-card.md
  start-review/reference/blocked-review-routing-card.md
)

for card in "${deleted[@]}"; do
  [[ ! -e "$card" ]] || fail "$card must be deleted"
done

require start-review/SKILL.md 'skill://start-review/REVIEW-FLOW.md' 'REVIEW-FLOW discoverability'
require start-review/SKILL.md 'skill://start-review/templates/review-report.md' 'review-report discoverability'
require start-review/SKILL.md 'skill://start-review/templates/reviewer-final-handoff.md' 'final-handoff discoverability'
reject start-review/SKILL.md 'single-mr-review-card|request-changes-rerun-card|finish-action-card|blocked-review-routing-card' 'deleted mode-card path'
reject start-review/SKILL.md 'Compact pointer maps' 'retired pointer-map framing'

printf 'start-review-mode-cards: PASS\n'
