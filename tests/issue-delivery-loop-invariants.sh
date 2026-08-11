#!/usr/bin/env bash
set -euo pipefail

# Invariant guard for issue-delivery-loop/SKILL.md, Dev Workflow docs, and the
# parent launch seam. Pins the POST-#151 pointer shape while also guarding the
# #226 skill-only model-tier routing contract, the #227 runtime-aware reviewer
#301 shared route-name cutover: classify launch, use exact shared model-free
# builder/reviewer route basenames at parent-orchestrator dispatch, keep
# model/provider pins in agent frontmatter/body prose, route final reviewer
# through `mr-reviewer-final`, no generic fallback builder/reviewer, no review
# scout.
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

# #226/#227/#301 model-free tier routing: loop classifies target, parent seam
# launches exact shared routed agents. Final review gate uses shared
# `mr-reviewer-final`; model/provider pins stay in selected agent
# frontmatter/body prose, so no generic fallback builder/reviewer or review
# scout.
#
# #249 single-table-owner split: the per-tier builder route NAMES live in exactly
# one canonical table (parent-orchestrator.md). The three pointer files
# (issue-delivery-loop SKILL.md + the two Dev Workflow docs) keep `skill://`
# pointers and the independent-review FLOOR sentences, but must not restate the
# builder route names on their doc surface.
POINTER_FILES=("$SKILL_FILE" "$DEV_WORKFLOW_FILE" "$SETUP_DEV_WORKFLOW_FILE")
BUILDER_ROUTE_NAMES=(
  'mr-builder-trivial'
  'mr-builder-moderate'
  'mr-builder-high-risk'
)

# Positive: the canonical table owner names every builder route. The runtime
# reviewer routes are floor sentences and stay reachable in all four files.
for needle in \
  'mr-builder-trivial' \
  'mr-builder-moderate' \
  'mr-builder-high-risk'; do
  require_parent_contains "$needle"
done
for needle in \
  'mr-reviewer-final'; do
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

require_contains 'Classify target issue/MR `trivial`, `moderate`, or `high-risk`'
require_parent_contains 'Classify target issue/MR `trivial`, `moderate`, or `high-risk`'
require_contains 'Manual direct agent selection outside enforcement surface'
require_parent_contains 'Manual direct agent selection outside enforcement surface'
# Runtime-neutral final reviewer: shared route name resolves current dialect;
# model/provider pins live in selected agent frontmatter/body prose.
require_contains 'mandatory independent final-reviewer route `mr-reviewer-final`'
require_contains 'Model pins live in frontmatter; provider effort pins live too'
require_parent_contains 'mandatory independent final reviewer route is `mr-reviewer-final`'
require_parent_contains 'Model pins live in frontmatter; provider effort pins live too, never in route name'

# #302 runtime budget notices are runtime-state interruptions, not scope blockers.
require_contains 'runtime budget/token/runtime notices are runtime state rather than task-scope changes'
require_contains 'resume the same child/worktree when runtime recovered'
require_contains 'without recasting the issue as product/workflow-scope blocked'
require_parent_contains 'Runtime budget/token/runtime notices are not scope changes'
require_parent_contains 'resume same child/worktree when runtime recovered'
require_parent_contains 'runtime/tool blocker'

# #230 reviewer route resolution: parent records route resolution from current
# runtime inventory in the minimal reviewer launch prompt.
require_parent_contains 'When the parent starts a fresh reviewer'
require_parent_contains 'current runtime inventory'
require_parent_contains 'Route-resolved-at-launch'

for workflow_file in "$DEV_WORKFLOW_FILE" "$SETUP_DEV_WORKFLOW_FILE"; do
  require_file_contains "$workflow_file" 'flows launched through `/issue-delivery-loop` parent loop'
  require_file_contains "$workflow_file" 'Manual direct agent selection outside enforcement surface'
  require_file_contains "$workflow_file" 'Model pins live in frontmatter; provider effort pins live too'
  # #249: builder route names NOT restated here (covered by negative
  # POINTER_FILES above); canonical table owner is parent-orchestrator.md.
  require_file_contains "$workflow_file" 'mandatory final-reviewer route'
  require_file_contains "$workflow_file" 'Missing route remains route-unavailable blocker'
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
# #374 queued-auto-merge is an intermediate delivery state. Queue action evidence
# is distinct from merge-event evidence; only an observed merge may advance the
# existing handoff route to the read-only verifier, and clean completion needs
# its checked snapshot.
require_contains 'Treat `auto-merge queued` as pending'
require_contains 'does not count as **MRs merged**'
require_contains 'without polling CI'
require_contains 'phase: `post-merge-verify`'
require_contains 'expected_next_actor: `verifier`'
require_contains 'expected_next_action: `post-merge-verify`'
require_contains '`post_merge_snapshot.kind=post-merge-snapshot`'
require_contains 'cannot satisfy clean delivery or batch completion'
refute_file_contains "$SKILL_FILE" '`wait-merge-event`'

# Batch teardown checklist: pointer-only for deletion safety.
require_contains 'Batch teardown'
require_contains 'cleanup_pending'
require_contains 'refs/tmp/review/'
require_contains 'start-build/reference/parent-orchestrator.md'
require_contains 'start-review/REVIEW-FLOW.md'
require_contains 'git remote prune --dry-run origin'
require_contains 'stale refs listed'
require_contains 'git for-each-ref refs/tmp/review/'
require_contains 'remaining ref names'
require_contains 'blocks a clean-teardown claim'

# #380 coordinator isolation and recorded-worktree ownership stay executable at
# launch/finish without turning repository-wide discovery into cleanup scope.
require_parent_contains 'session-owned worktree ledger'
require_parent_contains 'coordinator_path="$(cd "$coordinator_path" && pwd -P)"'
require_parent_contains 'child_worktree_path="$(cd "$child_worktree_path" && pwd -P)"'
require_parent_contains 'No repository-wide worktree discovery result'
require_parent_contains '`--coordinator-path "$coordinator_path"`'
require_parent_contains 'every local-mutating finish call'
require_parent_contains '`--worktree-path "$child_worktree_path"`'
require_parent_contains 'residual session-owned worktree'
require_contains 'session-owned worktree ledger'
require_contains 'residual session-owned worktree'

# Post-merge handoff to the read-only verifier recipe survives.
require_contains 'Do not invoke post-merge verification or teardown while the MR remains queued'
require_contains 'start-build/reference/post-merge-verifier.md'

printf 'issue-delivery-loop-invariants: PASS\n'
