#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'gitlab-build-cards: FAIL: %s\n' "$*" >&2
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

read_card="gitlab/reference/build-read.md"
action_card="gitlab/reference/build-actions.md"

for card in "$read_card" "$action_card"; do
  require_card_contract "$card"
done

for snippet in local-repo-preflight issue-pickup; do
  require_text "$read_card" "\.\./SKILL\.md#snippet-${snippet}" "${snippet} snippet link"
done

for snippet in draft-mr-create draft-mr-mark-ready mr-description-update mr-note-create issue-note-create; do
  require_text "$action_card" "\.\./SKILL\.md#snippet-${snippet}" "${snippet} snippet link"
done

# build-actions must NOT contain approval/merge/finish snippet names (least-privilege)
for forbidden in sha-bound-approval sha-bound-merge sha-bound-auto-merge-queue finish-mr-authority-aware; do
  if grep -Eq -- "snippet-${forbidden}" "$action_card"; then
    fail "$action_card must not contain forbidden snippet reference: $forbidden"
  fi
done

# The selected /forge GitLab branch owns card links and fallback.
require_text "forge/reference/gitlab.md" 'gitlab/reference/build-read\.md' 'build-read card link'
require_text "forge/reference/gitlab.md" 'gitlab/reference/build-actions\.md' 'build-actions card link'
require_text "forge/reference/gitlab.md" 'gitlab/SKILL\.md' 'full-reference fallback guidance'
reject_text "start-build/SKILL.md" 'gitlab/reference/(build-read|build-actions)\.md' 'direct generic GitLab card ownership'

# gitlab/SKILL.md must have discoverability links for the new build cards
require_text "gitlab/SKILL.md" 'reference/build-read\.md' 'build-read discoverability link'
require_text "gitlab/SKILL.md" 'reference/build-actions\.md' 'build-actions discoverability link'

printf 'gitlab-build-cards: PASS\n'
