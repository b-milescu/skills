#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() { printf 'start-build-mode-cards: FAIL: %s\n' "$*" >&2; exit 1; }
require() { grep -Eiq -- "$2" "$1" || fail "$1 missing $3"; }
reject() { ! grep -Eiq -- "$2" "$1" || fail "$1 contains $3"; }

cards=(
  start-build/reference/child-builder-card.md
  start-build/reference/parent-owned-gate-card.md
  start-build/reference/revision-card.md
  start-build/reference/parent-orchestrator-card.md
)

for card in "${cards[@]}"; do
  require "$card" 'pointer map' 'pointer-map contract'
  require "$card" 'not an alternate policy source' 'not-policy-source contract'
  require "$card" '^## Checklist$' 'Checklist'
  require "$card" '^## Fallback to canonical docs$' 'canonical fallback'
  require "$card" 'skill://forge/reference/common-guard.md' 'common guard owner'
  require "$card" 'forge snapshot' 'snapshot verb'
  require "$card" 'ci-decision-table' 'CI policy pointer'
  require "$card" 'authority' 'authority boundary'
  require "$card" 'child-builder' 'child boundary'
  require "$card" 'Gate Receipt|gate-receipt' 'Gate Receipt'
  require "$card" 'post-merge-verifier' 'read-only verifier pointer'
  for trigger in 'ambiguity' 'missing field' 'transport/help drift' 'authority uncertainty' 'SHA/CI mismatch' 'cross-project binding' 'partial review' 'any mutation action'; do
    require "$card" "$trigger" "fallback trigger $trigger"
  done
  reject "$card" 'GitLab|glab|Closes #[<0-9]|get_post_merge_snapshot|local-repo-preflight|draft-mr|mr-description|safe-mr-json|sha-guard|ci-watch-sha-pinned|finish-mr-authority-aware|mr-note-create' 'retired provider mechanics'
  reject "$card" '```' 'raw command block'
done

require "${cards[0]}" 'forge preflight' 'child preflight'
require "${cards[0]}" 'forge publish' 'child publication'
require "${cards[1]}" 'guarded `forge act`' 'guarded ready action'
require "${cards[2]}" 'forge publish' 'revision publication'
require "${cards[3]}" 'forge preflight' 'parent preflight'
require "${cards[3]}" 'guarded `forge act`' 'parent action'
require "${cards[3]}" 'forge post_merge_snapshot' 'post-merge snapshot'

require "${cards[0]}" 'child-builder.md#child-checklist' 'child checklist anchor'
require "${cards[0]}" 'child-builder.md#authority-boundary' 'child authority anchor'
require "${cards[1]}" 'parent-owned-gate.md#parent-verification-checklist' 'parent checklist anchor'
require "${cards[1]}" 'parent-owned-gate.md#gate-receipt-schema' 'receipt schema anchor'
require "${cards[2]}" 'implementation-flow.md#procedure' 'revision procedure anchor'
require "${cards[2]}" 'revision-packet.md' 'revision packet'
require "${cards[3]}" 'parent-orchestrator.md#parent-loop' 'parent loop anchor'

for card in child-builder-card parent-owned-gate-card revision-card parent-orchestrator-card; do
  require start-build/SKILL.md "skill://start-build/reference/${card}.md" "$card discoverability"
done
require start-build/SKILL.md 'Compact pointer maps' 'pointer-map framing'

printf 'start-build-mode-cards: PASS\n'
