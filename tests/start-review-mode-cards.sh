#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() { printf 'start-review-mode-cards: FAIL: %s\n' "$*" >&2; exit 1; }
require() { grep -Eiq -- "$2" "$1" || fail "$1 missing $3"; }
reject() { ! grep -Eiq -- "$2" "$1" || fail "$1 contains $3"; }

cards=(
  start-review/reference/single-mr-review-card.md
  start-review/reference/request-changes-rerun-card.md
  start-review/reference/finish-action-card.md
  start-review/reference/blocked-review-routing-card.md
)

for card in "${cards[@]}"; do
  require "$card" 'pointer map/checklist' 'pointer-map contract'
  require "$card" 'not an alternate policy source' 'not-policy contract'
  require "$card" '^## Checklist$' 'Checklist'
  require "$card" '^## Fallback to canonical docs$' 'canonical fallback'
  require "$card" 'skill://forge/reference/common-guard.md' 'ordered common guard'
  require "$card" 'forge snapshot' 'snapshot verb'
  require "$card" 'provider-native (snapshot/)?readback|provider-native action readback' 'provider-native readback'
  require "$card" 'reviewed commit' 'reviewed-commit binding'
  require "$card" 'CI' 'bound CI'
  require "$card" 'authority' 'authority boundary'
  require "$card" 'exactly one|one authorized action|No approval or finish' 'single-action boundary'
  require "$card" 'selected `/forge` provider reference' 'selected-provider fallback'
  require "$card" 'ambiguity' 'ambiguity fallback'
  require "$card" 'missing field' 'missing-field fallback'
  require "$card" 'transport/help drift' 'transport fallback'
  require "$card" 'authority uncertainty' 'authority fallback'
  require "$card" 'commit/CI mismatch' 'commit/CI fallback'
  require "$card" 'cross-project binding' 'binding fallback'
  require "$card" 'partial review' 'partial-review fallback'
  require "$card" 'suspected secret exposure' 'secret fallback'
  require "$card" 'grouped action pressure' 'grouped-action fallback'
  require "$card" 'any mutation action' 'mutation fallback'
  reject "$card" '(^|[[:space:]`])git(lab)?[[:space:]]+(status|fetch|checkout|pull|push|rev-parse|ls-remote|merge|branch|issue|mr|ci|repo|api)|Snippet:|gitlab/SKILL|review-(read|actions)[.]md|sha-guard|sha-bound|finish-mr|direct merge|MR URL|one MR|Reviewed SHA|exact-SHA' 'raw or provider-specific mechanics'
  reject "$card" '```' 'raw command block'
  lines="$(wc -l < "$card")"
  (( lines <= 60 )) || fail "$card exceeds compact size: $lines lines"
done

single="${cards[0]}"; rerun="${cards[1]}"; finish="${cards[2]}"; blocked="${cards[3]}"
require "$single" 'one change request per fresh reviewer' 'fresh single review'
require "$single" 'Context Firewall' 'context firewall'
require "$single" 'Fail-closed review coverage' 'coverage owner'
require "$rerun" 'revision packet' 'revision evidence'
require "$rerun" 'Prior Review Report' 'prior report binding'
require "$rerun" 'current delta' 'revision delta'
require "$finish" 'Approval authority never implies finish authority' 'approval/finish separation'
require "$finish" 'guarded `forge act`' 'guarded action'
require "$blocked" 'partial-review' 'partial review token'
require "$blocked" 'secret-exposure-suspected' 'secret token'
require "$blocked" 'No approval or finish' 'blocked action boundary'

for card in single-mr-review-card request-changes-rerun-card finish-action-card blocked-review-routing-card; do
  require start-review/SKILL.md "skill://start-review/reference/${card}.md" "$card discoverability"
done
require start-review/SKILL.md 'Compact pointer maps' 'pointer-map framing'

printf 'start-review-mode-cards: PASS\n'
