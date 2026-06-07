#!/usr/bin/env bash
set -euo pipefail

# CI/finish mechanics now specialize the shared GitLab Mutation Guard seam
# instead of restating a second full mutation sequence here.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

SKILL="gitlab-local/SKILL.md"
CARD="gitlab-local/reference/ci-finish-guards.md"
GUARD_DOC="gitlab-local/reference/mutation-guard.md"
GUARD_SCHEMA="gitlab-local/reference/mutation-guard.schema.json"

fail() {
  printf 'gitlab-local-ci-finish-guards: FAIL: %s\n' "$*" >&2
  exit 1
}

require_file() {
  local file="$1"
  [[ -f "$file" ]] || fail "missing file $file"
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

reject_text() {
  local file="$1" pattern="$2" label="$3"
  if grep -Eiq -- "$pattern" "$file"; then
    fail "$file unexpectedly contains $label"
  fi
}

extract_snippet() {
  local file="$1" name="$2"
  awk -v heading="### Snippet: $name" '
    $0 == heading { in_section=1; next }
    in_section && /^### Snippet:/ { exit }
    in_section { print }
  ' "$file"
}

require_snippet() {
  local name="$1" body
  body="$(extract_snippet "$SKILL" "$name")"
  [[ -n "$body" ]] || fail "$SKILL missing snippet $name"
  printf '%s\n' "$body"
}

assert_contains() {
  local text="$1" needle="$2" label="$3"
  [[ "$text" == *"$needle"* ]] || fail "missing $label: $needle"
}

assert_not_contains() {
  local text="$1" needle="$2" label="$3"
  [[ "$text" != *"$needle"* ]] || fail "unexpected $label still inline: $needle"
}

MECH_MR_VIEW='glab mr view|get_merge_request'
MECH_MR_LIST='glab mr list|list_merge_requests'
MECH_PIPELINE_FOR_SHA='glab ci status --branch|list_pipelines|get_pipeline|\.pipeline'
MECH_CI_MR_FORBIDDEN='glab ci status --mr|list_pipelines_for_mr|pipelines_for_merge_request'

require_file "$CARD"
require_file "$GUARD_DOC"
require_file "$GUARD_SCHEMA"

# The card points to the seam and no longer owns a second full sequence.
require_text "$CARD" 'GitLab Mutation Guard' 'Mutation Guard seam pointer'
require_text "$CARD" 'skill://gitlab-local/reference/mutation-guard\.md' 'guard doc skill URI'
require_text "$CARD" 'skill://gitlab-local/reference/mutation-guard\.schema\.json' 'guard schema skill URI'
reject_text "$CARD" '^### Polling and SHA rules$' 'old full polling list section'
reject_text "$CARD" '^### Guard and authority order$' 'old full finish guard order section'

# CI verdict mechanics remain present as read-only exact-SHA evidence.
require_text "$CARD" "$MECH_MR_VIEW" 'per-poll MR head re-read mechanic'
require_text "$CARD" 'every poll' 'per-poll re-read wording'
require_text "$CARD" "$MECH_MR_LIST" 'reference to candidate-only list mechanic'
require_text "$CARD" 'candidate data|not decision-grade' 'no list for decision-grade data wording'
require_text "$CARD" "$MECH_PIPELINE_FOR_SHA" 'pipeline-for-SHA lookup mechanic'
require_text "$CARD" "$MECH_CI_MR_FORBIDDEN" 'reference to forbidden whole-MR CI shortcut'
require_text "$CARD" "(not|never|do not)[^.]*($MECH_CI_MR_FORBIDDEN)" 'do-not-use whole-MR CI shortcut mechanic'
require_text "$CARD" 'stale_ci' 'stale_ci fail-closed token'
require_text "$CARD" 'timeout' 'timeout fail-closed token'
require_text "$CARD" 'expected_sha' 'expected_sha machine field'
require_text "$CARD" 'observed_sha' 'observed_sha machine field'
require_text "$CARD" 'pipeline_id' 'pipeline_id machine field'
require_text "$CARD" 'reviewed_sha' 'reviewed_sha SHA-pin token'
require_text "$CARD" '(differs?|mismatch|!=|not equal)[^.]*(reviewed_sha)|reviewed_sha[^.]*(differs?|mismatch|!=|not equal)' 'per-iteration SHA mismatch wording'

# Finish mechanics are expressed as a Mutation Guard mapping, not a vendored sequence.
require_text "$CARD" 'Mutation Guard field' 'finish mapping table'
require_text "$CARD" 'authority_value.*authority_source|authority_source.*authority_value' 'authority/source guard mapping'
require_text "$CARD" 'caller_role.*caller_identity|caller_identity.*caller_role' 'caller identity / context mapping'
require_text "$CARD" 'mcp_merge_robustness_gap' 'first-class MCP merge robustness gap'
require_text "$CARD" 'mcp_unavailable' 'first-class MCP unavailable gap'
require_text "$CARD" 'via=mcp|via=glab-fallback' 'finish transport evidence token'
require_text "$CARD" 'via=n/a' 'no-action transport evidence token'
require_text "$CARD" 'builder[^.]*(always )?stop|builder[^.]*handoff' 'builder-stops-at-handoff authority floor'
require_text "$CARD" 'at most one action|exactly one.*action|one action' 'exactly-one-finish-action mechanic'
require_text "$CARD" '(fetch|fast-forward)[^.]*only after[^.]*(finish|action)|only after[^.]*(finish|action)[^.]*(fetch|fast-forward)' 'fetch/fast-forward sequenced only-after the finish action'
require_text "$CARD" '(worktree[^.]*(clean `status --porcelain`|safety-check precondition|safety check)|clean `status --porcelain`[^.]*worktree)' 'worktree-removal gated on clean-status / safety-check precondition'
require_text "$CARD" 'closure_pending' 'closure_pending report token'

# Policy is still delegated to canonical owners.
require_text "$CARD" 'REVIEW-FLOW\.md#ci-decision-table' 'CI decision table pointer to REVIEW-FLOW.md'
require_text "$CARD" 'SAFETY\.md' 'authority pointer to start-build/SAFETY.md'
require_text "$CARD" 'authority-matrix\.md' 'authority matrix pointer'

# SKILL snippets keep compact helper path contracts and point at the card/seam.
ci_watch_body="$(require_snippet ci-watch-sha-pinned)"
finish_body="$(require_snippet finish-mr-authority-aware)"

assert_contains "$ci_watch_body" 'Inputs:' 'ci-watch Inputs list'
assert_contains "$ci_watch_body" 'scripts/gitlab-ci-watch.sh' 'ci-watch helper script pointer'
assert_contains "$ci_watch_body" 'scripts/README.md' 'ci-watch helper docs pointer'
assert_contains "$ci_watch_body" 'tests/gitlab-workflow-helpers.sh' 'ci-watch regression test pointer'
assert_contains "$ci_watch_body" '--reviewed-sha "$reviewed_sha"' 'ci-watch helper invocation block'
assert_contains "$ci_watch_body" 'gitlab_ci_watch_script="skill://gitlab-local/scripts/gitlab-ci-watch.sh"' 'ci-watch full skill URI helper path'
assert_contains "$ci_watch_body" 'reference/ci-finish-guards.md' 'ci-watch link to specialization card'
assert_contains "$ci_watch_body" 'mutation-guard.md' 'ci-watch link to Mutation Guard'

assert_contains "$finish_body" 'Inputs:' 'finish Inputs list'
assert_contains "$finish_body" 'scripts/gitlab-finish-mr.sh' 'finish helper script pointer'
assert_contains "$finish_body" 'scripts/README.md' 'finish helper docs pointer'
assert_contains "$finish_body" 'tests/gitlab-workflow-helpers.sh' 'finish regression test pointer'
assert_contains "$finish_body" '--merge-authority "$merge_authority"' 'finish helper invocation block'
assert_contains "$finish_body" 'gitlab_finish_mr_script="skill://gitlab-local/scripts/gitlab-finish-mr.sh"' 'finish full skill URI helper path'
assert_contains "$finish_body" 'reference/ci-finish-guards.md' 'finish link to specialization card'
assert_contains "$finish_body" 'mutation-guard.md' 'finish link to Mutation Guard'

assert_not_contains "$ci_watch_body" 'Polling and SHA rules:' 'old polling list header'
assert_not_contains "$finish_body" 'Guard and authority order:' 'old finish guard order header'

require_text "$SKILL" 'reference/mutation-guard\.md' 'SKILL.md discoverability link to Mutation Guard'

skill_lines="$(wc -l < "$SKILL")"
[[ "$skill_lines" -lt 409 ]] || fail "SKILL.md must stay shorter than 409 lines, found $skill_lines"

printf 'gitlab-local-ci-finish-guards: PASS\n'