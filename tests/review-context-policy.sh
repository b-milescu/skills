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
  local file="$1" row="$2" label="$3"
  grep -Eiq -- "^\|[[:space:]]*${row}[[:space:]]*\|" "$file" || fail "$file missing $label row"
}

flow="start-review/REVIEW-FLOW.md"
report="start-review/templates/review-report.md"
filling="start-review/templates/filling-guide.md"
# Issue #316 deleted start-build/BUILD-FLOW.md; the parent reviewer-launch
# minimal-prompt invariants are owned canonically by reference/parent-orchestrator.md.
parent_flow="start-build/reference/parent-orchestrator.md"
delivery_schema="start-build/templates/gitlab-delivery-schema.md"

# Canonical term: `routing index` names unverified handoff data, defined in the
# trust-tiers section of the delivery schema. Glosses elsewhere point here; this
# pin guards the single canonical-definition site against drift or removal.
require_text "$delivery_schema" '^## Trust and evidence tiers$' 'delivery-schema trust-tiers section'
require_text "$delivery_schema" '`routing index`[^.]*canonical term[^.]*unverified handoff data' 'routing index canonical-term declaration'
require_row "$delivery_schema" '`tier-3`[^|]*\|[[:space:]]*Unverified routing index' 'delivery-schema Tier 3 unverified routing index'

# Context Firewall: review independence is session/context-bound, not GitLab identity-bound.
require_text "$flow" '^## Context Firewall$' 'Context Firewall section'
require_text "$flow" 'built[^.]*planned[^.]*revised[^.]*cannot[^.]*gate-eligible review|cannot[^.]*gate-eligible review[^.]*built[^.]*planned[^.]*revised' 'builder/planner/reviser gate-eligible review ban'
require_text "$flow" 'same-session[^.]*advisory[^.]*only|advisory only[^.]*same-session' 'same-session review advisory-only rule'
require_text "$flow" 'parent[^.]*builder[^.]*reasoning[^.]*not[^.]*evidence|not[^.]*treat[^.]*parent[^.]*builder[^.]*reasoning[^.]*evidence' 'parent/builder reasoning not evidence rule'

# Review Context Capsule: fields must distinguish claim, verification, and source.
require_text "$flow" '^## Review Context Capsule$' 'Review Context Capsule section'
require_text "$flow" 'claim[^|\n]*verification[^|\n]*source|claim[^.]*verification[^.]*source' 'claim / verification / source semantics'
for row in 'Repo' 'MR' 'Authority' 'CI' 'Scope' 'Artifacts' 'Context expansion'; do
  require_row "$flow" "$row" "Review Context Capsule ${row}"
done

require_text "$report" '^## Review Context Capsule$' 'Review Report capsule section'
require_text "$report" '\|[[:space:]]*Capsule field[[:space:]]*\|[[:space:]]*Claim[[:space:]]*\|[[:space:]]*Reviewer verification[[:space:]]*\|[[:space:]]*Source[[:space:]]*\|' 'Review Report capsule claim/verification/source table'
for row in 'Repo' 'MR' 'Authority' 'CI' 'Scope' 'Artifacts' 'Context expansion'; do
  require_row "$report" "$row" "Review Report capsule ${row}"
done

# Context tiers govern narrow default reads and risk-triggered expansion.
for tier in \
  'Tier 0[^\n]*prompt invariants' \
  'Tier 1[^\n]*required reads' \
  'Tier 2[^\n]*risk-triggered reads' \
  'Tier 3[^\n]*forbidden-by-default broad context'; do
  require_text "$flow" "$tier" "context tier ${tier}"
done
require_text "$flow" 'Tier 3[^.]*whole repo|whole repo[^.]*Tier 3|Tier 3[^.]*parent conversation|parent conversation[^.]*Tier 3' 'Tier 3 broad-context examples'

# Reviewer Lift is a map, not truth; safety-critical fields require independent verification/source.
for file in "$flow" "$filling" "$report"; do
  require_text "$file" 'Reviewer Lift[^.]*map[^.]*not[^.]*truth|map[^.]*not[^.]*truth[^.]*Reviewer Lift' 'Reviewer Lift map-not-truth policy'
  require_text "$file" 'safety-critical[^.]*verification[^.]*source|safety-critical[^.]*source[^.]*verification' 'safety-critical verification/source policy'
done

# Parent reviewer launch prompt stays minimal and rejects inherited reasoning as evidence.
require_text "$parent_flow" 'minimal[^.]*reviewer launch prompt|reviewer launch prompt[^.]*minimal' 'minimal reviewer launch prompt guidance'
for label in 'MR URL' 'Reviewer Lift pointer' 'Project rulebook path'; do
  require_text "$parent_flow" "$label" "parent launch prompt ${label}"
done
require_text "$parent_flow" 'not[^.]*treat[^.]*parent[^.]*builder[^.]*reasoning[^.]*evidence|parent[^.]*builder[^.]*reasoning[^.]*not[^.]*evidence' 'parent launch prompt evidence-firewall instruction'

# Launch-prompt skill-load invariant (#320, guarded by #322): each
# parent-orchestrator launch-prompt fenced block must carry a Skill-tool-invocation
# `Skills:` line so the spawned subagent enters through the SKILL.md entry
# procedure rather than raw-Reading a mid-policy reference file. The reviewer block
# follows its `Mode: mr-reviewer` line; the child-builder block follows
# `Mode: child mr-builder`. Pin to the stable `Skills:` + `via the Skill tool`
# tokens, not the surrounding prose, so ordinary edits do not trip the guard.
launch_prompt_skill_line() {
  # Print the `Skills:` line that immediately follows the given `Mode:` marker
  # line inside the launch-prompt fenced blocks of parent_flow.
  local mode_marker="$1"
  awk -v marker="$mode_marker" '
    $0 == marker { want=1; next }
    want && /^Skills:/ { print; want=0 }
    want && /^```/ { want=0 }
  ' "$parent_flow"
}

reviewer_skills_line="$(launch_prompt_skill_line 'Mode: mr-reviewer')"
child_skills_line="$(launch_prompt_skill_line 'Mode: child mr-builder')"
for pair in "reviewer:${reviewer_skills_line}" "child-builder:${child_skills_line}"; do
  which_block="${pair%%:*}"
  skills_line="${pair#*:}"
  [ -n "$skills_line" ] || fail "$parent_flow ${which_block} launch-prompt block missing a Skills: line after its Mode: marker"
  printf '%s\n' "$skills_line" | grep -Eiq -- 'via the Skill tool' \
    || fail "$parent_flow ${which_block} launch-prompt Skills: line lacks the 'via the Skill tool' Skill-invocation token"
done

# reject_text scoped to the launch-prompt templates only: forbid the
# `Load <skill> (<file>.md)` parenthetical raw-Read-biasing form. Scoping to the
# launch-prompt host files keeps legitimate `Load`-a-file phrasing elsewhere
# (e.g. start-build/SKILL.md "Load host project's rulebook index") unaffected.
for launch_file in "$parent_flow" 'start-build/reference/standalone-gate.md'; do
  if grep -Ein -- 'Load [^()]*\([^)]*\.md\)' "$launch_file"; then
    fail "$launch_file reintroduces the 'Load <skill> (<file>.md)' raw-Read-biasing launch-prompt form"
  fi
done

# Reviewer-facing prompts must surface the policy without inlining command bodies.
for file in start-review/SKILL.md; do
  require_text "$file" 'Context Firewall' "$file Context Firewall pointer"
  require_text "$file" 'Review Context Capsule' "$file Review Context Capsule pointer"
  require_text "$file" 'Tier 0[^\n]*Tier 1[^\n]*Tier 2[^\n]*Tier 3|Tier 0' "$file context-tier pointer"
  require_text "$file" 'Reviewer Lift[^.]*map[^.]*not[^.]*truth|map[^.]*not[^.]*truth[^.]*Reviewer Lift' "$file Reviewer Lift map-not-truth pointer"
done

printf 'review-context-policy: PASS\n'
