#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SKILL_FILE="$REPO_ROOT/setup-dev-skills/SKILL.md"
SEED_FILE="$REPO_ROOT/setup-dev-skills/coding-guardrails.md"
ROOT_DOC="$REPO_ROOT/docs/agents/coding-guardrails.md"
ROOT_RULEBOOK="$REPO_ROOT/CLAUDE.md"

require_contains() {
  local file="$1"
  local needle="$2"

  if ! grep -Fq "$needle" "$file"; then
    printf 'missing expected text in %s: %s\n' "${file#$REPO_ROOT/}" "$needle" >&2
    exit 1
  fi
}

require_not_contains() {
  local file="$1"
  local needle="$2"

  if grep -Fq "$needle" "$file"; then
    printf 'unexpected upstream/vendor text in %s: %s\n' "${file#$REPO_ROOT/}" "$needle" >&2
    exit 1
  fi
}

for file in "$SKILL_FILE" "$SEED_FILE" "$ROOT_DOC" "$ROOT_RULEBOOK"; do
  if [[ ! -f "$file" ]]; then
    printf 'missing required file: %s\n' "${file#$REPO_ROOT/}" >&2
    exit 1
  fi
done

require_contains "$SKILL_FILE" "coding guardrails"
require_contains "$SKILL_FILE" "### Coding guardrails"
require_contains "$SKILL_FILE" 'docs/agents/coding-guardrails.md'
for heading in \
  '## Think before coding' \
  '## Simplicity first' \
  '## Surgical changes' \
  '## Goal-driven execution'; do
  require_contains "$SEED_FILE" "$heading"
  require_contains "$ROOT_DOC" "$heading"
done

require_contains "$ROOT_RULEBOOK" 'Coding guardrails: see `docs/agents/coding-guardrails.md`.'
require_contains "$ROOT_RULEBOOK" 'coding guardrails, and dev workflow skill references'

require_not_contains "$SEED_FILE" 'github.com/multica-ai/andrej-karpathy-skills'
require_not_contains "$SEED_FILE" 'If you write 200 lines and it could be 50, rewrite it.'
require_not_contains "$ROOT_DOC" 'github.com/multica-ai/andrej-karpathy-skills'
require_not_contains "$ROOT_DOC" 'If you write 200 lines and it could be 50, rewrite it.'

echo "setup-dev-skills guardrails regression: PASS"
