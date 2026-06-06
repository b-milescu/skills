#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'gitlab-mcp-first-workflows: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

reject_text() {
  local file="$1" pattern="$2" label="$3"
  if grep -Eni -- "$pattern" "$file" >&2; then
    fail "$file contains unconditional primary glab guidance: $label"
  fi
}

workflow_docs=(
  gitlab-local/SKILL.md
  gitlab-to-issues/SKILL.md
  start-build/SKILL.md
  start-build/BUILD-FLOW.md
  start-review/SKILL.md
  start-review/REVIEW-FLOW.md
  issue-delivery-loop/SKILL.md
  agents/claude/mr-builder.md
  agents/pi/mr-builder.md
  agents/claude/mr-reviewer.md
  agents/pi/mr-reviewer.md
  docs/agents/dev-workflows.md
  docs/agents/issue-tracker.md
  setup-dev-skills/dev-workflows-gitlab.md
  setup-dev-skills/issue-tracker-gitlab.md
)

for file in "${workflow_docs[@]}"; do
  reject_text "$file" '# Local GitLab via glab' 'old /gitlab-local title'
  reject_text "$file" 'authoritative[[:space:]]+`glab` CLI' 'glab CLI as authoritative transport'
  reject_text "$file" 'Use the `glab` CLI' 'direct glab CLI primary instruction'
  reject_text "$file" 'Before any GitLab CLI command' 'GitLab CLI primary loading rule'
  reject_text "$file" '(^|[^[:alpha:]])glab CLI([^[:alpha:]]|$)' 'glab CLI role description'
  reject_text "$file" 'GitLab syntax in `/gitlab-local`' 'syntax-only gitlab-local pointer'
  reject_text "$file" 'command syntax only' 'publish with command syntax only'
  reject_text "$file" 'Use `/gitlab-local` for all `glab` command syntax' 'all glab syntax publishing rule'
done

require_text gitlab-local/SKILL.md 'MCP first' '/gitlab-local MCP-first transport order'
require_text gitlab-local/SKILL.md 'Guarded `glab` fallback second' '/gitlab-local guarded glab fallback order'
require_text gitlab-local/SKILL.md 'MCP-first transport correctness plus help-first `glab` fallback correctness' 'qualified transport correctness invariant'
require_text gitlab-local/SKILL.md 'via=mcp.*via=glab-fallback|via=glab-fallback.*via=mcp' 'transport evidence wording'

contract=gitlab-local/reference/snippet-transports.md
[[ -f "$contract" ]] || fail "missing $contract"
require_text "$contract" 'MCP primary tool' 'MCP primary tool column'
require_text "$contract" 'Fail-closed checks' 'fail-closed checks column'
require_text "$contract" 'Fallback condition' 'fallback condition column'
require_text "$contract" 'Post-mutation MCP re-read' 'post-mutation MCP re-read column'
require_text "$contract" 'via=mcp' 'MCP transport evidence token'
require_text "$contract" 'via=glab-fallback' 'fallback transport evidence token'

snippet_count="$(grep -cE '^### Snippet:' gitlab-local/SKILL.md)"
[[ "$snippet_count" -eq 20 ]] || fail "expected 20 stable snippet names, found $snippet_count"
for name in \
  local-repo-preflight issue-pickup draft-mr-create mr-description-update \
  draft-mr-mark-ready mr-pickup artifact-capture ci-decision-snapshot \
  ci-watch-sha-pinned mr-note-create issue-note-create label-reconcile \
  safe-mr-json auto-merge-api-fallback sha-guard sha-bound-approval \
  sha-bound-merge sha-bound-auto-merge-queue approval-confirmation \
  finish-mr-authority-aware; do
  grep -Fxq "### Snippet: $name" gitlab-local/SKILL.md || fail "missing stable snippet $name"
  require_text "$contract" "\`$name\`" "transport contract for $name"
done

require_text gitlab-local/reference/ci-finish-guards.md 'fresh MCP re-read|Re-read `get_merge_request`|re-read through MCP' 'fresh MCP re-read before finish/fallback'
require_text gitlab-local/reference/ci-finish-guards.md 'exact-SHA CI|list_pipelines\(sha=reviewed_sha\)|get_pipeline' 'exact-SHA CI guard'
require_text gitlab-local/reference/ci-finish-guards.md 'authority.*source|authority/source' 'authority/source guard'
require_text gitlab-local/reference/ci-finish-guards.md 'caller identity|caller_user_id|no-self-merge' 'caller identity / no-self-merge guard'
require_text gitlab-local/reference/ci-finish-guards.md 'via=mcp|via=glab-fallback' 'finish transport evidence'
require_text gitlab-local/reference/finish-result-schema.json '"transport"' 'finish_result transport field'
require_text gitlab-local/reference/finish-result-schema.json 'glab-fallback' 'finish_result fallback transport enum'

require_text gitlab-local/reference/safe-text.md 'MCP callers that pass a `body` or' 'MCP body content-byte guard'
require_text gitlab-local/reference/safe-text.md 'must run `gitlab-content-guard\.sh`' 'MCP body guard command'
require_text gitlab-local/reference/safe-text.md 'Diagnostics never print the body' 'body redaction invariant'
require_text tests/gitlab-content-guard.sh 'LEAK_MARKER_SECRET' 'sensitive-body regression fixture'
require_text tests/gitlab-content-guard.sh 'assert_not_contains "LEAK_MARKER_SECRET"' 'diagnostics do not print sensitive body'

require_text gitlab-local/reference/mcp-contract-verification.md 'Merge robustness' 'known MCP merge robustness gap'
require_text gitlab-local/reference/mcp-contract-verification.md 'List pagination limitations' 'known MCP list pagination gap'
require_text gitlab-local/reference/mcp-contract-verification.md 'list_\*.*do not show reliable pagination controls|do not show reliable pagination controls.*list_\*' 'list pagination limitation wording'

printf 'gitlab-mcp-first-workflows: PASS\n'
