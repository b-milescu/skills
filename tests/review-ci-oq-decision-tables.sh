#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'review-ci-oq-decision-tables: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

canonical="start-review/REVIEW-FLOW.md"
anchor='CI and Open Question decision tables'

require_text "$canonical" '^## CI and Open Question decision tables$' 'canonical CI/OQ decision table section'

for ci_state in \
  'exact-SHA success' \
  'exact-SHA pending under protected auto-merge' \
  'red/failed/canceled/skipped' \
  'missing' \
  'stale' \
  'human-waived'; do
  require_text "$canonical" "\\|[[:space:]]*${ci_state}[[:space:]]*\\|" "CI decision table row: ${ci_state}"
done

require_text "$canonical" 'local gate[[:space:]]+PASS' 'pending CI local gate PASS condition'
require_text "$canonical" 'pending pipeline[^|.]*reviewed SHA|reviewed SHA[^|.]*pending pipeline' 'pending CI reviewed-SHA condition'
require_text "$canonical" 'protected merge checks[^|.]*green CI|green CI[^|.]*protected merge checks' 'pending CI protected merge checks condition'
require_text "$canonical" 'queue auto-merge[^|.]*authority|authority[^|.]*queue auto-merge' 'pending CI queue auto-merge authority condition'
require_text "$canonical" 'authorized human waiver[^|.]*source/comment|source/comment[^|.]*authorized human waiver' 'human-waived CI source/comment requirement'
require_text "$canonical" 'reviewer[^|.]*cannot self-waive|cannot self-waive[^|.]*reviewer' 'reviewer cannot self-waive CI'
require_text "$canonical" 'Builder readiness and Gate coverage do not authorize approval, merge, or auto-merge' 'builder readiness not approval/merge authority'
require_text "$canonical" 'CI approval/finish eligibility remains exclusively governed by the \[CI decision table\]' 'canonical CI table remains approval/finish owner'
require_text "$canonical" 'Gate coverage.*full-local.*/.*hybrid.*/.*ci-only.*never.*parent-owned|parent-owned.*invalid coverage' 'reviewer Gate coverage enum validation'

for oq_state in \
  'answered from evidence' \
  'builder evidence gap' \
  'human/product/security decision' \
  'non-blocking'; do
  require_text "$canonical" "\\|[[:space:]]*${oq_state}[[:space:]]*\\|" "OQ decision table row: ${oq_state}"
done

require_text "$canonical" 'answered from evidence[^|]*\|[^|]*(ok|pass allowed)' 'answered OQ ok outcome'
require_text "$canonical" 'builder evidence gap[^|]*\|[^|]*request-changes' 'builder evidence gap request-changes outcome'
require_text "$canonical" 'human/product/security decision[^|]*\|[^|]*(blocked/no approval|blocked[^|]*no approval)' 'human decision blocked/no approval outcome'
require_text "$canonical" 'non-blocking[^|]*\|[^|]*C-N[^|]*follow-up[^|]*rationale' 'non-blocking OQ C-N follow-up rationale outcome'

pointer_docs=(
  "start-review/SKILL.md"
  "start-review/REVIEW-FLOW.md"
  "start-review/templates/filling-guide.md"
  "agents/claude/mr-reviewer.md"
  "agents/omp/mr-reviewer.md"
)

for file in "${pointer_docs[@]}"; do
  require_text "$file" "$anchor" 'pointer to canonical CI/OQ decision tables'
done

# Keep detailed decision criteria centralized in REVIEW-FLOW. Other reviewer-facing
# docs may name blocker tokens, but should not restate full CI/OQ matrices.
for file in start-review/SKILL.md start-review/templates/filling-guide.md agents/claude/mr-reviewer.md agents/omp/mr-reviewer.md; do
  if grep -Eiq -- 'green/waived/pending under protected auto-merge|answer, escalate, or downgrade|CI green/waived or safely pending|stale or missing decision-grade CI maps' "$file"; then
    grep -Ein -- 'green/waived/pending under protected auto-merge|answer, escalate, or downgrade|CI green/waived or safely pending|stale or missing decision-grade CI maps' "$file" >&2 || true
    fail "$file restates CI/OQ decision criteria instead of pointing to $canonical"
  fi
done

printf 'review-ci-oq-decision-tables: PASS\n'
