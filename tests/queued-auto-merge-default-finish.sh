#!/usr/bin/env bash
set -euo pipefail

# Issue #276: default delivery/review finish to queued auto-merge.
#
# Maintainer-decided policy change: on a `pass` verdict with merge authority,
# the default finish is approve-SHA-bound + queue auto-merge (instead of
# block-watch-then-direct-merge), and the parent/reviewer launch review in
# PARALLEL with CI for every tier instead of block-watching the pipeline to
# terminal-green first. The exact-SHA CI gate and the fail-closed guard
# (reviewed-SHA pipeline failed/canceled => block, not queue) MUST survive.
#
# These assertions pin the new default-finish wording and the retirement of the
# trivial-tier CI-wait rule so a silent revert to block-watch-by-default fails
# `npm run check`. They are tokens, not whole sentences.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

REVIEW_FLOW="start-review/REVIEW-FLOW.md"
PARENT="start-build/reference/parent-orchestrator.md"
DELIVERY="issue-delivery-loop/SKILL.md"
VERIFIER="start-build/reference/post-merge-verifier.md"
EFFORT="start-build/docs/effort-scaling.md"
GITLAB_FORGE="forge/reference/gitlab.md"
GITLAB_SKILL="gitlab/SKILL.md"
GITLAB_ACTIONS="gitlab/reference/review-actions.md"
GITLAB_CI_FINISH="gitlab/reference/ci-finish-guards.md"

failures=0

fail() {
  printf 'queued-auto-merge-default-finish: FAIL: %s\n' "$*" >&2
  failures=$((failures + 1))
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

refute_text() {
  local file="$1" pattern="$2" label="$3"
  if grep -Eiq -- "$pattern" "$file"; then
    fail "$file unexpectedly still contains $label"
  fi
}

# ---------------------------------------------------------------------------
# start-review/REVIEW-FLOW.md — canonical default-finish + floor + fail-closed.
# ---------------------------------------------------------------------------
require_text "$REVIEW_FLOW" '^## Default finish: queued auto-merge$' \
  'canonical Default finish section'
# Neutral policy: default finish, exact-reviewed-commit protected queue, intact
# CI floor, fail-closed states, non-terminal queue, capability/authority, and
# parent finish ownership.
require_text "$REVIEW_FLOW" 'default finish[^.]*queue auto-merge|queue auto-merge[^.]*default finish' \
  'queued auto-merge is the default finish'
require_text "$REVIEW_FLOW" 'exact-reviewed-commit protected' \
  'exact-reviewed-commit protected queue'
require_text "$REVIEW_FLOW" 'floor is intact|floor[^.]*intact' \
  'CI floor restated as intact'
require_text "$REVIEW_FLOW" '(failed./.canceled./.missing./.stale|failed/canceled/missing/stale)[^.]*block|block[^.]*(failed./.canceled./.missing./.stale|failed/canceled/missing/stale)' \
  'fail-closed CI blocks'
require_text "$REVIEW_FLOW" 'not a CI waiver' 'queued finish is not a CI waiver'
require_text "$REVIEW_FLOW" 'provider.*capability|provider offers' 'provider capability requirement'
require_text "$REVIEW_FLOW" 'authority' 'finish authority requirement'
require_text "$REVIEW_FLOW" 'queued is non-terminal|queue is non-terminal|never reported as merged' 'queue is not merged'

# GitLab mechanics stay behind the selected provider entry point and its cards.
for card in review-actions ci; do
  require_text "$GITLAB_FORGE" "gitlab/reference/${card}\\.md" "$card provider-card link"
done
require_text "$GITLAB_SKILL" 'sha-bound-auto-merge-queue' 'GitLab SHA-bound queue snippet'
require_text "$GITLAB_SKILL" 'protected auto-merge' 'GitLab protected auto-merge'
require_text "$GITLAB_SKILL" 'auto-merge-api-fallback' 'GitLab fallback snippet'
require_text "$GITLAB_SKILL" 'approval-only' 'GitLab approval-only mapping'
require_text "$GITLAB_SKILL" 'human release' 'GitLab human-release mapping'
require_text "$GITLAB_ACTIONS" 'protected checks' 'GitLab protected-check queue requirement'
require_text "$GITLAB_CI_FINISH" 'exact-SHA green CI for merge' 'GitLab merge CI policy'

# ---------------------------------------------------------------------------
# parent-orchestrator.md — parallel launch default; trivial-tier wait retired.
# ---------------------------------------------------------------------------
require_text "$PARENT" '^## Reviewer launch timing$' \
  'renamed Reviewer launch timing section'
require_text "$PARENT" 'Parallel launch is the default for every tier' \
  'parallel launch default for every tier'
require_text "$PARENT" 'default finish[^.]*queue auto-merge|approve SHA-bound and queue auto-merge' \
  'parent default finish is queued auto-merge'
# The retired block-wait rule must be gone as an ACTIVE instruction: no tier
# should be told to wait for terminal-green CI before launching the reviewer.
refute_text "$PARENT" 'launch the reviewer only once that exact SHA is terminal-green' \
  'retired trivial-tier terminal-green wait instruction'
refute_text "$PARENT" '`trivial`-tier deliveries with non-terminal CI wait for exact-SHA terminal-green CI first' \
  'retired step-5 trivial CI-wait instruction'
# Fail-closed on red/canceled CI survives the retirement.
require_text "$PARENT" '(failed./.canceled|failed/canceled)[^.]*do not finish|do not finish[^.]*(failed./.canceled|failed/canceled)' \
  'fail-closed red/canceled CI guard preserved'

# ---------------------------------------------------------------------------
# issue-delivery-loop/SKILL.md — parallel launch + queued auto-merge default.
# ---------------------------------------------------------------------------
require_text "$DELIVERY" 'in parallel with CI' \
  'delivery loop launches review in parallel with CI'
require_text "$DELIVERY" 'do not block-watch' \
  'delivery loop drops block-watch before reviewer launch'
require_text "$DELIVERY" 'queue auto-merge' \
  'delivery loop default finish queues auto-merge'
require_text "$DELIVERY" '(failed./.canceled|failed/canceled)[^.]*block|block[^.]*(failed./.canceled|failed/canceled)' \
  'delivery loop restates the fail-closed guard'

# #374: queueing is pending, not a terminal delivery result. The delivery loop
# returns to its existing event-driven boundary without a CI/MR watcher, then
# routes an observed merge through the existing handoff and verifier snapshot.
require_text "$DELIVERY" 'Treat `auto-merge queued` as pending' \
  'queued auto-merge remains a pending delivery'
require_text "$DELIVERY" 'does not count as \*\*MRs merged\*\*' \
  'queue action is distinct from merge-event evidence'
require_text "$DELIVERY" 'without polling CI' \
  'queued delivery returns without a CI poller'
require_text "$DELIVERY" 'phase: `post-merge-verify`' \
  'observed merge advances the existing post-merge phase'
require_text "$DELIVERY" 'expected_next_actor: `verifier`' \
  'observed merge routes to the verifier'
require_text "$DELIVERY" 'expected_next_action: `post-merge-verify`' \
  'observed merge routes the existing verifier action'
require_text "$DELIVERY" 'post_merge_snapshot\.kind=post-merge-snapshot' \
  'clean completion requires the verifier snapshot'
require_text "$DELIVERY" 'cannot satisfy clean delivery or batch completion' \
  'queueing alone cannot satisfy completion'
refute_text "$DELIVERY" '`wait-merge-event`' \
  'no new wait-merge-event token'

# ---------------------------------------------------------------------------
# post-merge-verifier.md — triggers off the merge event, not a CI watcher.
# ---------------------------------------------------------------------------
require_text "$VERIFIER" 'Trigger off the[^.]*merge event' \
  'verifier triggers off the merge event'
require_text "$VERIFIER" 'not a CI watcher|not from a foreground/background CI watcher' \
  'verifier does not trigger from a CI watcher'
require_text "$VERIFIER" 'completes asynchronously' \
  'verifier notes queued auto-merge completes asynchronously'

# ---------------------------------------------------------------------------
# effort-scaling.md — reviewer-launch timing is parallel for every tier.
# ---------------------------------------------------------------------------
require_text "$EFFORT" 'parallel with CI for every tier' \
  'effort-scaling reviewer-launch timing parallel for every tier'
refute_text "$EFFORT" 'the `trivial` tier waits for exact-SHA terminal-green CI before launch' \
  'retired effort-scaling trivial-tier wait instruction'

require_text "$REVIEW_FLOW" 'Finish owner: parent'   'parent-managed finish owner exception documented'
require_text "$PARENT" 'Finish owner: parent'   'parent orchestrator finish owner literal'
require_text "$DELIVERY" 'Finish owner: parent'   'delivery loop passes parent finish owner'

if [[ "$failures" -ne 0 ]]; then
  echo "queued-auto-merge-default-finish: FAIL: $failures violation(s)" >&2
  exit 1
fi

echo "queued-auto-merge-default-finish: PASS"
