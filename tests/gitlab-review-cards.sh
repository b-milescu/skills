#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'gitlab-review-cards: FAIL: %s\n' "$*" >&2
  exit 1
}

require_file() {
  local file="$1"
  [[ -f "$file" ]] || fail "missing card $file"
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eq -- "$pattern" "$file" || fail "$file missing $label"
}

reject_text() {
  local file="$1" pattern="$2" label="$3"
  if grep -En -- "$pattern" "$file" >&2; then
    fail "$file contains $label"
  fi
}

require_card_contract() {
  local file="$1"
  require_file "$file"
  require_text "$file" '\.\./SKILL\.md' 'full gitlab/SKILL.md ownership pointer'
  require_text "$file" 'help-first' 'help-first pointer'
  require_text "$file" '^## Snippets' 'Snippets section'
  require_text "$file" '^## Fallback to full gitlab' 'fallback section'
  require_text "$file" 'Inputs' 'Inputs column/section'
  require_text "$file" 'Outputs' 'Outputs column/section'
  require_text "$file" 'Fail closed' 'Fail closed column/section'
  reject_text "$file" '```' 'raw command code fence'
  reject_text "$file" '(^|[[:space:]])glab[[:space:]]+(issue|mr|ci|repo|api)\b' 'raw glab command copy'
}

read_card="gitlab/reference/review-read.md"
action_card="gitlab/reference/review-actions.md"
ci_card="gitlab/reference/ci.md"

for card in "$read_card" "$action_card" "$ci_card"; do
  require_card_contract "$card"
done

for snippet in local-repo-preflight issue-pickup mr-pickup artifact-capture; do
  require_text "$read_card" "\.\./SKILL\.md#snippet-${snippet}" "${snippet} snippet link"
done

for snippet in mr-note-create issue-note-create sha-guard sha-bound-approval sha-bound-merge sha-bound-auto-merge-queue approval-confirmation finish-mr-authority-aware; do
  require_text "$action_card" "\.\./SKILL\.md#snippet-${snippet}" "${snippet} snippet link"
done

for snippet in ci-decision-snapshot ci-watch-sha-pinned; do
  require_text "$ci_card" "\.\./SKILL\.md#snippet-${snippet}" "${snippet} snippet link"
done

require_text "$action_card" 'MR comments only' 'MR-note target split rule'
require_text "$action_card" 'issue workflow explicitly calls' 'issue-note target split rule'

for card in review-read review-actions ci; do
  require_text "forge/reference/gitlab.md" "gitlab/reference/${card}\.md" "${card} card link"
done
require_text "forge/reference/gitlab.md" 'gitlab/SKILL\.md' 'full-reference fallback guidance'
for file in start-review/SKILL.md start-review/REVIEW-FLOW.md; do
  reject_text "$file" 'gitlab/reference/(review-read|review-actions|ci)\.md' 'direct generic GitLab card ownership'
done

require_text "gitlab/SKILL.md" 'reference/review-read.md' 'review-read discoverability link'
require_text "gitlab/SKILL.md" 'reference/review-actions.md' 'review-actions discoverability link'
require_text "gitlab/SKILL.md" 'reference/ci.md' 'ci card discoverability link'

printf 'gitlab-review-cards: PASS\n'
