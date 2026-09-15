#!/usr/bin/env bash
# Focus: Deleted GitLab build cards stay gone; `/forge` GitLab branch points at
# `gitlab/SKILL.md` while generic `/start-build` owns no direct GitLab card
# links.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'gitlab-build-cards: FAIL: %s\n' "$*" >&2
  exit 1
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

for card in gitlab/reference/build-read.md gitlab/reference/build-actions.md; do
  [[ ! -e "$card" ]] || fail "$card must be deleted"
done

require_text "forge/reference/gitlab.md" 'gitlab/SKILL\.md' 'full-reference fallback guidance'
require_text "gitlab/SKILL.md" 'skill://gitlab/reference/snippet-transports\.md' 'snippet-transports discoverability'
reject_text "start-build/SKILL.md" 'gitlab/reference/(build-read|build-actions)\.md' 'direct generic GitLab card ownership'
reject_text "gitlab/SKILL.md" 'reference/build-read\.md|reference/build-actions\.md' 'deleted build-card discoverability link'
reject_text "forge/reference/gitlab.md" 'gitlab/reference/(build-read|build-actions)\.md' 'deleted build-card link'

printf 'gitlab-build-cards: PASS\n'
