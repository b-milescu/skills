#!/usr/bin/env bash
set -euo pipefail

# Guards the #147 relocation: the load-bearing CI polling/SHA mechanics and the
# finish guard/authority mechanics moved out of gitlab-local/SKILL.md into the
# reference card gitlab-local/reference/ci-finish-guards.md, while each SKILL.md
# snippet keeps its heading + Inputs + helper-invocation block + scripts pointers
# and links to the card. Verdict-classification and authority-matrix policy must
# become accurate pointers to the canonical owners (REVIEW-FLOW.md / SAFETY.md),
# not restated prose.

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
  grep -Eq -- "$pattern" "$file" || fail "$file missing $label"
}

reject_text() {
  local file="$1" pattern="$2" label="$3"
  if grep -Eq -- "$pattern" "$file"; then
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

# ---------------------------------------------------------------------------
# (a) The new card exists and carries the relocated mechanics tokens.
# ---------------------------------------------------------------------------
require_file "$CARD"

# CI verdict mechanics (from ci-watch-sha-pinned) — verbatim glab mechanics.
require_text "$CARD" 'glab mr view' 'per-poll MR view re-read mechanic'
require_text "$CARD" 'every poll' 'per-poll re-read wording'
require_text "$CARD" 'glab mr list' 'reference to glab mr list (as not-for-decision-grade)'
require_text "$CARD" 'do not rely on|never|not for decision-grade|decision-grade data' 'no glab mr list for decision-grade data wording'
require_text "$CARD" 'glab ci status --branch' 'branch CI fallback mechanic'
require_text "$CARD" 'glab ci status --mr' 'reference to the forbidden ci status --mr'
require_text "$CARD" 'stale_ci' 'stale_ci fail-closed token'
require_text "$CARD" 'timeout' 'timeout fail-closed token'
require_text "$CARD" 'expected_sha' 'expected_sha machine field'
require_text "$CARD" 'observed_sha' 'observed_sha machine field'
require_text "$CARD" 'pipeline_id' 'pipeline_id machine field'
require_text "$CARD" 'reviewed_sha' 'reviewed_sha SHA-pin token'

# The forbidden ci status --mr must appear only as a do-not-use mechanic.
require_text "$CARD" '(not|never|Do not)[^.]*glab ci status --mr' 'do-not-use ci status --mr mechanic'

# Finish guard/authority mechanics (from finish-mr-authority-aware).
require_text "$CARD" '\.sha.*reviewed_sha|reviewed_sha.*\.sha|SHA-bound' 'SHA-bound finish guard mechanic'
require_text "$CARD" 'exactly one (finish )?action|one finish action' 'exactly-one-finish-action mechanic'
require_text "$CARD" 'closure_pending' 'closure_pending report token'
require_text "$CARD" '[Ff]etch|fast-forward' 'fetch/fast-forward default branch mechanic'
require_text "$CARD" 'only after' 'fetch only after the action sequencing'
require_text "$CARD" 'worktree' 'worktree-removal precondition mechanic'

# (c) Demoted policy became accurate pointers to the canonical owners (not dangling).
require_text "$CARD" 'REVIEW-FLOW\.md#ci-decision-table' 'CI decision table pointer to REVIEW-FLOW.md'
require_text "$CARD" 'SAFETY\.md' 'authority pointer to start-build/SAFETY.md'

# The card must NOT restate the canonical verdict classification / authority matrix
# as owned policy. The numbered authority matrix bullets must not be re-vendored.
reject_text "$CARD" '`queue auto-merge`: authorized caller may queue auto-merge' 'restated auto-merge authority policy'

# ---------------------------------------------------------------------------
# (b) Each SKILL.md snippet keeps heading + Inputs + helper block + scripts
#     pointers, and links to the new card.
# ---------------------------------------------------------------------------
ci_watch_body="$(require_snippet ci-watch-sha-pinned)"
finish_body="$(require_snippet finish-mr-authority-aware)"

# ci-watch-sha-pinned structure preserved inline.
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
# The 7-rule "Polling and SHA rules:" header and the 8-step "Guard and authority
# order:" header were the relocation targets.
assert_not_contains "$ci_watch_body" 'Polling and SHA rules:' '7-rule polling list header'
assert_not_contains "$finish_body" 'Guard and authority order:' '8-step authority order header'

# The relocated lists themselves must now be in the card (relocated, not lost).
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
# SKILL.md must surface the new card for discoverability.
# ---------------------------------------------------------------------------
require_text "$SKILL" 'reference/ci-finish-guards\.md' 'SKILL.md discoverability link to new card'

# Line-count budget: the relocation must materially shrink SKILL.md below 409.
skill_lines="$(wc -l < "$SKILL")"
[[ "$skill_lines" -lt 409 ]] || fail "SKILL.md must be shorter than 409 lines after relocation, found $skill_lines"

printf 'gitlab-local-ci-finish-guards: PASS\n'
