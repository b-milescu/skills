#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"
# shellcheck source=tests/lib/agent-prompt-sets.sh
source "$REPO_ROOT/tests/lib/agent-prompt-sets.sh"


fail() {
  printf 'review-authority-provenance: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

require_row() {
  local file="$1" row="$2" label="$3"
  grep -Eq "^\|[[:space:]]*$row[[:space:]]*\|" "$file" || fail "$file missing $label row"
}

# Reviewer Lift must carry approval policy, merge authority, and provenance;
# generated-copy parity is separately enforced by tests/reviewer-lift-schema.sh.
require_row \
  "start-build/templates/reviewer-lift-schema.md" \
  "Approval authority" \
  "canonical Approval authority"
require_row \
  "start-build/templates/reviewer-lift-schema.md" \
  "Approval authority source" \
  "canonical Approval authority source"
require_row \
  "start-build/templates/reviewer-lift-schema.md" \
  "Merge authority source" \
  "canonical Merge authority source"
require_text \
  "start-build/templates/reviewer-lift-schema.md" \
  'default-after-pass|approval policy' \
  'default approval policy semantics'
require_text \
  "start-build/templates/reviewer-lift-schema.md" \
  'REVIEW-FLOW\.md#approval-authority-policy|stable repo policy' \
  'stable approval policy source example'
require_text \
  "start-build/templates/reviewer-lift-schema.md" \
  'parent task|human MR comment|rulebook path|project default source' \
  'accepted merge authority source examples'
require_text \
  "start-build/templates/reviewer-lift-schema.md" \
  'builder[^.]*quote|quoted[^.]*claim|not[^.]*grant' \
  'builder authority is quoted claim, not grant semantics'

for copy in \
  start-build/templates/review-packet.md \
  start-build/templates/review-packet-compact.md \
  start-review/templates/review-report.md; do
  require_row "$copy" "Approval authority" "generated-copy Approval authority"
  require_row "$copy" "Approval authority source" "generated-copy Approval authority source"
  require_row "$copy" "Merge authority source" "generated-copy Merge authority source"
done

# Reviewers need source verification and deterministic precedence before approval
# and before any merge/auto-merge finish action.
reviewer_guidance=(
  start-review/REVIEW-FLOW.md
  start-review/SKILL.md
  start-review/templates/filling-guide.md
  $(agent_prompt_paths mr-reviewer)
)
routed_final_reviewer_guidance=( $(agent_prompt_paths "${routed_final_reviewer_prompt_names[@]}") )

for file in "${reviewer_guidance[@]}"; do
  require_text "$file" 'Approval authority|approval authority' 'Approval authority guidance'
  require_text "$file" 'Merge authority source' 'Merge authority source guidance'
  require_text "$file" 'verifiable source|source[^.]*verif|verified stable policy source' 'verifiable source requirement'
  require_text "$file" 'human[^.]*parent[^.]*rulebook|parent[^.]*human[^.]*rulebook|Human or parent instruction beats rulebook' 'human/parent over rulebook precedence'
  require_text "$file" 'conflict[^.]*most restrictive|most restrictive[^.]*no.action' 'conflict chooses most restrictive/no action'
  require_text "$file" 'builder[^.]*claim[^.]*not[^.]*grant|builder[^.]*quote[^.]*not[^.]*grant|not[^.]*grant[^.]*builder' 'builder claim not grant'
  require_text "$file" 'reviewer may merge[^.]*queue auto-merge[^.]*project default|queue auto-merge[^.]*reviewer may merge[^.]*project default' 'high-authority modes covered'
  require_text "$file" 'without[^.]*verifiable[^.]*source[^.]*blocked|without it[^.]*blocked|blocked[^.]*without[^.]*verifiable[^.]*source|missing merge authority[^.]*blocks finish' 'missing source blocks high-authority finish modes'
done

# Routed final reviewers are thin route pins; they must still preserve the
# authority-verification seam and treat builder/parent handoff fields as claims.
for file in "${routed_final_reviewer_guidance[@]}"; do
  require_text "$file" 'Canonical development pattern source: `start-review`' 'routed reviewer start-review pointer'
  require_text "$file" 'authority verification' 'routed reviewer authority verification'
  require_text "$file" 'start-review` plus `gitlab` authority verification explicitly permit' 'routed reviewer authority source seam'
  require_text "$file" 'Reviewer Lift[^.]*claims to verify' 'routed reviewer handoff claim verification'
done

# Builders must record provenance, not mint authority.
builder_guidance=(
  start-build/BUILD-FLOW.md
  start-build/SKILL.md
  start-build/templates/filling-guide.md
  $(agent_prompt_paths mr-builder)
)
routed_builder_guidance=( $(agent_prompt_paths "${routed_builder_prompt_names[@]}") )

for file in "${builder_guidance[@]}"; do
  require_text "$file" 'Approval authority|approval authority' 'builder records Approval authority'
  require_text "$file" 'Merge authority source' 'builder records Merge authority source'
  require_text "$file" 'quote[^.]*authority|quoted[^.]*claim|builder[^.]*claim' 'builder quotes authority instead of granting it'
  require_text "$file" 'not[^.]*grant|cannot[^.]*grant' 'builder cannot grant authority'
done

for file in "${routed_builder_guidance[@]}"; do
  require_text "$file" 'Canonical development pattern source: `start-build`' 'routed builder start-build pointer'
  require_text "$file" 'authority' 'routed builder authority evidence'
  require_text "$file" 'approve[^.]*merge[^.]*queue auto-merge|queue auto-merge[^.]*approve[^.]*merge' 'routed builder cannot self-approve/self-merge'
  require_text "$file" 'explicit parent/human delegation' 'routed builder parent/human authority override source'
done
# Machine handoffs preserve approval and merge authority/source for parent orchestration.
require_text "start-build/templates/builder-final-handoff.md" '^  approval_authority:' 'builder handoff approval_authority field'
require_text "start-build/templates/builder-final-handoff.md" '^  approval_authority_source:' 'builder handoff approval_authority_source field'
require_text "start-build/templates/builder-final-handoff.md" '^  merge_authority:' 'builder handoff merge_authority field'
require_text "start-build/templates/builder-final-handoff.md" '^  merge_authority_source:' 'builder handoff merge_authority_source field'
require_text "start-review/templates/reviewer-final-handoff.md" '^  approval_authority:' 'reviewer handoff approval_authority field'
require_text "start-review/templates/reviewer-final-handoff.md" '^  approval_authority_source:' 'reviewer handoff approval_authority_source field'
require_text "start-review/templates/reviewer-final-handoff.md" '^  merge_authority:' 'reviewer handoff merge_authority field'
require_text "start-review/templates/reviewer-final-handoff.md" '^  merge_authority_source:' 'reviewer handoff merge_authority_source field'

printf 'review-authority-provenance: PASS\n'
