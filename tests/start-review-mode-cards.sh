#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'start-review-mode-cards: FAIL: %s\n' "$*" >&2
  exit 1
}

require_file() {
  local file="$1"
  [[ -f "$file" ]] || fail "missing compact mode card: $file"
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

reject_text() {
  local file="$1" pattern="$2" label="$3"
  local tmp="${TMPDIR:-/tmp}/start-review-mode-cards.$$"
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
    'suspected secret exposure' \
    'grouped action pressure' \
    'any mutation action'; do
    require_text "$file" "$trigger" "fallback trigger: $trigger"
  done

  for anchor in \
    'REVIEW-FLOW\.md#context-firewall' \
    'REVIEW-FLOW\.md#review-context-capsule' \
    'REVIEW-FLOW\.md#fail-closed-review-coverage' \
    'REVIEW-FLOW\.md#ci-decision-table' \
    'REVIEW-FLOW\.md#open-question-decision-table' \
    'REVIEW-FLOW\.md#authority-source-precedence' \
    'REVIEW-FLOW\.md#project-binding'; do
    require_text "$file" "$anchor" "canonical anchor: $anchor"
  done

  require_text "$file" 'review-read\.md|review-actions\.md|ci\.md|gitlab-local' 'gitlab-local card/helper pointer'
  require_text "$file" 'Snippet: mr-pickup|Snippet: mr-note-create|Snippet: sha-guard|Snippet: ci-decision-snapshot' 'accepted snippet-name pointer'
  require_text "$file" 'final MR/CI/authority snapshot|final[^.]*MR[^.]*CI[^.]*authority[^.]*snapshot' 'final MR/CI/authority snapshot before report posting'
  require_text "$file" 'sha-guard[^.]*immediately before|immediately before[^.]*sha-guard' 'fresh SHA guard before approval/finish actions'
  require_text "$file" 'approval' 'approval guard mention'
  require_text "$file" 'direct merge' 'direct merge guard mention'
  require_text "$file" 'auto-merge queue|queue auto-merge|auto-merge' 'auto-merge queue guard mention'
  require_text "$file" 'never group|no grouped|Choose one action|one action' 'grouped action prohibition'
  require_text "$file" 'partial-review' 'partial-review blocker token'
  require_text "$file" 'secret-exposure-suspected' 'secret-exposure blocker token'
}

single_card="start-review/reference/single-mr-review-card.md"
rerun_card="start-review/reference/request-changes-rerun-card.md"
finish_card="start-review/reference/finish-action-card.md"
blocked_card="start-review/reference/blocked-review-routing-card.md"

for card in "$single_card" "$rerun_card" "$finish_card" "$blocked_card"; do
  require_card_contract "$card"
done

for owner in start-review/SKILL.md start-review/REVIEW-FLOW.md; do
  for card in \
    'single-mr-review-card\.md' \
    'request-changes-rerun-card\.md' \
    'finish-action-card\.md' \
    'blocked-review-routing-card\.md'; do
    require_text "$owner" "$card" "$card discoverability link"
  done
  require_text "$owner" 'fall back .*gitlab-local/SKILL\.md|fallback .*gitlab-local/SKILL\.md|Fallback .*gitlab-local/SKILL\.md' 'full gitlab-local fallback guidance'
done

require_text "$single_card" 'one MR.*one fresh reviewer session|one fresh reviewer session.*one MR' 'single-MR fresh-session scope'
require_text "$rerun_card" 'revision packet|Delta since last ready push|builder revision' 'request-changes revision evidence pointer'
require_text "$finish_card" 'finish-mr-authority-aware|sha-bound-merge|sha-bound-auto-merge-queue' 'finish action helper/snippet pointer'
require_text "$blocked_card" 'Action blocker|review_verdict: blocked|blocked Review Report' 'blocked routing vocabulary'

printf 'start-review-mode-cards: PASS\n'
