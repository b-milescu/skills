#!/usr/bin/env bash
set -euo pipefail

# Invariant guard for the structural maintainability sweep in
# start-review/REVIEW-FLOW.md.
#
# Pins POLICY SHAPE, not a frozen number: the sweep section exists, is
# diff-first / blast-radius-bounded, asserts the file-growth threshold as a
# `<1000` -> `>1000` SHAPE paired with its escape-hatch ("compelling
# decomposition rationale"), and keeps the MF-N (block) / C-N (non-blocking)
# decision rule. The bare literal `1000` is intentionally NOT asserted as
# immutable; the threshold token only appears coupled to the exception so the
# test documents policy shape, not a frozen value.
#
# The adjacent "## Review tone" section (#140) may sit next to this section;
# assertions are by SECTION CONTENT, never by section order.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
REVIEW_FLOW_FILE="$REPO_ROOT/start-review/REVIEW-FLOW.md"

fail() {
  printf 'review-structural-sweep: FAIL: %s\n' "$*" >&2
  exit 1
}

require_contains() {
  local needle="$1"
  grep -Fq -- "$needle" "$REVIEW_FLOW_FILE" || fail "missing expected token: $needle"
}

[[ -f "$REVIEW_FLOW_FILE" ]] || fail "missing required file: start-review/REVIEW-FLOW.md"

# The sweep section exists and keeps its bounded, diff-first stance (not a
# whole-repo audit).
require_contains '## Structural maintainability sweep'
require_contains 'diff-first'
require_contains 'blast-radius-bounded'

# Threshold SHAPE: the file-growth smell is expressed as `<1000` -> `>1000`, not
# a bare immutable number. Assert both bracketed bounds so the shape is pinned.
require_contains '`<1000`'
require_contains '`>1000`'

# Escape hatch: the threshold is presumptive, defeasible by a compelling
# decomposition rationale. Assert threshold + exception together so the test
# documents policy shape rather than a frozen `1000`.
require_contains 'presumptive Must Fix'
require_contains 'compelling decomposition rationale'

# Decision rule keeps the MF-N (block) vs C-N (non-blocking) split.
require_contains 'Decision rule:'
require_contains 'block as `MF-N`'
require_contains 'Use `C-N`'

# A representative smell from the taxonomy stays present (sweep is not empty).
require_contains 'Code-judo simplification'

# Threshold-shape coupling guard: the bracketed lower bound `<1000` must never
# appear without the escape-hatch clause in the same file. This is what stops the
# threshold from ossifying into a frozen number with no exception.
if grep -Fq -- '`<1000`' "$REVIEW_FLOW_FILE" \
  && ! grep -Fq -- 'compelling decomposition rationale' "$REVIEW_FLOW_FILE"; then
  fail "file-growth threshold present without its 'compelling decomposition rationale' exception"
fi

printf 'review-structural-sweep: PASS\n'
