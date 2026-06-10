#!/usr/bin/env bash
set -euo pipefail

# Invariant guard for issue-delivery-loop/SKILL.md, Dev Workflow docs, and the
# parent launch seam. Pins the POST-#151 pointer shape while also guarding the
# #226 skill-only model-tier routing contract and the #227 runtime-aware reviewer
# split: classify before child launch, use exact routed builder/reviewer names at
# parent-orchestrator dispatch, route the final reviewer by runtime
# (mr-reviewer-opus48-xhigh on Claude Code, mr-reviewer-gpt55-xhigh on OMP), keep
# the OMP-only optional scout non-gate, and restrict the OMP Opus xhigh reviewer
# fallback to explicit provider failure only.
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
# (Opus 4.8 xhigh on Claude Code, GPT-5.5 xhigh on OMP); the GPT scout/reviewer
# routes are OMP-only and the scout is optional/non-gate; the OMP Opus xhigh route
# is provider-failure fallback only.
for needle in \
  'mr-builder-sonnet-low' \
  'mr-builder-opus48' \
  'mr-builder-opus48-high' \
  'mr-reviewer-gpt55-xhigh' \
  'mr-review-scout-gpt54-low' \
  'mr-reviewer-opus48-xhigh'; do
  require_contains "$needle"
  require_parent_contains "$needle"
done

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

require_contains 'Classify each target issue/MR as `trivial`, `moderate`, or `high-risk`'
require_parent_contains 'Classify each target issue/MR as `trivial`, `moderate`, or `high-risk`'
require_contains 'Manual direct agent selection is outside this enforcement surface'
require_parent_contains 'Manual direct agent selection is outside this enforcement surface'
# Runtime-aware final reviewer: Claude Code uses the Opus route; OMP keeps the GPT
# route. The GPT reviewer/scout routes are OMP-only (no openai-codex/* on Claude).
require_contains 'final reviewer `mr-reviewer-opus48-xhigh` on Claude Code or `mr-reviewer-gpt55-xhigh` on OMP'
require_contains 'pin `openai-codex/*` models that exist only on OMP'
require_parent_contains 'mandatory independent final reviewer for every tier'
require_parent_contains '`mr-reviewer-opus48-xhigh` on Claude Code or `mr-reviewer-gpt55-xhigh` on OMP'
require_parent_contains 'Claude Code has no `openai-codex/*` route'
require_contains 'cannot satisfy the mandatory independent review gate'
require_parent_contains 'cannot satisfy independent review'
require_parent_contains 'cannot approve/pass/fail/request changes'
require_contains 'explicit parent/operator decision token'
require_parent_contains 'explicit parent/operator decision token'
require_contains 'never a cost downgrade'
require_parent_contains 'never describe or select it as a cost downgrade'

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
  require_file_contains "$workflow_file" 'mr-builder-sonnet-low'
  require_file_contains "$workflow_file" 'mr-builder-opus48'
  require_file_contains "$workflow_file" 'mr-builder-opus48-high'
  require_file_contains "$workflow_file" 'mr-review-scout-gpt54-low'
  require_file_contains "$workflow_file" 'mr-reviewer-gpt55-xhigh'
  require_file_contains "$workflow_file" 'mr-reviewer-opus48-xhigh'
  require_file_contains "$workflow_file" '`mr-reviewer-opus48-xhigh` on Claude Code or `mr-reviewer-gpt55-xhigh` on OMP'
  require_file_contains "$workflow_file" 'pin `openai-codex/*` models that exist only on OMP'
  require_file_contains "$workflow_file" 'cannot satisfy independent review'
  require_file_contains "$workflow_file" 'explicit parent/operator decision token'
  require_file_contains "$workflow_file" 'never a cost downgrade'
done

# Per-batch metrics envelope survives.
require_contains 'Metrics to report per batch'
require_contains 'issues attempted'
require_contains 'review rounds'

# Post-merge handoff to the read-only verifier recipe survives.
require_contains 'After merge or protected auto-merge'
require_contains 'start-build/reference/post-merge-verifier.md'

printf 'issue-delivery-loop-invariants: PASS\n'
