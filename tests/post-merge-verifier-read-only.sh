#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'post-merge-verifier-read-only: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

removed_skill_dir="post-merge-verifier"
removed_skill_file="$removed_skill_dir/SKILL.md"
verifier_recipe="start-build/reference/post-merge-verifier.md"
snapshot_helper="gitlab/scripts/gitlab-post-merge-snapshot.sh"

[[ ! -e "$removed_skill_file" ]] || fail "removed top-level verifier skill still exists: $removed_skill_file"

# The canonical verifier recipe forbids mutating actions (post-#152 wording: the
# dropped "promised docs/ADR/follow-ups" check is intentionally NOT asserted here).
require_text "$verifier_recipe" 'approve.*merge.*queue|approve, (merge|reject)' 'recipe approve/merge/queue forbidden token'
require_text "$verifier_recipe" 'force.?close' 'recipe force-close forbidden token'
require_text "$verifier_recipe" 'delete.*(remote |local )?(source )?branch' 'recipe delete-branch forbidden token'
require_text "$verifier_recipe" 'release, deploy|deploy.*operator|operator mutation' 'recipe release/deploy/operator forbidden token'

# The verifier reports pending state rather than mutating.
require_text "$verifier_recipe" 'issue_closure_pending' 'recipe issue_closure_pending report token'
require_text "$verifier_recipe" 'source_branch_cleanup_pending' 'recipe source_branch_cleanup_pending report token'

# Optional compact routing blocks stay read-only and specific.
require_text "$verifier_recipe" 'delivery\.handoff_contract' 'recipe handoff_contract routing token'
require_text "$verifier_recipe" 'specific/actionable|specific actionable' 'recipe actionable blocker wording token'

# Read-only invariant, canonical recipe ownership, helper wiring, and schema
# anchors must be explicit without requiring a first-class skill file.
require_text "$verifier_recipe" 'Canonical read-only post-merge verification recipe|canonical .*verifier recipe' 'recipe canonical-owner token'
require_text "$verifier_recipe" 'top-level skill discovery should not expose a separate verifier entry point' 'recipe demoted-skill-surface token'
require_text "$verifier_recipe" 'read-only confirmation|read-only GitLab/git' 'recipe read-only invariant token'
require_text "$verifier_recipe" 'get_post_merge_snapshot' 'recipe MCP snapshot tool pointer'
require_text "$verifier_recipe" 'post_merge_snapshot\.kind=post-merge-snapshot' 'recipe snapshot schema anchor'
require_text "$snapshot_helper" 'post-merge-snapshot' 'snapshot helper emits schema kind'
require_text "$snapshot_helper" 'read-only' 'snapshot helper read-only invariant token'

# Post-#152 guard: the dropped "promised docs/ADR/follow-ups" check must stay gone.
if grep -Eiq -- 'promised (docs|adr|follow-?ups?)|docs/adr/follow' "$verifier_recipe"; then
  fail "post-#152 dropped 'promised docs/ADR/follow-ups' check reappeared in verifier docs"
fi

printf 'post-merge-verifier-read-only: PASS\n'
