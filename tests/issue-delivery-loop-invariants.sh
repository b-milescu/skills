#!/usr/bin/env bash
set -euo pipefail

# Invariant guard for issue-delivery-loop/SKILL.md.
# Pins the POST-#151 shape: the operating contract delegates the canonical loop
# to parent-orchestrator.md (decoupling proof before parallel work, parent
# spot-check, revision rounds) via a POINTER instead of paraphrased restatements,
# while keeping the load-bearing batch envelope + metrics + post-merge handoff.
# Assertions are tokens, not whole sentences.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SKILL_FILE="$REPO_ROOT/issue-delivery-loop/SKILL.md"

fail() {
  printf 'issue-delivery-loop-invariants: FAIL: %s\n' "$*" >&2
  exit 1
}

require_contains() {
  local needle="$1"
  grep -Fq -- "$needle" "$SKILL_FILE" || fail "missing expected token: $needle"
}

[[ -f "$SKILL_FILE" ]] || fail "missing required file: issue-delivery-loop/SKILL.md"

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

# Per-batch metrics envelope survives.
require_contains 'Metrics to report per batch'
require_contains 'issues attempted'
require_contains 'review rounds'

# Post-merge handoff to the read-only verifier survives.
require_contains 'After merge or protected auto-merge'
require_contains 'post-merge-verifier/SKILL.md'

printf 'issue-delivery-loop-invariants: PASS\n'
