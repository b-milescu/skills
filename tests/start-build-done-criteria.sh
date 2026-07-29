#!/usr/bin/env bash
set -euo pipefail

# Regression guard for issue #135: start-build done criteria must be
# mode-tiered instead of single-mode (approval + CI + merge + issue-closed).
# Asserts the four named done tiers in SAFETY.md, that each tier points to its
# existing reference flow rather than restating it, that the child builder tier
# ends at its Gate owner-specific handoff with no self-approve/self-merge
# wording, and that SKILL.md flags the checklist as mode-specific.

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
    printf 'unexpected text in %s: %s\n' "${file#"$REPO_ROOT"/}" "$needle" >&2
    exit 1
  fi
}

for file in "$SAFETY_FILE" "$SKILL_FILE"; do
  if [[ ! -f "$file" ]]; then
    printf 'missing required file: %s\n' "${file#"$REPO_ROOT"/}" >&2
    exit 1
  fi
done

# Extract the SAFETY.md "## Done criteria" section body so the tier and
# no-merge assertions apply to the done criteria, not the rest of the file.
done_section="$(awk '
  /^## Done criteria$/ { in_section=1; next }
  in_section && /^## / { exit }
  in_section { print }
' "$SAFETY_FILE")"

if [[ -z "$done_section" ]]; then
  echo "SAFETY.md is missing a '## Done criteria' section" >&2
  exit 1
fi

require_done_contains() {
  local needle="$1"
  if ! printf '%s\n' "$done_section" | grep -Fq "$needle"; then
    printf 'missing expected text in SAFETY.md "## Done criteria": %s\n' "$needle" >&2
    exit 1
  fi
}

# The four mode tiers must be named so done is no longer single-mode.
require_done_contains 'builder-ready'
require_done_contains 'review-gate-complete'
require_done_contains 'finish-merge'
require_done_contains 'post-merge-verified'

# Each tier points to its existing reference flow rather than restating it.
require_done_contains 'reference/child-builder.md'
require_done_contains 'reference/standalone-gate.md'
require_done_contains 'reference/parent-orchestrator.md'
require_done_contains 'reference/post-merge-verifier.md'

# The builder-ready tier must end at handoff without approval/merge. The
# universal summary must preserve the builder-owned ready transition and the
# parent-owned Draft candidate handoff as distinct completion conditions.
require_done_contains 'final handoff'
require_contains "$SKILL_FILE" 'builder-owned requires a ready MR plus handoff'
require_contains "$SKILL_FILE" 'parent-owned requires a Draft candidate plus complete handoff to the parent'
require_not_contains "$SKILL_FILE" '(MR ready + handoff)'
require_not_contains "$SAFETY_FILE" 'builder may self-approve'
require_not_contains "$SAFETY_FILE" 'builder may merge its own'

# SKILL.md flags that the canonical checklist is mode-specific.
require_contains "$SKILL_FILE" 'mode-specific'

echo "start-build done criteria regression: PASS"
