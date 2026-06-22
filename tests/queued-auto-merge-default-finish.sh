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
# Default finish on pass + merge authority is approve-SHA-bound + queue auto-merge.
require_text "$REVIEW_FLOW" 'default finish[^.]*queue auto-merge|queue auto-merge[^.]*default finish' \
  'queued auto-merge is the default finish'
require_text "$REVIEW_FLOW" 'sha-bound-auto-merge-queue' \
  'default finish uses the sha-bound auto-merge queue snippet'
# Exact-SHA CI floor explicitly restated as intact.
require_text "$REVIEW_FLOW" 'floor is intact|floor[^.]*intact' \
  'exact-SHA CI floor restated as intact'
require_text "$REVIEW_FLOW" 'will not complete a queued merge until the reviewed-SHA pipeline succeeds' \
  'queued merge blocked until reviewed-SHA pipeline succeeds'
require_text "$REVIEW_FLOW" 'pipeline must succeed' \
  'protected merge "pipeline must succeed" precondition'
require_text "$REVIEW_FLOW" 'not a CI waiver|never substitutes for the reviewer.s own exact-SHA CI' \
  'queued auto-merge is not a CI waiver'
# Fail-closed guard: failed/canceled reviewed-SHA pipeline is a block, not a queue.
require_text "$REVIEW_FLOW" 'pending./.running./.success|pending/running/success' \
  'queue only on pending/running/success reviewed-SHA pipeline'
require_text "$REVIEW_FLOW" '(failed./.canceled|failed/canceled)[^.]*block|block[^.]*(failed./.canceled|failed/canceled)' \
  'fail-closed: failed/canceled reviewed-SHA pipeline blocks, not queues'
# Precondition: protected auto-merge + known 405 fallback snippet.
require_text "$REVIEW_FLOW" 'protected auto-merge' \
  'protected auto-merge precondition'
require_text "$REVIEW_FLOW" 'auto-merge-api-fallback' \
  '405 path routes through auto-merge-api-fallback snippet'
# approval-only / human release exemption stays explicit.
require_text "$REVIEW_FLOW" 'approval-only[^.]*human release|human release[^.]*approval-only' \
  'approval-only / human release exemption from default finish'

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
