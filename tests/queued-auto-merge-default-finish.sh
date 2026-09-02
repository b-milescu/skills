#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() { printf 'advisory-ci-policy: FAIL: %s\n' "$*" >&2; exit 1; }
require() { grep -Eiq -- "$2" "$1" || fail "$1 missing $3"; }

REVIEW="start-review/REVIEW-FLOW.md"
SAFETY="start-build/SAFETY.md"
PARENT="start-build/reference/parent-orchestrator.md"
RECEIPT="start-build/reference/parent-owned-gate.md"
COMMON="forge/reference/common-guard.md"
GITLAB="gitlab/reference/ci-finish-guards.md"
POST="start-build/reference/post-merge-verifier.md"

require "$SAFETY" 'exact-candidate local Check Gate.*quality gate' 'singular local quality gate'
require "$RECEIPT" 'exact candidate plus a passing parent Gate Receipt is sufficient' 'Gate Receipt sufficiency'
require "$REVIEW" 'Every classification is advisory' 'advisory CI classifications'
require "$REVIEW" 'No provider CI status changes the review' 'red/missing/stale non-blocking policy'
require "$REVIEW" 'Independent review' 'preserved review floor'
require "$REVIEW" 'authority/caller guards' 'preserved authority/caller floor'
require "$REVIEW" 'exactly one mutation' 'preserved one-mutation floor'
require "$COMMON" 'CI status never blocks' 'common guard advisory CI'
require "$PARENT" 'CI state never changes eligibility' 'parent finish advisory CI'
require "$GITLAB" 'provider result and never bypass' 'native protection refusal'
require "$POST" 'post-merge failure' 'post-merge advisory CI'
require "$REVIEW" 'Queued is non-terminal' 'queue is not merged'

retired_modes="Gate coverage.*(hy""brid|ci""-only)"
retired_tokens="CI wa""iver|wait""-ci|stale-or-missing-""ci|no_ci_""expected"
retired_blockers="ci_not_""green|ci_""guard|stale_""ci|red_""ci|missing_""ci"
tracked=(issue-delivery-loop start-build start-review forge gitlab setup-dev-skills retro docs CONTEXT.md)
if grep -R -n -E "$retired_modes|$retired_tokens|$retired_blockers" "${tracked[@]}"; then
  fail "retired CI mode/waiver/action/blocker vocabulary remains in active policy sources"
fi

printf 'advisory-ci-policy: PASS\n'
