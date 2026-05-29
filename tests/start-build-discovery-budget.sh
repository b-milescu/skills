#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'start-build-discovery-budget: FAIL: %s\n' "$*" >&2
  exit 1
}

flow="start-build/BUILD-FLOW.md"
skill="start-build/SKILL.md"
template="start-build/templates/build-plan-packet.md"

grep -qE '^## Discovery Budget$' "$flow" || fail "$flow missing Discovery Budget section"
grep -qE '^## Build Plan Packet$' "$flow" || fail "$flow missing Build Plan Packet section"

discovery_start="$(grep -n '^## Discovery Budget$' "$flow" | cut -d: -f1)"
packet_start="$(grep -n '^## Build Plan Packet$' "$flow" | cut -d: -f1)"
builder_modes_start="$(grep -n '^## Builder invocation modes$' "$flow" | cut -d: -f1)"

[ -n "$discovery_start" ] || fail "Discovery Budget heading not found"
[ -n "$packet_start" ] || fail "Build Plan Packet heading not found"
[ -n "$builder_modes_start" ] || fail "Builder invocation modes heading not found"

[ "$discovery_start" -lt "$packet_start" ] || fail "Discovery Budget must precede Build Plan Packet"
[ "$packet_start" -lt "$builder_modes_start" ] || fail "Build Plan Packet must precede Builder invocation modes"

discovery_block="$(sed -n "${discovery_start},$((packet_start - 1))p" "$flow")"
packet_block="$(sed -n "${packet_start},$((builder_modes_start - 1))p" "$flow")"

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
printf '%s\n' "$packet_block" | grep -q 'templates/build-plan-packet.md' || fail "Build Plan Packet block missing template pointer"
require_block_text "$packet_block" 'loaded context sources' "Build Plan Packet block missing loaded-context-source recording"
require_block_text "$packet_block" 'why each source was relevant' "Build Plan Packet block missing context relevance rationale"

require_block_text "$(cat "$skill")" 'rulebook index first' "$skill missing rulebook-index-first guidance"
if grep -qE 'Load the host project.?s rulebook first.*architecture docs, ADRs' "$skill"; then
  fail "$skill still implies architecture docs and ADRs are loaded as part of the first rulebook read"
fi

for pattern in 'Standalone `/start-build` mode' 'Child `mr-builder` mode'; do
  grep -qF "$pattern" "$flow" || fail "$flow missing authority boundary text: $pattern"
done

grep -qF 'templates/build-plan-packet.md' "$skill" || fail "$skill missing build plan packet template pointer"

for field in '## Issue' '## Intended behavior' '## Loaded context sources' '## Affected surfaces' '## Test plan' '## Risk' '## Non-goals'; do
  grep -qF "$field" "$template" || fail "$template missing $field"
done

grep -qF 'why relevant' "$template" || fail "$template missing context-source relevance instruction"

printf 'start-build-discovery-budget: PASS\n'
