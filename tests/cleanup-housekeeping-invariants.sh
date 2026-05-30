#!/usr/bin/env bash
set -euo pipefail

# Invariant guard for cleanup-housekeeping/SKILL.md.
# Pins the POST-#149 rescoped identity (deslop + destale), NOT the pre-#149
# architecture/triage scope. Assertions are tokens, not whole sentences, so the
# test documents the load-bearing policy shape rather than exact prose.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SKILL_FILE="$REPO_ROOT/cleanup-housekeeping/SKILL.md"

fail() {
  printf 'cleanup-housekeeping-invariants: FAIL: %s\n' "$*" >&2
  exit 1
}

require_contains() {
  local needle="$1"
  grep -Fq -- "$needle" "$SKILL_FILE" || fail "missing expected token: $needle"
}

[[ -f "$SKILL_FILE" ]] || fail "missing required file: cleanup-housekeeping/SKILL.md"

# Planning-only default survives the rescope (fail-closed: no edits/deletes from
# this skill; approved slices route to the build workflow).
require_contains 'Planning-only by default'
require_contains 'leave implementation to the build workflow'

# Rescoped identity: the two tight subtractive scopes are deslop + destale.
require_contains 'DESLOP'
require_contains 'DESTALE'

# Deslop is gated by a CLOSED allowed-transform list (post-#149: anything off the
# list routes to improve-codebase-architecture, not deslop).
require_contains 'CLOSED list'
require_contains 'improve-codebase-architecture'

# The five-gate sequence (export/reference/incidental-contract/domain/edge) is the
# load-bearing deslop firewall; assert the sequence and its terminal verdict.
require_contains 'Gate sequence'
require_contains 'Export gate'
require_contains 'Reference gate'
require_contains 'Incidental-contract gate'
require_contains 'Domain gate'
require_contains 'Edge gate'
require_contains 'Survives all five'

# Broad-sweep-by-default discovery (amends #149): fan-out is the DEFAULT posture for a
# repo-wide sweep; narrowing to a single/docs-only pass is an explicit, user-requested
# opt-out, not the default. 'broad' must still appear.
require_contains 'broad'
require_contains 'the default posture for discovery'
require_contains 'narrow to a single pass only when'

# OUT-of-scope handoffs with fallbacks stay present (deslop firewall keeps
# boundary-moving work routed away).
require_contains 'handoffs'
require_contains 'fallback'

printf 'cleanup-housekeeping-invariants: PASS\n'
