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

[[ ! -e "$removed_skill_file" ]] || fail "removed top-level verifier skill still exists: $removed_skill_file"

# The canonical verifier is read-only and provider-neutral.
require_text "$verifier_recipe" 'approve.*merge.*queue|approve, (merge|reject)' 'recipe approve/merge/queue forbidden token'
require_text "$verifier_recipe" 'close work items' 'recipe work-item close forbidden token'
require_text "$verifier_recipe" 'delete.*source refs' 'recipe delete-ref forbidden token'
require_text "$verifier_recipe" 'release, deploy|product/runtime/operator mutation' 'recipe release/deploy/operator forbidden token'
require_text "$verifier_recipe" 'pending' 'recipe pending-state token'
require_text "$verifier_recipe" 'delivery\.handoff_contract' 'recipe handoff_contract routing token'
require_text "$verifier_recipe" 'specific/actionable|specific actionable' 'recipe actionable blocker wording token'
require_text "$verifier_recipe" 'Canonical read-only post-merge verification recipe|canonical .*verifier recipe' 'recipe canonical-owner token'
require_text "$verifier_recipe" 'top-level skill discovery' 'recipe demoted-skill-surface token'
require_text "$verifier_recipe" 'read-only confirmation|read-only.*post-merge' 'recipe read-only invariant token'
require_text "$verifier_recipe" 'forge post_merge_snapshot' 'recipe forge snapshot pointer'
require_text "$verifier_recipe" 'post_merge_snapshot\.kind=post-merge-snapshot' 'recipe snapshot schema anchor'
require_text "$verifier_recipe" 'advisory result-commit CI observation attributed to the provider result commit' 'result-commit CI attribution'
require_text "$verifier_recipe" 'wrong-result-commit CI is recorded' 'wrong-result CI advisory handling'

for forbidden in '/gitlab' 'get_post_merge_snapshot' 'Closes #' 'MR IID' 'issue-note'; do
  if grep -Fqi -- "$forbidden" "$verifier_recipe"; then
    fail "provider-specific verifier mechanic remains: $forbidden"
  fi
done

# Post-#152 guard: the dropped "promised docs/ADR/follow-ups" check must stay gone.
if grep -Eiq -- 'promised (docs|adr|follow-?ups?)|docs/adr/follow' "$verifier_recipe"; then
  fail "post-#152 dropped 'promised docs/ADR/follow-ups' check reappeared in verifier docs"
fi

printf 'post-merge-verifier-read-only: PASS\n'
