#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'start-build-stale-reviewer-control: FAIL: %s\n' "$*" >&2
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

# Issue #316 deleted start-build/BUILD-FLOW.md; its timeout compatibility stub is
# gone. The stale-reviewer-control invariants are validated only at their
# canonical owners (timeout-handling.md, standalone-gate.md, parent-orchestrator.md).
standalone="start-build/reference/standalone-gate.md"
timeout="start-build/reference/timeout-handling.md"
parent="start-build/reference/parent-orchestrator.md"

for file in "$standalone" "$timeout" "$parent"; do
  [ -f "$file" ] || fail "missing expected workflow doc: $file"
done

require_text "$timeout" "runtime's status/control/interruption mechanism" \
  "$timeout must route through runtime status/control/interruption when available"
require_text "$timeout" 'escalate instead of launching a duplicate reviewer' \
  "$timeout must escalate when status/control is unavailable"
require_text "$timeout" 'Record the reason before any second reviewer attempt' \
  "$timeout must require documented reason before a second attempt"
require_text "$timeout" 'failed, stale, interrupted, or unreachable' \
  "$timeout must limit second attempt to failed/stale/interrupted/unreachable states"
require_text "$timeout" 'still active' \
  "$timeout must forbid replacing an active reviewer"

require_text "$standalone" 'No fixed wall-clock value alone authorizes replacement' \
  "$standalone must not let a fixed timeout alone authorize replacement"
require_text "$standalone" 'timeout / stale / interrupted are non-completion states' \
  "$standalone Review Gate Summary must record timeout/stale/interrupted without implying completion"
require_text "$standalone" 'pass / request-changes / reject / blocked / timeout / stale / interrupted' \
  "$standalone Review Gate Summary table must use the verdict enum plus timeout/stale/interrupted states"
reject_text "$standalone" 'approve / request-changes / reject / timeout / stale / interrupted' \
  "$standalone Review Gate Summary table must not retain the approve round token"

require_text "$parent" 'check the reviewer run status/activity before replacement' \
  "$parent must check reviewer status/activity before replacement"
require_text "$parent" 'Do not start a second reviewer while the first run is still active' \
  "$parent must forbid duplicate active reviewer runs"
require_text "$parent" 'escalate instead of launching a duplicate reviewer' \
  "$parent must fail closed when runtime control is unavailable"

for file in "$standalone" "$timeout" "$parent"; do
  reject_text "$file" 'within 10 minutes' \
    "$file still contains exact-10-minute blind retry wording"
  reject_text "$file" 'Timeout: 10 minutes per round' \
    "$file still contains fixed 10-minute timeout wording"
  reject_text "$file" 'try one fresh reviewer session, then escalate' \
    "$file still contains blind fresh-reviewer retry wording"
  reject_text "$file" 'Start one fresh reviewer session with the same task prompt' \
    "$file still contains unconditional second reviewer wording"
done

printf 'start-build-stale-reviewer-control: PASS\n'
