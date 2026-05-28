#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

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

# Reviewer Lift must carry value plus provenance; generated-copy parity is
# separately enforced by tests/reviewer-lift-schema.sh.
require_row \
  "start-build/templates/reviewer-lift-schema.md" \
  "Merge authority source" \
  "canonical Merge authority source"
require_text \
  "start-build/templates/reviewer-lift-schema.md" \
  'parent task|human MR comment|rulebook path|project default source' \
  'accepted authority source examples'
require_text \
  "start-build/templates/reviewer-lift-schema.md" \
  'builder[^.]*quote|quoted[^.]*claim|not[^.]*grant' \
  'builder authority is quoted claim, not grant semantics'

for copy in \
  start-build/templates/review-packet.md \
  start-build/templates/review-packet-compact.md \
  start-review/templates/review-report.md; do
  require_row "$copy" "Merge authority source" "generated-copy Merge authority source"
done

# Reviewers need source verification and deterministic precedence before any
# approval/merge/auto-merge action.
reviewer_guidance=(
  start-review/REVIEW-FLOW.md
  start-review/SKILL.md
  start-review/templates/filling-guide.md
  agents/claude/mr-reviewer.md
  agents/pi/mr-reviewer.md
)

for file in "${reviewer_guidance[@]}"; do
  require_text "$file" 'Merge authority source' 'Merge authority source guidance'
  require_text "$file" 'verifiable source|source[^.]*verif' 'verifiable source requirement'
  require_text "$file" 'human[^.]*parent[^.]*rulebook|parent[^.]*human[^.]*rulebook' 'human/parent over rulebook precedence'
  require_text "$file" 'conflict[^.]*most restrictive|most restrictive[^.]*no action' 'conflict chooses most restrictive/no action'
  require_text "$file" 'builder[^.]*claim[^.]*not[^.]*grant|builder[^.]*quote[^.]*not[^.]*grant|not[^.]*grant[^.]*builder' 'builder claim not grant'
  require_text "$file" 'reviewer may merge[^.]*queue auto-merge[^.]*project default|queue auto-merge[^.]*reviewer may merge[^.]*project default' 'high-authority modes covered'
  require_text "$file" 'without[^.]*verifiable source[^.]*blocked|blocked[^.]*without[^.]*verifiable source' 'missing source blocks high-authority modes'
done

# Builders must record provenance, not mint authority.
builder_guidance=(
  start-build/BUILD-FLOW.md
  start-build/SKILL.md
  start-build/templates/filling-guide.md
  agents/claude/mr-builder.md
  agents/pi/mr-builder.md
)

for file in "${builder_guidance[@]}"; do
  require_text "$file" 'Merge authority source' 'builder records Merge authority source'
  require_text "$file" 'quote[^.]*authority|quoted[^.]*claim|builder[^.]*claim' 'builder quotes authority instead of granting it'
  require_text "$file" 'not[^.]*grant|cannot[^.]*grant' 'builder cannot grant authority'
done

# Machine handoffs preserve both fields for parent orchestration.
require_text "start-build/templates/builder-final-handoff.md" '^  merge_authority:' 'builder handoff merge_authority field'
require_text "start-build/templates/builder-final-handoff.md" '^  merge_authority_source:' 'builder handoff merge_authority_source field'
require_text "start-review/templates/reviewer-final-handoff.md" '^  merge_authority:' 'reviewer handoff merge_authority field'
require_text "start-review/templates/reviewer-final-handoff.md" '^  merge_authority_source:' 'reviewer handoff merge_authority_source field'

printf 'review-authority-provenance: PASS\n'
