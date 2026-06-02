#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'start-build-mode-cards: FAIL: %s\n' "$*" >&2
  exit 1
}

require_file() {
  local file="$1"
  [[ -f "$file" ]] || fail "missing compact mode card: $file"
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eq -- "$pattern" "$file" || fail "$file missing $label"
}

reject_text() {
  local file="$1" pattern="$2" label="$3"
  local tmp="${TMPDIR:-/tmp}/start-build-mode-cards.$$"
  if grep -En -- "$pattern" "$file" >"$tmp"; then
    cat "$tmp" >&2
    rm -f "$tmp"
    fail "$file contains $label"
  fi
  rm -f "$tmp"
}

require_card_contract() {
  local file="$1"
  require_file "$file"
  require_text "$file" 'pointer map|pointer-map' 'pointer-map wording'
  require_text "$file" 'not an alternate policy source' 'not-policy-source wording'
  require_text "$file" '^## Checklist' 'Checklist section'
  require_text "$file" '^## Fallback to canonical docs' 'canonical fallback section'
  reject_text "$file" '```' 'raw command/code fence'
  reject_text "$file" '(^|[[:space:]])glab[[:space:]]+(issue|mr|ci|repo|api)\b' 'raw glab command copy'
  reject_text "$file" '(^|[[:space:]])git[[:space:]]+(status|fetch|checkout|pull|push|rev-parse|ls-remote|merge|branch)\b' 'raw git command copy'

  for trigger in \
    'ambiguity' \
    'missing field' \
    'CLI/help drift' \
    'authority uncertainty' \
    'SHA/CI mismatch' \
    'cross-project binding' \
    'partial review' \
    'any mutation action'; do
    require_text "$file" "$trigger" "fallback trigger: $trigger"
  done

  require_text "$file" 'sha-guard' 'final SHA guard pointer'
  require_text "$file" 'ci-decision-table' 'CI decision policy pointer'
  require_text "$file" 'authority' 'authority source verification pointer'
  require_text "$file" 'child-builder.*authority-boundary|child-builder-card\.md' 'child-builder boundary pointer'
  require_text "$file" 'Gate Receipt|gate-receipt' 'Gate Receipt pointer'
  require_text "$file" 'post-merge-verifier' 'post-merge verifier read-only pointer'
  reject_text "$file" 'post-merge-verifier/SKILL[.]md' 'removed top-level verifier skill pointer'
}

child_card="start-build/reference/child-builder-card.md"
parent_gate_card="start-build/reference/parent-owned-gate-card.md"
revision_card="start-build/reference/revision-card.md"
parent_card="start-build/reference/parent-orchestrator-card.md"

for card in "$child_card" "$parent_gate_card" "$revision_card" "$parent_card"; do
  require_card_contract "$card"
done

# Accepted compact card names stay discoverable from the primary start-build entry points.
for owner in start-build/SKILL.md start-build/BUILD-FLOW.md; do
  for card_name in \
    'child-builder-card\.md' \
    'parent-owned-gate-card\.md' \
    'revision-card\.md' \
    'parent-orchestrator-card\.md'; do
    require_text "$owner" "$card_name" "discoverability link $card_name"
  done
  require_text "$owner" 'pointer maps|pointer-map' 'pointer-only card framing'
  require_text "$owner" 'any mutation action' 'mutation fallback trigger'
done

# Snippet names are stable API; cards should link to names, never paste command bodies.
for snippet in \
  local-repo-preflight \
  issue-pickup \
  draft-mr-create \
  mr-description-update \
  mr-pickup \
  safe-mr-json \
  sha-guard \
  ci-decision-snapshot \
  ci-watch-sha-pinned \
  finish-mr-authority-aware \
  mr-note-create \
  draft-mr-mark-ready; do
  grep -R "SKILL\.md#snippet-${snippet}" start-build/reference/*-card.md >/dev/null || \
    fail "missing accepted gitlab-local snippet pointer: $snippet"
done

# Canonical start-build anchors stay referenced instead of restating policy.
require_text "$child_card" 'child-builder\.md#child-checklist' 'child checklist canonical anchor'
require_text "$child_card" 'child-builder\.md#authority-boundary' 'child authority canonical anchor'
require_text "$parent_gate_card" 'parent-orchestrator\.md#parent-owned-gate-receipt-mode' 'parent Gate Receipt canonical anchor'
require_text "$parent_gate_card" 'gitlab-delivery-schema\.md#gate-receipt-schema' 'Gate Receipt schema anchor'
require_text "$revision_card" 'implementation-flow\.md#procedure' 'revision procedure canonical anchor'
require_text "$revision_card" 'revision-packet\.md' 'revision packet template pointer'
require_text "$parent_card" 'parent-orchestrator\.md#parent-loop' 'parent loop canonical anchor'
require_text "$parent_card" 'post-merge-verifier\.md' 'post-merge verifier canonical anchor'

printf 'start-build-mode-cards: PASS\n'
