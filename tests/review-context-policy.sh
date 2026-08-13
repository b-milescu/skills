#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'review-context-policy: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

require_row() {
  local file="$1" row="$2"
  grep -Eq -- "^\|[[:space:]]*${row}[[:space:]]*\|" "$file" || fail "$file missing capsule row: $row"
}

reject_text() {
  local file="$1" pattern="$2" label="$3"
  ! grep -Eiq -- "$pattern" "$file" || fail "$file contains $label"
}

flow="start-review/REVIEW-FLOW.md"
report="start-review/templates/review-report.md"
filling="start-review/templates/filling-guide.md"
schema="start-build/templates/delivery-schema.md"
parent="start-build/reference/parent-orchestrator.md"
standalone="start-build/reference/standalone-gate.md"

require_text "$schema" '^## Trust and evidence tiers$' 'trust tiers'
require_text "$schema" 'Tier 1[^|]*\|[[:space:]]*Provider-native decision-grade' 'Tier 1 definition'
require_text "$schema" 'Tier 2[^|]*\|[[:space:]]*Repository policy/source/tests' 'Tier 2 definition'
require_text "$schema" 'Tier 3[^|]*\|[[:space:]]*Unverified routing index' 'Tier 3 definition'
require_text "$schema" '`routing index` is the canonical term for unverified handoff data' 'routing-index rule'
require_text "$schema" 'rebind it to[[:space:]]*Tier 1 or Tier 2 evidence before action' 'routing-index rebind rule'
require_text "$schema" 'Artifacts count as evidence only through their verified source and readback' 'artifact provenance rule'

require_text "$flow" '^## Context Firewall$' 'Context Firewall'
require_text "$flow" 'gate-eligible reviewer is fresh' 'fresh independent reviewer rule'
require_text "$flow" 'Parent/builder reasoning' 'inherited reasoning'
require_text "$flow" 'claims or maps, not evidence' 'inherited-reasoning boundary'
require_text "$flow" '`rerun-review` from a fresh context' 'fresh rerun rule'
require_text "$flow" '^## Review Context Capsule$' 'Review Context Capsule'
require_text "$flow" 'claim[^.]*reviewer verification[^.]*source' 'claim verification source rule'

for file in "$flow" "$report"; do
  for row in 'Repository' 'Change request' 'Authority' 'CI' 'Scope' 'Artifacts' 'Context expansion'; do
    require_row "$file" "$row"
  done
  reject_text "$file" '^\|[[:space:]]*(Repo|MR)[[:space:]]*\|' 'stale capsule alias'
done

require_text "$flow" 'Tier 1 — required reads' 'Tier 1 context'
require_text "$flow" 'bounded provider-native decision-grade evidence' 'bounded Tier 1 context'
require_text "$flow" 'Tier 2 — risk-triggered reads' 'Tier 2 context'
require_text "$flow" 'bounded repository policy' 'bounded Tier 2 context'
require_text "$flow" 'Tier 3 — forbidden-by-default broad context' 'forbidden Tier 3 context'
require_text "$flow" 'whole-repository reading' 'broad-context example'
for file in "$flow" "$report" "$filling"; do
  require_text "$file" 'Reviewer Lift[^.]*map[^.]*not proof|maps, not proof' 'Reviewer Lift map-not-proof rule'
  require_text "$file" 'safety-critical' 'safety-critical field rule'
  require_text "$file" 'verification' 'independent verification rule'
  require_text "$file" 'source' 'verification source rule'
done

reviewer_prompt="$(awk '/^```text$/ { in_block=1; block=""; next } in_block && /^```$/ { if (block ~ /Mode: mr-reviewer/) print block; in_block=0; next } in_block { block=block $0 "\n" }' "$parent")"
builder_prompt="$(awk '/^```text$/ { in_block=1; block=""; next } in_block && /^```$/ { if (block ~ /Mode: child mr-builder/) print block; in_block=0; next } in_block { block=block $0 "\n" }' "$parent")"

[ -n "$reviewer_prompt" ] || fail 'reviewer launch prompt not found'
[ -n "$builder_prompt" ] || fail 'child-builder launch prompt not found'
printf '%s' "$reviewer_prompt" | grep -Eiq 'Skills: invoke start-review and forge via the Skill tool' || fail 'reviewer prompt missing Skill invocation'
printf '%s' "$builder_prompt" | grep -Eiq 'Skills: invoke start-build and forge via the Skill tool' || fail 'builder prompt missing Skill invocation'
for field in 'Change request locator' 'Reviewer Lift pointer' 'Project rulebook path' 'Stop condition' 'Finish owner'; do
  printf '%s' "$reviewer_prompt" | grep -Eiq "$field" || fail "reviewer prompt missing $field"
done
for prompt in "$reviewer_prompt" "$builder_prompt"; do
  ! printf '%s' "$prompt" | grep -Eiq 'invoke (start-review|start-build) and gitlab|Reading? (an? )?(internal )?reference|MR URL' || fail 'launch prompt owns transport or raw policy reads'
done
require_text "$standalone" 'Change request locator[^.]*Reviewer Lift pointer[^.]*project rulebook path' 'standalone neutral minimal prompt'
require_text "$standalone" 'Invoke `start-review` and `forge` through the Skill tool' 'standalone Skill invocation'

printf 'review-context-policy: PASS\n'
