#!/usr/bin/env bash
# Focus: Deleted GitLab review/CI cards stay gone; `/forge` GitLab branch
# points at `gitlab/SKILL.md` while generic `/start-review` owns no direct
# GitLab card links.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'gitlab-review-cards: FAIL: %s\n' "$*" >&2
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

for card in gitlab/reference/review-read.md gitlab/reference/review-actions.md gitlab/reference/ci.md; do
  [[ ! -e "$card" ]] || fail "$card must be deleted"
done

require_text "forge/reference/gitlab.md" 'gitlab/SKILL\.md' 'full-reference fallback guidance'
require_text "gitlab/SKILL.md" 'skill://gitlab/reference/snippet-transports\.md' 'snippet-transports discoverability'
for file in start-review/SKILL.md start-review/REVIEW-FLOW.md; do
  reject_text "$file" 'gitlab/reference/(review-read|review-actions|ci)\.md' 'direct generic GitLab card ownership'
done
reject_text "gitlab/SKILL.md" 'reference/review-read\.md|reference/review-actions\.md|reference/ci\.md' 'deleted review-card discoverability link'
reject_text "forge/reference/gitlab.md" 'gitlab/reference/(review-read|review-actions|ci)\.md' 'deleted review-card link'

printf 'gitlab-review-cards: PASS\n'
