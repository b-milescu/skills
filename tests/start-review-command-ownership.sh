#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"
# shellcheck source=tests/lib/agent-prompt-sets.sh
source "$REPO_ROOT/tests/lib/agent-prompt-sets.sh"


TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

fail() {
  printf 'start-review-command-ownership: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

collect_raw_glab_syntax() {
  local file="$1"

  # Reject command-shaped glab examples in reviewer-owned docs. Review cards and
  # gitlab/SKILL.md own flag syntax; start-review should point to snippets
  # and bound-target concepts instead of copying raw command bodies.
  grep -En -- 'glab[[:space:]]+(issue|mr|ci|repo|api|\.\.\.|-[A-Za-z-])\b' "$file" || true
}

assert_no_raw_glab_syntax() {
  local file="$1"
  local hits
  hits="$(collect_raw_glab_syntax "$file")"
  if [[ -n "$hits" ]]; then
    printf '%s\n' "$hits" >&2
    return 1
  fi
}

bad_fixture="$TMPDIR/raw-glab.md"
cat > "$bad_fixture" <<'BAD'
Reviewer should run `glab mr view <id> -F json` before approval.
BAD

if assert_no_raw_glab_syntax "$bad_fixture" 2>/dev/null; then
  fail 'negative fixture with raw glab command syntax was not rejected'
fi

good_fixture="$TMPDIR/snippet-pointer.md"
cat > "$good_fixture" <<'GOOD'
Reviewer should use `gitlab` **Snippet: mr-pickup** with a bound MR IID
plus explicit repo target, or the full bound MR URL when repo inference is unsafe.
GOOD

assert_no_raw_glab_syntax "$good_fixture" || fail 'snippet-pointer fixture should not be rejected'

reviewer_owned_docs=(
  start-review/SKILL.md
  start-review/REVIEW-FLOW.md
  start-review/templates/filling-guide.md
  $(agent_prompt_paths "${reviewer_prompt_names[@]}")
)

for file in "${reviewer_owned_docs[@]}"; do
  assert_no_raw_glab_syntax "$file" || fail "$file copies raw glab command syntax instead of pointing to gitlab cards/snippets"
done

for file in start-review/SKILL.md start-review/REVIEW-FLOW.md; do
  require_text "$file" '../gitlab/reference/review-read.md' 'review-read card link'
  require_text "$file" '../gitlab/reference/review-actions.md' 'review-actions card link'
  require_text "$file" '../gitlab/reference/ci.md' 'CI card link'
  require_text "$file" 'fall back to .*gitlab/SKILL.md|Fallback to full gitlab' 'full gitlab fallback guidance'
done

require_text start-review/REVIEW-FLOW.md 'Snippet: local-repo-preflight' 'preflight snippet ownership'
require_text start-review/REVIEW-FLOW.md 'Snippet: mr-pickup' 'MR metadata snippet ownership'
require_text start-review/REVIEW-FLOW.md 'Snippet: ci-decision-snapshot' 'CI snippet ownership'
require_text start-review/REVIEW-FLOW.md 'Snippet: mr-note-create' 'MR note snippet ownership'
require_text start-review/REVIEW-FLOW.md 'Snippet: sha-guard' 'SHA guard snippet ownership'
require_text start-review/REVIEW-FLOW.md 'Snippet: sha-bound-approval' 'SHA-bound approval snippet ownership'
require_text start-review/REVIEW-FLOW.md 'Snippet: sha-bound-merge' 'SHA-bound merge snippet ownership'
require_text start-review/REVIEW-FLOW.md 'Snippet: sha-bound-auto-merge-queue' 'SHA-bound auto-merge snippet ownership'

printf 'start-review-command-ownership: PASS\n'
