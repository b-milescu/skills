#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'review-partial-secret-fail-closed: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

review_flow="start-review/REVIEW-FLOW.md"
review_skill="start-review/SKILL.md"
report_template="start-review/templates/review-report.md"
final_handoff="start-review/templates/reviewer-final-handoff.md"
filling_guide="start-review/templates/filling-guide.md"
prompt_docs=(
  "agents/claude/mr-reviewer.md"
  "agents/omp/mr-reviewer.md"
)

require_text "$review_flow" 'partial-review' 'partial-review blocker token'
require_text "$review_flow" 'cannot inspect all behavior-affecting changed surfaces' 'fail-closed partial review rule'
require_text "$review_flow" 'no partial approval|never partially approve' 'no partial approval wording'
for trigger in \
  'diff unavailable' \
  'too large for bounded review' \
  'binary/generated artifact without provenance' \
  'hidden dependencies' \
  'missing linked issue/context.*affecting behavior' \
  'tool limits before decision'; do
  require_text "$review_flow" "$trigger" "partial-review trigger: $trigger"
done
require_text "$review_flow" 'request split|request a split' 'request split guidance'

require_text "$review_flow" 'secret-exposure-suspected' 'secret exposure blocker token'
require_text "$review_flow" 'do not quote.*(secret|credential)|never quote.*(secret|credential)' 'do-not-quote secret guidance'
require_text "$review_flow" 'redact.*(Review Report|report)' 'redacted report guidance'
require_text "$review_flow" 'block.*approval|approval.*block' 'approval blocking for suspected secrets'
require_text "$review_flow" 'remov.*rotat.*purg|rotat.*remov.*purg' 'remove/rotate/purge guidance'
require_text "$review_flow" 'human security escalation|security escalation' 'human security escalation guidance'
require_text "$review_flow" 'per project policy' 'project-policy-scoped secret guidance'

for file in "$report_template" "$final_handoff" "$review_skill" "${prompt_docs[@]}"; do
  require_text "$file" 'partial-review' "$file partial-review blocker token"
  require_text "$file" 'secret-exposure-suspected' "$file secret-exposure-suspected blocker token"
done

for file in "$filling_guide" "${prompt_docs[@]}"; do
  require_text "$file" 'do not quote.*(secret|credential)|never quote.*(secret|credential)' "$file safe no-quote wording"
  require_text "$file" '\[REDACTED\]|redacted' "$file redacted placeholder guidance"
  require_text "$file" 'without (copying|including) (the )?(sensitive )?(payload|secret|credential)|do not copy.*(secret|credential|payload)' "$file no sensitive payload copying"
done

require_text "$final_handoff" 'without secret values|without including secret values|no secret values' 'final handoff blocker without secret values guidance'

printf 'review-partial-secret-fail-closed: PASS\n'
