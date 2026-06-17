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
  'omitted not-applicable job \(conditional required-job set\)' \
  'red/failed/canceled/skipped' \
  'missing' \
  'stale' \
  'human-waived'; do
  require_text "$canonical" "\\|[[:space:]]*${ci_state}[[:space:]]*\\|" "CI decision table row: ${ci_state}"
done

# Conditional required-job set (docs-only / rules:-omitted not-applicable jobs).
# The reviewer must honor a target-repo-declared conditional required-job set
# without relaxing the gate. These assertions guard the fail-closed boundary.
require_text "$canonical" 'omitted not-applicable job[^|]*\|[^|]*(approv|merge)' \
  'omitted not-applicable job row allows approval/finish'
require_text "$canonical" 'required-job set is read from the target repo|read from the target repo[^|]*check-gate doc|check-gate doc[^|]*project_profile' \
  'conditional required-job set read from target repo doc / project_profile, not hard-coded'
require_text "$canonical" "rules:[^|]*omitted|omitted[^|]*rules:" \
  'rules:-omitted (absent, not skipped/failed) job description'
require_text "$canonical" 'success[^|]*at the reviewed SHA|reviewed SHA[^|]*success|exact-SHA success' \
  'omitted not-applicable row still requires success at the reviewed SHA'
require_text "$canonical" 'absent for any reason[^|]*other[^|]*than a declared not-applicable rule still blocks' \
  'fail-closed: job absent for any other reason still blocks'
require_text "$canonical" '(failed|canceled|pending)[^|]*applicable required job[^|]*block|applicable required job[^|]*(failed|canceled|pending)[^|]*block' \
  'fail-closed: failed/canceled/pending applicable required job still blocks'

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
)

for file in "${pointer_docs[@]}"; do
  require_text "$file" "$anchor" 'pointer to canonical CI/OQ decision tables'
done

# Keep detailed decision criteria centralized in REVIEW-FLOW. Other reviewer-facing
# docs may name blocker tokens, but should not restate full CI/OQ matrices.
for file in start-review/SKILL.md start-review/templates/filling-guide.md; do
  if grep -Eiq -- 'green/waived/pending under protected auto-merge|answer, escalate, or downgrade|CI green/waived or safely pending|stale or missing decision-grade CI maps' "$file"; then
    grep -Ein -- 'green/waived/pending under protected auto-merge|answer, escalate, or downgrade|CI green/waived or safely pending|stale or missing decision-grade CI maps' "$file" >&2 || true
    fail "$file restates CI/OQ decision criteria instead of pointing to $canonical"
  fi
done

printf 'review-ci-oq-decision-tables: PASS\n'
