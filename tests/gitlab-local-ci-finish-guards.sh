#!/usr/bin/env bash
set -euo pipefail

# Parallel-execution contract (issue #197):
#   Phase 3 OWNS this file: tests/gitlab-local-ci-finish-guards.sh.
#   Phase 2 OWNS tests/gitlab-local-split-snippets.sh.
# The two test files are intentionally disjoint so Phase 2 and Phase 3 can run in
# parallel without serializing on a shared test. If a future change must touch
# both, merge test rows by ID without resequencing the existing assertions.
#
# Transport independence (issue #197):
#   This test asserts the CONCEPTUAL CI-watch + finish-guard invariants and their
#   MCP wording, NOT exact `glab` command strings. When Phase 3 swaps the card's
#   relocated mechanics from `glab` CLI calls to gitlab-mcp tool calls, the
#   per-poll re-read and pipeline-lookup mechanics below are matched in EITHER
#   transport (legacy `glab mr view` / `glab ci status --branch` OR MCP
#   `get_merge_request` / `list_pipelines(sha=)`), so this test stays green
#   across the migration. The load-bearing invariants it preserves are:
#     - per-poll re-read of MR head (no stale list data for decision-grade),
#     - SHA-pin EVERY poll iteration against reviewed_sha,
#     - the forbidden whole-MR CI status shortcut stays a do-not-use mechanic,
#     - authority-gate-BEFORE-mutation (no approve/merge/queue before the gate),
#     - exactly-one-finish-action,
#     - fetch-ONLY-AFTER the finish action,
#     - worktree-removal precondition,
#     - closure_pending instead of force-closing,
#     - demoted verdict/authority policy points to the canonical owners,
#     - the relocated 7 polling/SHA rules + 8 guard/authority steps survive,
#     - SKILL.md stays under its post-relocation line budget.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

SKILL="gitlab-local/SKILL.md"
CARD="gitlab-local/reference/ci-finish-guards.md"

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

# Transport-independent mechanic regexes. Each matches the current `glab` wording
# and the planned gitlab-mcp tool-call wording the refactor adopts.
#   - MR head re-read: `glab mr view` OR `get_merge_request`.
#   - pipeline lookup for a SHA: `glab ci status --branch` / MR `.pipeline`
#     OR `list_pipelines(sha=...)` / `get_pipeline`.
#   - the forbidden whole-MR CI shortcut: `glab ci status --mr` OR an MCP
#     pipelines-for-MR-without-SHA form.
MECH_MR_VIEW='glab mr view|get_merge_request'
MECH_MR_LIST='glab mr list|list_merge_requests'
MECH_PIPELINE_FOR_SHA='glab ci status --branch|list_pipelines|get_pipeline|\.pipeline'
MECH_CI_MR_FORBIDDEN='glab ci status --mr|list_pipelines_for_mr|pipelines_for_merge_request'

# ---------------------------------------------------------------------------
# (a) The relocation card exists and carries the relocated mechanics.
# ---------------------------------------------------------------------------
require_file "$CARD"

# CI verdict mechanics (from ci-watch-sha-pinned) — transport-independent.
require_text "$CARD" "$MECH_MR_VIEW" 'per-poll MR head re-read mechanic'
require_text "$CARD" 'every poll' 'per-poll re-read wording'
require_text "$CARD" "$MECH_MR_LIST" 'reference to the not-for-decision-grade list mechanic'
require_text "$CARD" 'do not rely on|never|not for decision-grade|decision-grade data' 'no list for decision-grade data wording'
require_text "$CARD" "$MECH_PIPELINE_FOR_SHA" 'pipeline-for-SHA lookup mechanic'
require_text "$CARD" "$MECH_CI_MR_FORBIDDEN" 'reference to the forbidden whole-MR CI shortcut'
require_text "$CARD" 'stale_ci' 'stale_ci fail-closed token'
require_text "$CARD" 'timeout' 'timeout fail-closed token'
require_text "$CARD" 'expected_sha' 'expected_sha machine field'
require_text "$CARD" 'observed_sha' 'observed_sha machine field'
require_text "$CARD" 'pipeline_id' 'pipeline_id machine field'
require_text "$CARD" 'reviewed_sha' 'reviewed_sha SHA-pin token'

# SHA-pin EVERY poll iteration: the card must require a fail/abort when the
# observed MR head differs from reviewed_sha during polling (the per-iteration
# pin, not just the one-time finish-gate equality check). Anchor to a
# fail-on-mismatch statement so dropping the polling-time pin fails closed even
# though reviewed_sha also appears in the finish section.
require_text "$CARD" '(fail|abort|stop|reject)[^;]*(differs?|mismatch|!=|not equal)[^;]*reviewed_sha|(differs?|mismatch|!=|not equal)[^;]*reviewed_sha[^.]*(stale|new review|fail)' 'per-iteration fail-on-SHA-mismatch against reviewed_sha'

# The forbidden whole-MR CI shortcut must appear only as a do-not-use mechanic.
require_text "$CARD" "(not|never|do not)[^.]*($MECH_CI_MR_FORBIDDEN)" 'do-not-use whole-MR CI shortcut mechanic'

# Finish guard/authority mechanics (from finish-mr-authority-aware).
require_text "$CARD" '\.sha.*reviewed_sha|reviewed_sha.*\.sha|sha[ =]"?\$?reviewed_sha|SHA-bound' 'SHA-bound finish guard mechanic'
require_text "$CARD" 'exactly one (finish )?action|one finish action' 'exactly-one-finish-action mechanic'
require_text "$CARD" 'closure_pending' 'closure_pending report token'

# fetch-only-after-action: the default-branch fetch/fast-forward must be SEQUENCED
# strictly AFTER the finish action. Anchor to the co-occurrence of the
# fetch/fast-forward mechanic with the "only after" ordering and the finish
# action, so reordering, negating ("before"/"prior to"), or dropping the
# after-action sequencing fails closed — not just deleting the word "fetch".
# Transport-independent: matches git/sequencing wording, no exact `glab` string.
require_text "$CARD" '(fetch|fast-forward)[^.]*only after[^.]*(merge|queue|auto-merge|finish|action)|only after[^.]*(merge|queue|auto-merge|finish|action)[^.]*(fetch|fast-forward)' 'fetch/fast-forward sequenced only-after the finish action'

# worktree-precondition: worktree removal must be GATED on a precondition (clean
# `status --porcelain` and/or the default-branch safety check passing) BEFORE the
# worktree is removed. Anchor to the co-occurrence of "worktree" with a
# remove/removal verb and a conditional ("only when"/"before"/"verify"/"clean"/
# "status --porcelain"/"safety check"), so making removal unconditional or
# dropping the precondition fails closed — not just deleting the word "worktree".
require_text "$CARD" '(remove|removal|removing|delete)[^.]*worktree[^.]*(only when|only after|before|verify|clean|status --porcelain|safety check|has passed)|worktree[^.]*(remove|removal|removing|delete)[^.]*(only when|only after|before|verify|clean|status --porcelain|safety check|has passed)|worktree only when[^.]*(status --porcelain|clean|safety check|empty)' 'worktree-removal gated on a clean-status / safety-check precondition'

# Authority-gate-BEFORE-mutation: the card must require the current SHA / CI / and
# caller-role+merge-authority gate to be satisfied BEFORE approve/merge/auto-merge.
require_text "$CARD" 'before (approval|approve|merge|auto-merge)|require current.*before' 'authority/SHA gate-before-mutation ordering'
# The caller-role + merge-authority matrix must be APPLIED as the gate (anchor to
# the matrix-application phrase so deleting the gate fails closed, not just any
# incidental "caller" mention).
require_text "$CARD" 'caller-role and merge-authority matrix|apply the caller-role|caller-role.*merge-authority matrix' 'caller-role + merge-authority gate application'
# A builder caller must always stop at handoff and never finish (anchor to the
# builder-stops-with-handoff co-occurrence, not generic never-approve prose).
require_text "$CARD" 'builder[^.]*(always )?stops[^.]*handoff|builder[^.]*handoff[^.]*never (approve|merge)' 'builder-stops-at-handoff authority floor'

# (c) Demoted policy became accurate pointers to the canonical owners.
require_text "$CARD" 'REVIEW-FLOW\.md#ci-decision-table' 'CI decision table pointer to REVIEW-FLOW.md'
require_text "$CARD" 'SAFETY\.md' 'authority pointer to start-build/SAFETY.md'

# The card must NOT re-vendor the canonical authority matrix as owned policy.
reject_text "$CARD" '`queue auto-merge`: authorized caller may queue auto-merge' 'restated auto-merge authority policy'

# ---------------------------------------------------------------------------
# (b) Each SKILL.md snippet keeps heading + Inputs + helper block + scripts
#     pointers, and links to the relocation card.
# ---------------------------------------------------------------------------
ci_watch_body="$(require_snippet ci-watch-sha-pinned)"
finish_body="$(require_snippet finish-mr-authority-aware)"

# ci-watch-sha-pinned structure preserved inline (helper-path contracts survive).
assert_contains "$ci_watch_body" 'Inputs:' 'ci-watch Inputs list'
assert_contains "$ci_watch_body" 'scripts/gitlab-ci-watch.sh' 'ci-watch helper script pointer'
assert_contains "$ci_watch_body" 'scripts/README.md' 'ci-watch helper docs pointer'
assert_contains "$ci_watch_body" 'tests/gitlab-workflow-helpers.sh' 'ci-watch regression test pointer'
assert_contains "$ci_watch_body" '--reviewed-sha "$reviewed_sha"' 'ci-watch helper invocation block'
assert_contains "$ci_watch_body" 'gitlab_ci_watch_script="skill://gitlab-local/scripts/gitlab-ci-watch.sh"' 'ci-watch full skill URI helper path'
assert_contains "$ci_watch_body" '"$gitlab_ci_watch_script"' 'ci-watch helper variable invocation'
assert_not_contains "$ci_watch_body" 'skill_dir/scripts/gitlab-ci-watch.sh' 'ci-watch bare skill_dir script path pattern'
assert_not_contains "$ci_watch_body" 'gitlab_local_skill_dir/scripts/gitlab-ci-watch.sh' 'ci-watch bare gitlab_local_skill_dir script path pattern'
assert_contains "$ci_watch_body" 'reference/ci-finish-guards.md' 'ci-watch link to relocation card'

# finish-mr-authority-aware structure preserved inline.
assert_contains "$finish_body" 'Inputs:' 'finish Inputs list'
assert_contains "$finish_body" 'scripts/gitlab-finish-mr.sh' 'finish helper script pointer'
assert_contains "$finish_body" 'scripts/README.md' 'finish helper docs pointer'
assert_contains "$finish_body" 'tests/gitlab-workflow-helpers.sh' 'finish regression test pointer'
assert_contains "$finish_body" '--merge-authority "$merge_authority"' 'finish helper invocation block'
assert_contains "$finish_body" 'gitlab_finish_mr_script="skill://gitlab-local/scripts/gitlab-finish-mr.sh"' 'finish full skill URI helper path'
assert_contains "$finish_body" '"$gitlab_finish_mr_script"' 'finish helper variable invocation'
assert_not_contains "$finish_body" 'skill_dir/scripts/gitlab-finish-mr.sh' 'finish bare skill_dir script path pattern'
assert_not_contains "$finish_body" 'gitlab_local_skill_dir/scripts/gitlab-finish-mr.sh' 'finish bare gitlab_local_skill_dir script path pattern'
assert_contains "$finish_body" 'reference/ci-finish-guards.md' 'finish link to relocation card'

# The verbose relocated narrative must no longer live inline in the snippets.
assert_not_contains "$ci_watch_body" 'Polling and SHA rules:' '7-rule polling list header'
assert_not_contains "$finish_body" 'Guard and authority order:' '8-step authority order header'

# The relocated lists themselves must now live in the card (relocated, not lost).
require_text "$CARD" 'Polling and SHA rules' 'relocated polling/SHA rules section'
require_text "$CARD" 'Guard and authority order' 'relocated guard/authority order section'

# Count the relocated structure: 7 polling rules + 8 authority steps survive.
polling_rules="$(awk '
  /Polling and SHA rules/ { in_sec=1; next }
  in_sec && (/^#/ || /Guard and authority order/) { in_sec=0 }
  in_sec && /^[[:space:]]*[0-9]+\./ { n++ }
  END { print n+0 }
' "$CARD")"
[[ "$polling_rules" -ge 7 ]] || fail "expected >=7 relocated polling/SHA rules, found $polling_rules"

authority_steps="$(awk '
  /Guard and authority order/ { in_sec=1; next }
  in_sec && /^#/ { in_sec=0 }
  in_sec && /^[[:space:]]*[0-9]+\./ { n++ }
  END { print n+0 }
' "$CARD")"
[[ "$authority_steps" -ge 8 ]] || fail "expected >=8 relocated guard/authority steps, found $authority_steps"

# ---------------------------------------------------------------------------
# SKILL.md must surface the relocation card for discoverability.
# ---------------------------------------------------------------------------
require_text "$SKILL" 'reference/ci-finish-guards\.md' 'SKILL.md discoverability link to relocation card'

# Line-count budget: the relocation must keep SKILL.md materially smaller.
skill_lines="$(wc -l < "$SKILL")"
[[ "$skill_lines" -lt 409 ]] || fail "SKILL.md must be shorter than 409 lines after relocation, found $skill_lines"

printf 'gitlab-local-ci-finish-guards: PASS\n'
