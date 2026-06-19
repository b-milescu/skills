#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

TEST_NAME="gitlab-mcp-first-workflows"

# shellcheck source=tests/lib/assertions.sh
source "$REPO_ROOT/tests/lib/assertions.sh"
# shellcheck source=tests/lib/agent-prompt-sets.sh
source "$REPO_ROOT/tests/lib/agent-prompt-sets.sh"


workflow_docs=(
  gitlab/SKILL.md
  gitlab-to-issues/SKILL.md
  start-build/SKILL.md
  start-review/SKILL.md
  start-review/REVIEW-FLOW.md
  issue-delivery-loop/SKILL.md
  $(agent_prompt_paths "${builder_prompt_names[@]}")
  $(agent_prompt_paths "${reviewer_prompt_names[@]}")
  docs/agents/dev-workflows.md
  docs/agents/issue-tracker.md
  setup-dev-skills/dev-workflows-gitlab.md
  setup-dev-skills/issue-tracker-gitlab.md
)

for file in "${workflow_docs[@]}"; do
  reject_text "$file" '# Local GitLab via glab' 'old /gitlab title'
  reject_text "$file" 'authoritative[[:space:]]+`glab` CLI' 'glab CLI as authoritative transport'
  reject_text "$file" 'Use the `glab` CLI' 'direct glab CLI primary instruction'
  reject_text "$file" 'Before any GitLab CLI command' 'GitLab CLI primary loading rule'
  reject_text "$file" '(^|[^[:alpha:]])glab CLI([^[:alpha:]]|$)' 'glab CLI role description'
  reject_text "$file" 'GitLab syntax in `/gitlab`' 'syntax-only gitlab pointer'
  reject_text "$file" 'command syntax only' 'publish with command syntax only'
  reject_text "$file" 'Use `/gitlab` for all `glab` command syntax' 'all glab syntax publishing rule'
done

require_text gitlab/SKILL.md 'MCP first' '/gitlab MCP-first transport order'
require_text gitlab/SKILL.md 'Guarded `glab` fallback second' '/gitlab guarded glab fallback order'
require_text gitlab/SKILL.md 'MCP-first transport correctness plus help-first `glab` fallback correctness' 'qualified transport correctness invariant'
require_text gitlab/SKILL.md 'via=mcp.*via=glab-fallback|via=glab-fallback.*via=mcp' 'transport evidence wording'

contract=gitlab/reference/snippet-transports.md
[[ -f "$contract" ]] || fail "missing $contract"
require_text "$contract" 'MCP primary tool' 'MCP primary tool column'
require_text "$contract" 'Fail-closed checks' 'fail-closed checks column'
require_text "$contract" 'Fallback condition' 'fallback condition column'
require_text "$contract" 'Post-mutation MCP re-read' 'post-mutation MCP re-read column'
require_text "$contract" 'via=mcp' 'MCP transport evidence token'
require_text "$contract" 'via=glab-fallback' 'fallback transport evidence token'

# Slim guard-read path for repeated SHA/state guards (agents/skills #286): one
# sanctioned interim path, first per-MR read stays full, repeated guards go slim,
# and the bounded fallback names the documented full-body re-read gap.
require_text gitlab/SKILL.md '## Slim guard-read for repeated SHA/state guards' 'slim guard-read section'
require_text gitlab/SKILL.md 'is unchanged. Read the whole response' 'slim path keeps first per-MR full read unchanged'
require_text gitlab/SKILL.md 'agents/gitlab-mcp/-/issues/87' 'linked gitlab-mcp projection issue reference'
require_text gitlab/SKILL.md 'repeated SHA/state guard re-reads where the MCP read returns full bodies' 'documented repeated-guard fallback gap wording'
# Elided-body fallback for first full reads (agents/skills #287): when the first
# get_merge_request returns an elided description body, the first-read rule is not
# satisfied; safe-mr-json bounded fallback is used to retrieve the actual content.
require_text gitlab/SKILL.md 'elided.*body.*fallback.*first|Elided-body fallback for first' 'elided-body fallback condition for first full reads section'
require_text gitlab/SKILL.md 'elided MCP body on first full description read' 'documented elided-body first-read gap wording'
require_text gitlab/SKILL.md 'safe-mr-json.*bounded fallback.*retrieve.*actual description|safe-mr-json.*retrieve.*actual description|retrieve.*actual description.*safe-mr-json' 'elided-body fallback names safe-mr-json'
require_text gitlab/reference/mutation-guard.md 'slim guard-read path' 'Mutation Guard re-read points at slim path for repeated guards'
require_text gitlab/reference/snippet-transports.md 'slim guard-read path' 'snippet-transports names the slim guard-read path'

require_text gitlab/reference/mutation-guard.md 'GitLab Mutation Guard' 'canonical Mutation Guard document'
require_text gitlab/reference/mutation-guard.schema.json 'mcp_merge_robustness_gap' 'Mutation Guard MCP merge robustness gap token'
require_text gitlab/reference/mutation-guard.schema.json 'mcp_pagination_gap' 'Mutation Guard MCP pagination gap token'
snippet_count="$(grep -cE '^### Snippet:' gitlab/SKILL.md)"
[[ "$snippet_count" -eq 20 ]] || fail "expected 20 stable snippet names, found $snippet_count"
for name in \
  local-repo-preflight issue-pickup draft-mr-create mr-description-update \
  draft-mr-mark-ready mr-pickup artifact-capture ci-decision-snapshot \
  ci-watch-sha-pinned mr-note-create issue-note-create label-reconcile \
  safe-mr-json auto-merge-api-fallback sha-guard sha-bound-approval \
  sha-bound-merge sha-bound-auto-merge-queue approval-confirmation \
  finish-mr-authority-aware; do
  require_exact_line gitlab/SKILL.md "### Snippet: $name" "stable snippet $name"
  require_text "$contract" "\`$name\`" "transport contract for $name"
done

require_text gitlab/reference/ci-finish-guards.md 'fresh MCP re-read|Re-read `get_merge_request`|re-read through MCP' 'fresh MCP re-read before finish/fallback'
require_text gitlab/reference/ci-finish-guards.md 'exact-SHA CI|list_pipelines\(sha=reviewed_sha\)|get_pipeline' 'exact-SHA CI guard'
require_text gitlab/reference/ci-finish-guards.md 'authority.*source|authority/source' 'authority/source guard'
require_text gitlab/reference/ci-finish-guards.md 'caller identity|caller_user_id|token-stability|context-firewall' 'caller identity / context guard'
require_text gitlab/reference/ci-finish-guards.md 'via=mcp|via=glab-fallback' 'finish transport evidence'
require_text gitlab/reference/finish-result-schema.json '"transport"' 'finish_result transport field'
require_text gitlab/reference/finish-result-schema.json 'glab-fallback' 'finish_result fallback transport enum'

require_text gitlab/reference/safe-text.md 'MCP callers that pass a `body` or' 'MCP body content-byte guard'
require_text gitlab/reference/safe-text.md 'validate_gitlab_text' 'MCP body validator command'
require_text gitlab/reference/safe-text.md 'Diagnostics never print the body' 'body redaction invariant'
require_text tests/gitlab-content-guard.sh 'LEAK_MARKER_SECRET' 'sensitive-body regression fixture'
require_text tests/gitlab-content-guard.sh 'assert_not_contains "LEAK_MARKER_SECRET"' 'diagnostics do not print sensitive body'

require_text gitlab/reference/mcp-contract-verification.md 'Merge robustness' 'known MCP merge robustness gap'
require_text gitlab/reference/mcp-contract-verification.md 'List pagination limitations' 'known MCP list pagination gap'
require_text gitlab/reference/mcp-contract-verification.md 'list_\*.*do not show reliable pagination controls|do not show reliable pagination controls.*list_\*' 'list pagination limitation wording'

printf 'gitlab-mcp-first-workflows: PASS\n'
