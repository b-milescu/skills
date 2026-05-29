#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'start-build-bypass-wording: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1"
  local needle="$2"
  local message="$3"
  grep -qF "$needle" "$file" || fail "$message"
}

reject_text() {
  local file="$1"
  local needle="$2"
  local message="$3"
  if grep -qF "$needle" "$file"; then
    fail "$message"
  fi
}

canonical="start-build/reference/standalone-gate.md"
safety="start-build/SAFETY.md"
router="start-build/BUILD-FLOW.md"

# --- Canonical owner: strict, non-inferable accepted-phrase bypass rule ---

# The loose "or equivalent explicit override" escape hatch must be gone: it let
# agents infer a bypass from vague phrasing.
reject_text "$canonical" 'or equivalent explicit override' \
  "$canonical still uses the inferable 'or equivalent explicit override' bypass wording"

# Bypass must be limited to an exact accepted-phrase set, not paraphrase.
require_text "$canonical" 'accepted bypass phrase' \
  "$canonical missing strict accepted-phrase bypass rule"
require_text "$canonical" '"skip gate"' \
  "$canonical missing the literal \"skip gate\" accepted phrase"
require_text "$canonical" '"merge unreviewed"' \
  "$canonical missing the literal \"merge unreviewed\" accepted phrase"

# Ambiguous release language must NOT bypass and must be clarified.
require_text "$canonical" 'Ambiguous release language' \
  "$canonical missing ambiguous-release-language non-bypass rule"
require_text "$canonical" 'does not bypass' \
  "$canonical missing explicit 'does not bypass' statement"
require_text "$canonical" 'must be clarified' \
  "$canonical missing the requirement to clarify ambiguous bypass language"
for phrase in 'ship it' 'looks fine' 'lgtm'; do
  require_text "$canonical" "$phrase" \
    "$canonical missing example of non-bypassing vague phrase: $phrase"
done

# Audit trail: reason, named human/authorized actor, Review gate field, MR comment.
require_text "$canonical" 'named human' \
  "$canonical missing named-human/authorized-actor bypass requirement"
require_text "$canonical" 'reason' \
  "$canonical missing bypass reason requirement"
require_text "$canonical" 'bypassed (human override)' \
  "$canonical missing Review gate field bypass value"
require_text "$canonical" 'MR comment' \
  "$canonical missing MR comment audit-trail requirement"

# Bypass never grants builder self-approval/self-merge.
require_text "$canonical" 'self-approval' \
  "$canonical missing no-self-approval-under-bypass guard"

# --- Pointer-only owners: SAFETY.md and BUILD-FLOW.md ---

# Point, don't copy: neither pointer doc may restate the strict accepted-phrase
# rule. They must point at the canonical owner and preserve no-self-approval.
require_text "$safety" 'reference/standalone-gate.md#human-bypass-protocol' \
  "$safety missing pointer to canonical human bypass protocol"
reject_text "$safety" 'accepted bypass phrase' \
  "$safety restates the strict accepted-phrase rule instead of pointing to the canonical owner"
require_text "$safety" 'self-approval' \
  "$safety lost the no-self-approval safety invariant"

require_text "$router" 'reference/standalone-gate.md#human-bypass-protocol' \
  "$router missing pointer to canonical human bypass protocol"
reject_text "$router" 'accepted bypass phrase' \
  "$router restates the strict accepted-phrase rule instead of pointing to the canonical owner"
require_text "$router" 'self-approval' \
  "$router lost the no-self-approval safety invariant"

printf 'start-build-bypass-wording: PASS\n'
