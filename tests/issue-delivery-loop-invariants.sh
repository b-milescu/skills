#!/usr/bin/env bash
set -euo pipefail

# Invariant guard for issue-delivery-loop/SKILL.md, Dev Workflow docs, and the
# parent launch seam. Pins the POST-#151 pointer shape while also guarding the
# #226 skill-only model-tier routing contract, the #227 runtime-aware reviewer
# split, and the #300 routed-only cutover: classify before child launch, use the
# exact runtime-specific builder/reviewer routes at parent-orchestrator dispatch
# (OMP pins openai-codex/* GPT routes, Claude Code pins anthropic/* Opus/Sonnet
# routes), route the final reviewer by runtime (mr-reviewer-opus48-xhigh on Claude
# Code, mr-reviewer-gpt55-xhigh on OMP), with no generic fallback builder/reviewer
# and no review scout.
# Assertions are tokens, not whole sentences.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SKILL_FILE="$REPO_ROOT/issue-delivery-loop/SKILL.md"
PARENT_FILE="$REPO_ROOT/start-build/reference/parent-orchestrator.md"
DEV_WORKFLOW_FILE="$REPO_ROOT/docs/agents/dev-workflows.md"
SETUP_DEV_WORKFLOW_FILE="$REPO_ROOT/setup-dev-skills/dev-workflows-gitlab.md"

fail() {
  printf 'issue-delivery-loop-invariants: FAIL: %s\n' "$*" >&2
  exit 1
}

require_file_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$file" || fail "missing expected token in ${file#$REPO_ROOT/}: $needle"
}

refute_file_contains() {
  local file="$1"
  local needle="$2"
  if grep -Fq -- "$needle" "$file"; then
    fail "forbidden token present in ${file#$REPO_ROOT/}: $needle"
  fi
}

require_contains() {
  require_file_contains "$SKILL_FILE" "$1"
}

require_parent_contains() {
  require_file_contains "$PARENT_FILE" "$1"
}

[[ -f "$SKILL_FILE" ]] || fail "missing required file: issue-delivery-loop/SKILL.md"
[[ -f "$PARENT_FILE" ]] || fail "missing required file: start-build/reference/parent-orchestrator.md"
[[ -f "$DEV_WORKFLOW_FILE" ]] || fail "missing required file: docs/agents/dev-workflows.md"
[[ -f "$SETUP_DEV_WORKFLOW_FILE" ]] || fail "missing required file: setup-dev-skills/dev-workflows-gitlab.md"



# Batch envelope survives: serial-by-default WIP=1.
require_contains 'Default WIP: 1'
require_contains 'serial by default'

# Post-#151 pointer: the parent loop, decoupling-before-parallel proof, spot-check,
# and revision rounds defer to the canonical recipe instead of being paraphrased.
require_contains 'Run the parent loop per'
require_contains 'parent-orchestrator.md'
require_contains 'decoupling proof before parallel work'

# The three-round limit is delegated to standalone-gate, not restated as a local
# number (keeps the policy single-sourced after #151).
require_contains 'three-round limit'
require_contains 'defers to'
require_contains 'standalone-gate.md'

# Authority boundaries from the canonical flows stay preserved; command bodies are
# not restated here.
require_contains 'Preserve builder/reviewer authority boundaries'
require_contains 'do not restate command bodies'

# Delegation to child builder / fresh reviewer survives the pointer rewrite.
require_contains 'Delegate implementation to child'
require_contains 'Delegate independent review'

# Parent-launch minimality and routing-index guidance stay present.
require_contains 'exact role/mode'
require_contains 'expected handoff schema'
require_contains 'minimum evidence pointers'
require_contains 'delivery.handoff_contract'

# #226/#227 model-tier routing: the loop classifies each target and the parent
# seam launches exact routed agents. The final review gate is runtime-specific
# (Opus 4.8 xhigh on Claude Code, GPT-5.5 xhigh on OMP); the GPT builder/reviewer
# routes are OMP-only and Claude Code has no openai-codex/* route, so there is no
# generic fallback builder/reviewer and no review scout.
#
# #249 single-table-owner split: the per-tier builder route NAMES live in exactly
# one canonical table (parent-orchestrator.md). The three pointer files
# (issue-delivery-loop SKILL.md + the two Dev Workflow docs) keep `skill://`
# pointers and the independent-review FLOOR sentences, but must not restate the
# builder route names on their doc surface.
POINTER_FILES=("$SKILL_FILE" "$DEV_WORKFLOW_FILE" "$SETUP_DEV_WORKFLOW_FILE")
BUILDER_ROUTE_NAMES=(
  'mr-builder-sonnet-low'
  'mr-builder-opus48-high'
  'mr-builder-opus48'
  'mr-builder-gpt54-low'
  'mr-builder-gpt55-high'
  'mr-builder-gpt55'
)

# Positive: the canonical table owner names every builder route. The runtime
# reviewer routes are floor sentences and stay reachable in all four files.
for needle in \
  'mr-builder-sonnet-low' \
  'mr-builder-opus48' \
  'mr-builder-opus48-high' \
  'mr-builder-gpt54-low' \
  'mr-builder-gpt55' \
  'mr-builder-gpt55-high'; do
  require_parent_contains "$needle"
done
for needle in \
  'mr-reviewer-gpt55-xhigh' \
  'mr-reviewer-opus48-xhigh'; do
  require_contains "$needle"
  require_parent_contains "$needle"
done

# Negative: no builder route name appears on the three pointer files' doc surface.
for pointer_file in "${POINTER_FILES[@]}"; do
  for route_name in "${BUILDER_ROUTE_NAMES[@]}"; do
    refute_file_contains "$pointer_file" "$route_name"
  done
done

# Tier criteria stay owned by issue-delivery-loop (inline criteria bullets) and
# reachable from the parent's required reads. The two Dev Workflow docs point back
# to the criteria owner instead of silently duplicating the route table.
require_contains '`moderate` is the default when work is neither `trivial` nor `high-risk`'
require_file_contains "$DEV_WORKFLOW_FILE" 'tier criteria live in'
require_file_contains "$SETUP_DEV_WORKFLOW_FILE" 'tier criteria live in'
require_parent_contains 'classifies with the same criteria'

for needle in \
  'docs/prose/templates/labels/inventory/checklist' \
  'no runtime behavior' \
  'no security/auth/permissions/billing' \
  'no schema/migration/persistence' \
  'no deploy/runtime/CI semantic change' \
  'no concurrency/state-machine/locking impact' \
  'no broad architecture/cross-file coupling' \
  'clear acceptance criteria' \
  'auth/security/crypto/secrets' \
  'migrations/schema/data-loss' \
  'deploy/runtime/infra/CI semantics' \
  'concurrency/locking/state machines/queues' \
  'billing/permissions/access control' \
  '>=20' \
  '>=1000' \
  'unclear acceptance criteria'; do
  require_contains "$needle"
  require_parent_contains "$needle"
done

# #274 wide-surface test-refactor routing: a broad multi-file / shared-harness
# test refactor is NOT eligible for the trivial path just because it is test-only
# and runs no runtime code. The trivial criteria must carry the test-blast-radius
# exclusion, and an objective blast-radius signal must route this class to at
# least `moderate`. Tokens are mirrored in both criteria owners (the loop SKILL
# and the canonical parent seam) so the rule fails closed if either re-opens the
# trivial path. Canonical route-name ownership stays in parent-orchestrator.md
# and is unchanged by this rule.
for needle in \
  'no broad multi-file or shared-harness test refactor' \
  'broad test-only refactor' \
  '>=10' \
  'route it at least `moderate`'; do
  require_contains "$needle"
  require_parent_contains "$needle"
done

require_contains 'Classify each target issue/MR as `trivial`, `moderate`, or `high-risk`'
require_parent_contains 'Classify each target issue/MR as `trivial`, `moderate`, or `high-risk`'
require_contains 'Manual direct agent selection is outside this enforcement surface'
require_parent_contains 'Manual direct agent selection is outside this enforcement surface'
# Runtime-aware final reviewer: Claude Code uses the Opus route; OMP keeps the GPT
# route. The GPT builder/reviewer routes are OMP-only (no openai-codex/* on Claude).
require_contains 'mr-reviewer-opus48-xhigh` on Claude Code or `mr-reviewer-gpt55-xhigh` on OMP'
require_contains 'pin `openai-codex/*` models that exist only on OMP'
require_parent_contains 'mandatory independent final reviewer for every tier'
require_parent_contains '`mr-reviewer-opus48-xhigh` on Claude Code or `mr-reviewer-gpt55-xhigh` on OMP'
require_parent_contains 'Claude Code has no `openai-codex/*` route'

# #230 reviewer route resolution: parent must re-resolve from current runtime
# inventory immediately before reviewer launch; agent_inventory changes require
# re-resolution to avoid stale routes.
require_parent_contains 'Immediately before launching the reviewer'
require_parent_contains 'agent_inventory'
require_parent_contains 'Route-resolved-at-launch'

for workflow_file in "$DEV_WORKFLOW_FILE" "$SETUP_DEV_WORKFLOW_FILE"; do
  require_file_contains "$workflow_file" 'Model-tier routing is enforced only for flows launched through `/issue-delivery-loop` and its parent loop'
  require_file_contains "$workflow_file" 'Manual direct agent selection is outside this enforcement surface'
  require_file_contains "$workflow_file" "frontmatter owns the model/effort pin"
  # #249: builder route names are NOT restated here (covered by the negative
  # POINTER_FILES loop above); the canonical table owner is parent-orchestrator.md.
  require_file_contains "$workflow_file" 'mr-reviewer-gpt55-xhigh'
  require_file_contains "$workflow_file" 'mr-reviewer-opus48-xhigh'
  require_file_contains "$workflow_file" '`mr-reviewer-opus48-xhigh` on Claude Code or `mr-reviewer-gpt55-xhigh` on OMP'
  require_file_contains "$workflow_file" 'pin `openai-codex/*` models that exist only on OMP'
done

# Per-batch metrics envelope survives with retro-report-matching names and definitions.
require_contains 'Metrics to report per batch'
# Names must match retro/templates/retro-report.md
require_contains 'Issues attempted'
require_contains 'MRs opened'
require_contains 'MRs merged'
require_contains 'MRs queued (auto-merge)'
require_contains 'MRs blocked'
require_contains 'Review rounds (total / max per MR)'
require_contains 'CI failures'
require_contains 'Brief defects'
require_contains 'Follow-up issues created'
# Brief defects is a pointer to existing criteria, not a new inventory.
require_contains 'start-review/templates/filling-guide.md'
require_contains 'start-review/templates/review-report.md'
# Decoupling proof is conditional on parallel fan-out; token preserved; serial batches skip.
require_contains 'decoupling proof before parallel work'
require_contains 'Serial WIP-1 batches skip'
# Batch teardown checklist: pointer-only for deletion safety.
require_contains 'Batch teardown'
require_contains 'cleanup_pending'
require_contains 'refs/tmp/review/'
require_contains 'start-build/reference/parent-orchestrator.md'
require_contains 'start-review/REVIEW-FLOW.md'

# Post-merge handoff to the read-only verifier recipe survives.
require_contains 'After merge or protected auto-merge'
require_contains 'start-build/reference/post-merge-verifier.md'

printf 'issue-delivery-loop-invariants: PASS\n'
