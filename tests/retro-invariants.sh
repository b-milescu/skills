#!/usr/bin/env bash
set -euo pipefail

# Invariant guard for retro/SKILL.md.
# Pins the secret/dump safety tokens, the proposal-only / route-out boundary
# (the skill never edits canonical skills/docs/tests directly; it emits
# proposals and routes approved candidates out via /plan-to-issues), the
# safety-floor guard (floor-touching proposals are classified human-decision),
# and the lookback-scope tokens added by #256. Assertions are HEAD-exact
# tokens, not paraphrases (per the #254 lesson).

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SKILL_FILE="$REPO_ROOT/retro/SKILL.md"

fail() {
  printf 'retro-invariants: FAIL: %s\n' "$*" >&2
  exit 1
}

require_contains() {
  local needle="$1"
  grep -Fq -- "$needle" "$SKILL_FILE" || fail "missing expected token: $needle"
}

refute_contains() {
  local needle="$1"
  if grep -Fq -- "$needle" "$SKILL_FILE"; then
    fail "unexpected token present: $needle"
  fi
}

[[ -f "$SKILL_FILE" ]] || fail "missing required file: retro/SKILL.md"

# Secret / sensitive-payload safety: never print secrets, never paste full
# session dumps, redact reconstructable content.
require_contains 'Never print secrets'
require_contains 'Never paste full session dumps'
require_contains 'redact with `[REDACTED]`'

# Proposal-only / route-out boundary: emit proposals, never edit the canonical
# skill/doc/test surfaces directly, and route approved candidates out to the
# issue workflow via /plan-to-issues.
require_contains 'Proposal-only'
require_contains 'never edits skills, templates, docs, gates, or tests directly'
require_contains "Route, don't edit"
require_contains '/plan-to-issues'

# Safety-floor guard: a proposal that touches a hard floor is classified
# human-decision and stops there (this closes the longitudinal floor-guard gap).
require_contains 'Safety floors are not retro material'
require_contains 'classified `human-decision` and stops there'
require_contains 'safety-floor check'

# Lookback scope (#256): both scope names, the four imported behaviors,
# graceful-degradation wording, and the no-overfit rule.
require_contains '`batch`'
require_contains '`lookback <date range>`'
require_contains 'Aggregate counts'
require_contains 'Active memory discovery with graceful degradation'
require_contains 'if it is unavailable, say so and continue'
require_contains 'Date-range scoping'
require_contains "don't-overfit-to-anecdotes rule"

# The merged skill must not resurrect a reference to the retired skill. The
# needle is assembled from two parts so this guard file itself stays free of
# the banned literal (acceptance: zero tracked references survive the merge).
retired_skill_ref="memory-""retrospective"
refute_contains "$retired_skill_ref"

printf 'retro-invariants: PASS\n'
