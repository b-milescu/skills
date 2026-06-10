#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'review-reject-non-mutating: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

reject_docs=(
  "start-review/REVIEW-FLOW.md"
  "start-review/SKILL.md"
  "agents/claude/mr-reviewer.md"
  "agents/omp/mr-reviewer.md"
)

require_text \
  "start-review/REVIEW-FLOW.md" \
  'Reject.*(Review Report|report).*(stop|escalat)|Reject.*(stop|escalat).*(Review Report|report)' \
  'reject path that posts a Review Report and stops/escalates'

for file in "${reject_docs[@]}"; do
  require_text \
    "$file" \
    'reject.*(stop|escalat)|reject.*(Review Report|report)' \
    'reject path guidance'
done

# Any MR-close wording in the reviewer path must be tied to explicit authority.
while IFS=: read -r file line text; do
  lower="$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')"
  if [[ "$lower" != *explicit* || "$lower" != *authority* ]]; then
    fail "$file:$line has MR close wording without explicit authority: $text"
  fi
  if [[ "$lower" != *human* && "$lower" != *project* ]]; then
    fail "$file:$line has MR close authority wording without human/project scope: $text"
  fi
done < <(
  grep -RIinE \
    'close (an |the )?mr|close-mr|mr close|closing (an |the )?mr' \
    start-review agents/claude/mr-reviewer.md agents/omp/mr-reviewer.md || true
)

printf 'review-reject-non-mutating: PASS\n'
