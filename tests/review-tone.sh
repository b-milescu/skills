#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
REVIEW_FLOW_FILE="$REPO_ROOT/start-review/REVIEW-FLOW.md"
SKILL_FILE="$REPO_ROOT/start-review/SKILL.md"

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

for file in "$REVIEW_FLOW_FILE" "$SKILL_FILE"; do
  if [[ ! -f "$file" ]]; then
    printf 'missing required file: %s\n' "${file#$REPO_ROOT/}" >&2
    exit 1
  fi
done

# The scoped Review tone section keeps the demanding voice for structural
# maintainability findings.
require_contains "$REVIEW_FLOW_FILE" '## Review tone'
require_contains "$REVIEW_FLOW_FILE" 'Tone never moves the bar.'

# Style-non-blocking guarantees stay present so the tone cannot be read as
# lowering the C-N -> MF-N bar.
require_contains "$REVIEW_FLOW_FILE" 'Do not request changes for taste'
require_contains "$SKILL_FILE" 'Treat style-only preferences as non-blocking'

# No-vendoring norm: neither file vendors the upstream URL or verbatim thermo
# prose the tone was adapted from.
for file in "$REVIEW_FLOW_FILE" "$SKILL_FILE"; do
  require_not_contains "$file" 'cursor/plugins'
  require_not_contains "$file" 'Measure twice, cut once.'
done

echo "review tone regression: PASS"
