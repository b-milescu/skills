#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'start-build-discovery-budget: FAIL: %s\n' "$*" >&2
  exit 1
}

# Issue #316 deleted the start-build/BUILD-FLOW.md redirect layer. The Discovery
# Budget / Build Plan Packet sections are now validated only at their canonical
# owner (reference/context-and-planning.md); the retired router-stub checks are
# gone.
context="start-build/reference/context-and-planning.md"
skill="start-build/SKILL.md"
template="start-build/templates/build-plan-packet.md"

for section in 'Discovery Budget' 'Build Plan Packet'; do
  grep -qE "^## ${section}$" "$context" || fail "$context missing canonical $section section"
done

discovery_start="$(grep -n '^## Discovery Budget$' "$context" | cut -d: -f1)"
packet_start="$(grep -n '^## Build Plan Packet$' "$context" | cut -d: -f1)"
check_gate_start="$(grep -n '^## Check gate discovery$' "$context" | cut -d: -f1)"

[ -n "$discovery_start" ] || fail "Discovery Budget heading not found"
[ -n "$packet_start" ] || fail "Build Plan Packet heading not found"
[ -n "$check_gate_start" ] || fail "Check gate discovery heading not found"
[ "$discovery_start" -lt "$packet_start" ] || fail "Discovery Budget must precede Build Plan Packet"
[ "$packet_start" -lt "$check_gate_start" ] || fail "Build Plan Packet must precede check gate discovery"

discovery_block="$(sed -n "${discovery_start},$((packet_start - 1))p" "$context")"
packet_block="$(sed -n "${packet_start},$((check_gate_start - 1))p" "$context")"

require_block_text() {
  block="$1"
  needle="$2"
  message="$3"
  printf '%s\n' "$block" | grep -qF "$needle" || fail "$message"
}

printf '%s\n' "$discovery_block" | grep -q 'bounded' || fail "Discovery Budget block missing bounded exploration language"
printf '%s\n' "$discovery_block" | grep -q 'current behavior, affected surfaces, test entrypoint, safety constraints, and non-goals' || fail "Discovery Budget block missing required facts list"
printf '%s\n' "$discovery_block" | grep -q 'route the issue back to triage' || fail "Discovery Budget block missing triage bounce rule"
printf '%s\n' "$discovery_block" | grep -q 'exact unanswered questions' || fail "Discovery Budget block missing exact-question requirement"

for context_source in 'ADRs' 'architecture docs' 'domain docs' 'CONTEXT.md'; do
  require_block_text "$discovery_block" "$context_source" "Discovery Budget block missing evidence-driven expansion target: $context_source"
done

for trigger in 'issue links' 'rulebook references' 'changed paths' 'imports/callers' 'tests' 'safety invariants' 'failing checks' 'explicit user/parent prompt'; do
  require_block_text "$discovery_block" "$trigger" "Discovery Budget block missing evidence trigger: $trigger"
done

printf '%s\n' "$packet_block" | grep -q 'issue, intended behavior, affected surfaces, test plan, risk, and non-goals' || fail "Build Plan Packet block missing required fields"
printf '%s\n' "$packet_block" | grep -q '../templates/build-plan-packet.md' || fail "Build Plan Packet block missing template pointer"
require_block_text "$packet_block" 'loaded context sources' "Build Plan Packet block missing loaded-context-source recording"
require_block_text "$packet_block" 'why each source was relevant' "Build Plan Packet block missing context relevance rationale"

grep -qF 'skill://start-build/reference/context-and-planning.md' "$skill" || \
  fail "$skill missing canonical context-and-planning pointer"
grep -qF 'skill://start-build/templates/build-plan-packet.md' "$skill" || \
  fail "$skill missing canonical Build Plan Packet pointer"
grep -qF -- '- **Standalone:**' "$skill" || \
  fail "$skill missing compact Standalone contract"
grep -qF -- '- **Child `mr-builder`:**' "$skill" || \
  fail "$skill missing compact Child contract"
grep -qF 'parent owns Gate Receipt and ready' "$skill" || \
  fail "$skill missing parent-owned child boundary"

for field in '## Issue' '## Intended behavior' '## Loaded context sources' '## Affected surfaces' '## Test plan' '## Risk' '## Non-goals'; do
  grep -qF "$field" "$template" || fail "$template missing $field"
done

grep -qF 'why relevant' "$template" || fail "$template missing context-source relevance instruction"

printf 'start-build-discovery-budget: PASS\n'
