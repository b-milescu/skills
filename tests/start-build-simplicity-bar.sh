#!/usr/bin/env bash
set -euo pipefail

# Regression guard for issue #141: the within-diff simplicity bar in
# start-build/SAFETY.md "Quality rules". Asserts the verbatim bullet, its
# blast-radius firewall anchors, the preserved scope anti-pattern, and the
# repo no-vendoring norm (no upstream URL / verbatim thermo prose).

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SAFETY_FILE="$REPO_ROOT/start-build/SAFETY.md"
SKILL_FILE="$REPO_ROOT/start-build/SKILL.md"

require_contains() {
  local file="$1"
  local needle="$2"

  if ! grep -Fq "$needle" "$file"; then
    printf 'missing expected text in %s: %s\n' "${file#"$REPO_ROOT"/}" "$needle" >&2
    exit 1
  fi
}

require_not_contains() {
  local file="$1"
  local needle="$2"

  if grep -Fq "$needle" "$file"; then
    printf 'unexpected upstream/vendor text in %s: %s\n' "${file#"$REPO_ROOT"/}" "$needle" >&2
    exit 1
  fi
}

for file in "$SAFETY_FILE" "$SKILL_FILE"; do
  if [[ ! -f "$file" ]]; then
    printf 'missing required file: %s\n' "${file#"$REPO_ROOT"/}" >&2
    exit 1
  fi
done

# The within-diff simplicity bar bullet is present.
require_contains "$SAFETY_FILE" 'Simplest version of your own change.'

# The blast-radius firewall anchors are present: the bar applies only to the
# touched lines, and the in-doubt tie-breaker routes to surrounding code.
require_contains "$SAFETY_FILE" 'within the lines your diff introduces or touches'
require_contains "$SAFETY_FILE" 'treat it as surrounding code'

# The scope anti-pattern is preserved so the bar cannot be read as a
# drive-by-refactor license.
require_contains "$SAFETY_FILE" 'Open a separate issue.'

# No-vendoring norm: neither file vendors the upstream URL or verbatim
# thermo prose the bar was adapted from.
for file in "$SAFETY_FILE" "$SKILL_FILE"; do
  require_not_contains "$file" 'cursor/plugins'
  require_not_contains "$file" 'Measure twice, cut once.'
done

echo "start-build simplicity bar regression: PASS"
