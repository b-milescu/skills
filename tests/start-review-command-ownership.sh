#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"
# shellcheck source=tests/lib/agent-prompt-sets.sh
source "$REPO_ROOT/tests/lib/agent-prompt-sets.sh"

fail() { printf 'start-review-command-ownership: FAIL: %s\n' "$*" >&2; exit 1; }
require() { grep -Eiq -- "$2" "$1" || fail "$1 missing $3"; }
reject() { ! grep -Eiq -- "$2" "$1" || fail "$1 contains $3"; }

owned=(
  start-review/SKILL.md
  start-review/REVIEW-FLOW.md
  start-review/templates/filling-guide.md
  $(agent_prompt_paths "${reviewer_prompt_names[@]}")
)

for file in "${owned[@]}"; do
  reject "$file" '(^|[[:space:]`])glab[[:space:]]+(issue|mr|ci|repo|api)|Snippet:|gitlab/reference/(review-read|review-actions|ci)[.]md|refs/merge-requests|PRIVATE-TOKEN' 'raw/provider-specific review mechanics'
done

for file in start-review/SKILL.md start-review/REVIEW-FLOW.md; do
  require "$file" 'forge preflight' 'forge preflight'
  require "$file" 'forge snapshot' 'forge snapshot'
  require "$file" 'provider' 'selected-provider ownership'
  require "$file" 'fail(s|ed)? closed|blocks?|Stop on ambiguity' 'fail-closed behavior'
  require "$file" 'provider-native (post-)?readback|provider-native post-read' 'provider-native readback'
  require "$file" 'reviewed commit|reviewed-commit' 'reviewed-commit binding'
done

require start-review/SKILL.md 'ordered common' 'common guard ownership'
require start-review/SKILL.md 'forge post_merge_snapshot' 'read-only post-merge snapshot'
require start-review/SKILL.md 'separate read-only actor' 'read-only verifier boundary'
require start-review/REVIEW-FLOW.md 'provider-proven[[:space:]]*integration candidate' 'provider-proven CI binding'
require start-review/REVIEW-FLOW.md 'selected `/forge`' 'selected-provider fallback'
require start-review/REVIEW-FLOW.md 'provider reference' 'provider fallback owner'

printf 'start-review-command-ownership: PASS\n'
