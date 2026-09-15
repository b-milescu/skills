#!/usr/bin/env bash
# Focus: GitLab workflow docs/prompts stay MCP-first for GitLab API actions,
# preserve stable `/gitlab` snippet names, allow `glab` only as documented
# fallback/helper/troubleshooting/test coverage, require per-snippet transport
# contracts, preserve safe-text/content-byte rules for MCP bodies, and record
# known MCP merge/list gaps.
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
  gitlab/reference/snippets-read-evidence.md
  gitlab/reference/snippets-publish-body.md
  gitlab/reference/snippets-mutate-finish.md
  start-build/SKILL.md
  start-review/SKILL.md
  start-review/REVIEW-FLOW.md
  issue-delivery-loop/SKILL.md
  $(agent_prompt_paths "${builder_prompt_names[@]}")
  $(agent_prompt_paths "${reviewer_prompt_names[@]}")
  docs/agents/dev-workflows.md
  docs/agents/issue-tracker.md
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
# The `via=` transport-evidence wording moved with the auto-merge-api-fallback
# body into the mutate-and-finish group file (ADR-0002).
require_text gitlab/reference/snippets-mutate-finish.md 'via=mcp.*via=glab-fallback|via=glab-fallback.*via=mcp' 'transport evidence wording'

contract=gitlab/reference/snippet-transports.md
[[ -f "$contract" ]] || fail "missing $contract"
require_text "$contract" 'MCP primary tool' 'MCP primary tool column'
require_text "$contract" 'Fail-closed checks' 'fail-closed checks column'
require_text "$contract" 'Fallback condition' 'fallback condition column'
require_text "$contract" 'via=mcp' 'MCP transport evidence token'
require_text "$contract" 'via=glab-fallback' 'fallback transport evidence token'

# Guard reads are body-free; body recovery uses the dedicated bounded readers
# before any guarded, help-first glab fallback (agents/skills #372).
require_text gitlab/reference/bounded-reads.md 'get_merge_request.*include_description:false' 'body-free MR guard read'
for tool in get_merge_request_description get_issue_description get_merge_request_note get_issue_note; do
  require_text gitlab/reference/bounded-reads.md "$tool" "dedicated body reader $tool"
done
for field in description_grep description_max_bytes description_offset_bytes body_grep body_max_bytes body_offset_bytes; do
  require_text gitlab/reference/bounded-reads.md "$field" "bounded body recovery field $field"
done
require_text gitlab/reference/bounded-reads.md 'retry with a smaller' 'smaller bounded retry before fallback'
require_text gitlab/reference/bounded-reads.md 'body read is a guarded last resort' 'guarded glab body fallback is last resort'
require_text gitlab/reference/mutation-guard.md 'include_description:false' 'Mutation Guard requires body-free MR re-read'
require_text gitlab/reference/snippet-transports.md 'include_description:false' 'transport mirror requires body-free SHA guard read'
# Issue/note state checks stay bounded (agents/skills #442). Snippet bodies now
# live in the phase-grouped files (ADR-0002), so each needle is asserted against
# the file that holds it.
GITLAB_SNIPPET_GROUPS=(
  gitlab/reference/snippets-read-evidence.md
  gitlab/reference/snippets-publish-body.md
  gitlab/reference/snippets-mutate-finish.md
)
require_text gitlab/reference/snippets-read-evidence.md 'get_issue\(include_description:false\)' 'issue-pickup state-check is body-free'
require_text gitlab/reference/snippets-publish-body.md 'get_issue\(include_description:false\)' 'label-reconcile state-check is body-free'
require_text gitlab/reference/snippet-transports.md 'get_issue\(include_description:false\)' 'transport issue state-check is body-free'
require_text gitlab/reference/snippets-read-evidence.md 'description_grep' 'focused Closes/Lift description_grep'
require_text gitlab/reference/snippets-publish-body.md 'description_max_bytes' 'bounded description readback after publication'
require_text gitlab/reference/snippet-transports.md 'description_grep' 'transport focused Closes/Lift description_grep'
require_text gitlab/reference/snippets-read-evidence.md 'body_grep' 'Gate Receipt/Review Report note body_grep'
require_text gitlab/reference/snippet-transports.md 'body_grep' 'transport Gate Receipt/Review Report note body_grep'
for file in gitlab/SKILL.md "${GITLAB_SNIPPET_GROUPS[@]}"; do
  reject_text "$file" 'first read stays full|First read per MR stays full|Slim guard-read for repeated SHA/state guards' 'obsolete first-full/slim guard discipline'
  reject_text "$file" 'note body where MCP exposes no bounded param' 'obsolete unbounded-note MCP claim'
done
reject_text gitlab/reference/mutation-guard.md 'first per-MR full read|slim guard-read path' 'obsolete Mutation Guard full-read discipline'

require_text gitlab/reference/mutation-guard.md 'GitLab Mutation Guard' 'canonical Mutation Guard document'
require_text gitlab/reference/mutation-guard.schema.json 'mcp_merge_robustness_gap' 'Mutation Guard MCP merge robustness gap token'
require_text gitlab/reference/mutation-guard.schema.json 'mcp_pagination_gap' 'Mutation Guard MCP pagination gap token'
snippet_count=0
for file in "${GITLAB_SNIPPET_GROUPS[@]}"; do
  [[ -f "$file" ]] || fail "missing snippet group file $file"
  snippet_count=$((snippet_count + $(grep -cE '^## Snippet:' "$file" || true)))
done
[[ "$snippet_count" -eq 21 ]] || fail "expected 21 stable snippet names across the group files, found $snippet_count"
reject_text gitlab/SKILL.md '^### Snippet:' 'snippet body back in the entry procedure'
for name in \
  local-repo-preflight issue-pickup draft-mr-create mr-description-update \
  draft-mr-mark-ready mr-pickup artifact-capture ci-decision-snapshot \
  ci-watch-sha-pinned mr-note-create issue-note-create label-reconcile \
  safe-mr-json auto-merge-api-fallback sha-guard sha-bound-approval \
  sha-bound-merge sha-bound-auto-merge-queue approval-confirmation \
  finish-mr-authority-aware mr-handoff-evidence; do
  grep -Fxq -- "## Snippet: $name" "${GITLAB_SNIPPET_GROUPS[@]}" \
    || fail "no snippet group file holds stable snippet $name"
  require_text gitlab/SKILL.md "\`$name\`" "snippet index row for $name"
  require_text "$contract" "\`$name\`" "transport contract for $name"
done

require_text gitlab/reference/ci-finish-guards.md 'list_pipelines\(sha=reviewed_sha\).*get_pipeline' 'SHA-attributed advisory CI observation'
require_text gitlab/reference/ci-finish-guards.md 'exactly one mutation and provider-native readback' 'one-mutation/readback guard'
require_text gitlab/reference/ci-finish-guards.md 'authority/caller evidence, and transport' 'finish transport evidence'
require_text gitlab/reference/finish-result-schema.json '"transport"' 'finish_result transport field'
require_text gitlab/reference/finish-result-schema.json 'glab-fallback' 'finish_result fallback transport enum'

require_text gitlab/reference/safe-text.md 'MCP callers that pass a `body` or' 'MCP body content-byte guard'
require_text gitlab/reference/safe-text.md 'validate_gitlab_text' 'MCP body validator command'
require_text gitlab/reference/safe-text.md 'Diagnostics never print the body' 'body redaction invariant'
require_text gitlab/reference/safe-text.md 'does not close #410' 'negated close example documented'
require_text gitlab/reference/safe-text.md 'group/project#410' 'safe non-closing full-path issue reference documented'
require_text gitlab/reference/safe-text.md 'Keep the real auto-close trailer deliberate and unique' 'single intended auto-close trailer guidance'
require_text gitlab/reference/safe-text.md 'must \*\*not\*\* close' 'MR description non-closing issue guidance'
require_text gitlab/reference/safe-text.md 'never print body' 'diagnostics do not print body'
require_text gitlab/reference/safe-text.md 'malformed secret-bearing payload is not echoed back' 'sensitive-body redaction invariant'

require_text gitlab/reference/snippet-transports.md 'MCP merge robustness gap' 'known MCP merge robustness gap'

printf 'gitlab-mcp-first-workflows: PASS\n'
