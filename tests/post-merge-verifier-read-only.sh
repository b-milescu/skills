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

verifier_skill="post-merge-verifier/SKILL.md"
verifier_recipe="start-build/reference/post-merge-verifier.md"

# Both verifier docs forbid the mutating actions (post-#152 wording: the dropped
# "promised docs/ADR/follow-ups" check is intentionally NOT asserted here).
for file in "$verifier_skill" "$verifier_recipe"; do
  require_text "$file" 'approve.*merge.*queue|approve, (merge|reject)' "$file approve/merge/queue forbidden token"
  require_text "$file" 'force.?close' "$file force-close forbidden token"
  require_text "$file" 'delete.*(remote |local )?(source )?branch' "$file delete-branch forbidden token"
  require_text "$file" 'release, deploy|deploy.*operator|operator mutation' "$file release/deploy/operator forbidden token"
done

# The verifier reports pending state rather than mutating.
for file in "$verifier_skill" "$verifier_recipe"; do
  require_text "$file" 'issue_closure_pending' "$file issue_closure_pending report token"
  require_text "$file" 'source_branch_cleanup_pending' "$file source_branch_cleanup_pending report token"
done

# Read-only invariant must be explicit.
require_text "$verifier_skill" 'read-only' 'SKILL.md read-only invariant token'
require_text "$verifier_recipe" 'read-only confirmation' 'recipe read-only confirmation token'

# Post-#152 guard: the dropped "promised docs/ADR/follow-ups" check must stay gone.
if grep -Eiq -- 'promised (docs|adr|follow-?ups?)|docs/adr/follow' "$verifier_skill" "$verifier_recipe"; then
  fail "post-#152 dropped 'promised docs/ADR/follow-ups' check reappeared in verifier docs"
fi

printf 'post-merge-verifier-read-only: PASS\n'
