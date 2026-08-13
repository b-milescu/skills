#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

failures=0
require() {
  local file="$1" pattern="$2" label="$3"
  if ! grep -Eiq -- "$pattern" "$file"; then
    printf 'safety-floor-tokens: FAIL: %s missing %s\n' "$file" "$label" >&2
    failures=$((failures + 1))
  fi
}

guard="forge/reference/common-guard.md"
build="start-build/SKILL.md"
review="start-review/SKILL.md"
flow="start-review/REVIEW-FLOW.md"
loop="issue-delivery-loop/SKILL.md"
parent="start-build/reference/parent-orchestrator.md"

require "$guard" 'reviewed commit binding' 'reviewed-commit binding'
require "$guard" 'CI evidence bound to that commit or a provider-proven integration candidate' 'commit-bound/provider-proven CI'
require "$guard" 'action-specific authority and provenance' 'action-specific authority provenance'
require "$guard" 'exactly one mutation' 'single-mutation boundary'
require "$guard" 'provider-native post-mutation re-read' 'provider-native post-read'
require "$guard" 'blocks without transport fallback' 'fail-closed behavior'

require "$build" 'exact-commit CI' 'exact-commit CI'
require "$build" 'fresh independent reviewer' 'mandatory independent review'
require "$build" 'child/parent/reviewer/verifier' 'role boundaries'
require "$build" 'authority guards' 'authority guards'
require "$build" 'Post-merge' 'post-merge verification'
require "$build" 'verification is read-only' 'read-only post-merge verification'
require "$flow" 'gate-eligible reviewer is fresh' 'fresh independent review'
require "$flow" 'exact reviewed commit' 'exact reviewed commit'
require "$flow" 'CI[^.]*bound to the reviewed commit' 'bound CI'
require "$review" 'verdict, approval, finish, action blocker, and next action separate' 'authority/action separation'
require "$flow" 'Fail-closed review coverage' 'complete coverage fail-closed'
require "$review" 'Post-merge verification is a' 'post-merge verification'
require "$review" 'separate read-only actor' 'read-only post-merge actor'
require "$loop" 'skill://start-build/reference/parent-orchestrator.md' 'canonical parent orchestrator pointer'
require "$loop" 'reviewed-commit binding' 'reviewed-commit binding'
require "$loop" 'commit-bound CI' 'commit-bound CI'
require "$loop" 'explicit authority provenance' 'authority provenance'
require "$loop" 'independent review' 'independent review'
require "$loop" 'child/reviewer/verifier boundaries' 'role boundaries'
require "$loop" 'provider-native post-read' 'provider readback'

require "$parent" 'child builders do not spawn reviewers, approve, finish' 'child-builder boundary'
require "$parent" 'post-merge verifiers stay read-only' 'post-merge verifier boundary'

if (( failures )); then
  printf 'safety-floor-tokens: FAIL: %d invariant(s) missing\n' "$failures" >&2
  exit 1
fi
printf 'safety-floor-tokens: PASS\n'
