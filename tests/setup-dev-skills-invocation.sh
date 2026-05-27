#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SKILL_FILE="$REPO_ROOT/setup-dev-skills/SKILL.md"
README_FILE="$REPO_ROOT/README.md"

require_contains() {
  local file="$1"
  local needle="$2"

  if ! grep -Fq "$needle" "$file"; then
    printf 'missing expected text in %s: %s\n' "${file#$REPO_ROOT/}" "$needle" >&2
    exit 1
  fi
}

frontmatter="$(awk 'NR == 1 { if ($0 != "---") exit 2; next } $0 == "---" { exit } { print }' "$SKILL_FILE")"
if ! printf '%s\n' "$frontmatter" | grep -qx "disable-model-invocation: true"; then
  printf 'setup-dev-skills/SKILL.md frontmatter must keep disable-model-invocation: true\n' >&2
  exit 1
fi

require_contains "$SKILL_FILE" "Manual invocation only."
require_contains "$SKILL_FILE" 'Agents may recommend `/setup-dev-skills` when Agent Setup Docs are missing or stale'
require_contains "$SKILL_FILE" "Before running it or writing setup docs, ask the user for permission"
require_contains "$README_FILE" 'Manual Setup Skill (`disable-model-invocation: true`)'
require_contains "$README_FILE" 'Invoke explicitly as `/setup-dev-skills`'
require_contains "$README_FILE" "must ask before running or writing"

echo "setup-dev-skills invocation regression: PASS"
