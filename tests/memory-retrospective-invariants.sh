#!/usr/bin/env bash
set -euo pipefail

# Invariant guard for memory-retrospective/SKILL.md.
# Pins the secret/dump safety tokens AND the POST-#153 propose-only / route-out
# boundary (the skill never edits skill prompts/templates/docs/gates/tests
# directly; it emits proposals and routes approved candidates out to the
# issue/build workflow). Assertions are tokens, not whole sentences.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SKILL_FILE="$REPO_ROOT/memory-retrospective/SKILL.md"

fail() {
  printf 'memory-retrospective-invariants: FAIL: %s\n' "$*" >&2
  exit 1
}

require_contains() {
  local needle="$1"
  grep -Fq -- "$needle" "$SKILL_FILE" || fail "missing expected token: $needle"
}

[[ -f "$SKILL_FILE" ]] || fail "missing required file: memory-retrospective/SKILL.md"

# Read-only retrospective stance.
require_contains 'Read-only'

# Secret / sensitive-payload safety: never print secrets, never paste full
# session dumps, redact reconstructable examples.
require_contains 'Never print secrets'
require_contains 'Never paste full session dumps'
require_contains 'Redact or omit'

# Post-#153 propose-only / route-out boundary: emit proposals, never edit the
# skill surfaces directly, and route approved candidates to the issue/build
# workflow.
require_contains 'Output proposals only'
require_contains 'never edit skill prompts'
require_contains 'Route approved candidates'
require_contains 'gitlab-to-issues'

# Do not write back / require claude-mem for normal repo checks (read-only edge of
# the boundary).
require_contains 'Do not upload, write back'

printf 'memory-retrospective-invariants: PASS\n'
