#!/usr/bin/env bash
set -euo pipefail

# Regression for gitlab/scripts/validate-closes-keyword.sh (issue #295).
#
# The helper is a pure-local, no-network shape linter for the GitLab auto-close
# keyword in an MR description. It reads an MR description from a file or stdin
# plus a target issue iid, and exits 0 only when the description contains at
# least one plain `Closes #<iid>` reference that GitLab's default closing pattern
# would actually match — i.e. a closing keyword + `#<iid>` that is NOT inside an
# inline code span or a fenced code block, and is NOT present only in a
# bolded/wrapped form.
#
# Root cause this guards (issue #293 recurrence, RF-1): documentation-only
# guidance asking builders to write a plain `Closes #N` did not prevent
# `**Closes:** #N` (bolded) and `` `Closes #N` `` (inline code span) recurrences,
# which GitLab does not auto-close. The closing-pattern rationale (the *why*)
# lives in start-build/templates/review-packet.md (#293); this helper enforces it.
#
# This test proves the issue #295 acceptance criteria:
#   - plain `Closes #N`                                   -> pass (exit 0)
#   - `**Closes:** #N` only (bolded)                      -> fail closed
#   - backtick-wrapped `` `Closes #N` `` only (code span) -> fail closed
#   - missing entirely                                    -> fail closed
#   - plain reference co-existing with unrelated prose
#     backticks elsewhere                                 -> pass (exit 0)
#   plus: file and stdin input, the full default closing-keyword set,
#   case-insensitivity, fenced-code-block exclusion, wrong-iid non-match,
#   usage errors, and the no-network invariant.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
VALIDATOR="$REPO_ROOT/gitlab/scripts/validate-closes-keyword.sh"

CAPTURE_STATUS=0
CAPTURE_OUTPUT=""

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# run_validator <iid> <description-text> -> sets CAPTURE_STATUS/CAPTURE_OUTPUT
# feeding the description on stdin.
run_validator() {
  set +e
 CAPTURE_OUTPUT="$(printf '%s' "$2" | bash "$VALIDATOR" --issue-iid "$1" 2>&1)"
  CAPTURE_STATUS=$?
  set -e
}

assert_status() {
  local expected="$1"
  [[ "$CAPTURE_STATUS" -eq "$expected" ]] || \
    fail "expected status $expected, got $CAPTURE_STATUS; output: $CAPTURE_OUTPUT"
}

assert_pass() { [[ "$CAPTURE_STATUS" -eq 0 ]] || fail "expected pass (0), got $CAPTURE_STATUS; output: $CAPTURE_OUTPUT"; }
assert_fail() { [[ "$CAPTURE_STATUS" -ne 0 ]] || fail "expected fail (non-zero); output: $CAPTURE_OUTPUT"; }

assert_contains() {
  [[ "$CAPTURE_OUTPUT" == *"$1"* ]] || \
    fail "expected output to contain '$1'; got: $CAPTURE_OUTPUT"
}

[[ -f "$VALIDATOR" ]] || fail "validator script missing at $VALIDATOR"

# === AC: plain `Closes #N` passes (stdin). ===
run_validator 295 $'Implements the validator.\n\nCloses #295\n'
assert_pass

# === AC: plain `Closes #N` passes (file input). ===
tmp_input="$(mktemp)"
trap 'rm -f "$tmp_input"' EXIT
printf '%s' $'Some prose.\n\nCloses #295\n' > "$tmp_input"
set +e
file_output="$(bash "$VALIDATOR" --issue-iid 295 "$tmp_input" 2>&1)"
file_status=$?
set -e
[[ "$file_status" -eq 0 ]] || fail "file-input validation should pass; status=$file_status output=$file_output"

# === AC: `**Closes:** #N` only (bolded) fails closed. ===
run_validator 295 $'Summary.\n\n**Closes:** #295\n'
assert_fail
assert_contains "295"

# A bolded keyword without the colon (`**Closes** #295`) also must not count: the
# bold markers wrap the keyword so the plain-keyword regex does not match.
run_validator 295 $'Summary.\n\n**Closes** #295\n'
assert_fail

# === AC: backtick-wrapped `` `Closes #N` `` only (inline code span) fails. ===
run_validator 295 $'Summary.\n\n`Closes #295`\n'
assert_fail
assert_contains "295"

# A keyword where only part is inside the code span still must not count, e.g.
# the whole reference wrapped: `Closes #295` is a single inline span.
run_validator 295 $'See `Closes #295` in the prose, nowhere else plain.\n'
assert_fail

# === AC: missing entirely fails closed. ===
run_validator 295 $'This MR does not reference the closing issue at all.\n'
assert_fail
assert_contains "295"

# === AC: a plain reference co-existing with unrelated prose backticks passes. ===
run_validator 295 $'Refactors the `parseFoo()` helper and updates `config.yaml`.\n\nCloses #295\n'
assert_pass

# A fenced code block elsewhere (containing its own backticks/words) does not
# defeat a plain reference outside the fence.
run_validator 295 $'Closes #295\n\n```bash\necho "Closes #999 inside a fence does not count"\n```\n'
assert_pass

# === A `Closes #N` that exists ONLY inside a fenced code block fails closed. ===
run_validator 295 $'Here is an example:\n\n```\nCloses #295\n```\n'
assert_fail

# === The full default closing-keyword set is accepted (case-insensitive). ===
for kw in Close Closes Closed Closing \
          Fix Fixes Fixed Fixing \
          Resolve Resolves Resolved Resolving \
          Implement Implements Implemented Implementing; do
  run_validator 295 "$kw #295"
  assert_pass
  # lower-case form
  lower="$(printf '%s' "$kw" | tr '[:upper:]' '[:lower:]')"
  run_validator 295 "$lower #295"
  assert_pass
  # UPPER-case form
  upper="$(printf '%s' "$kw" | tr '[:lower:]' '[:upper:]')"
  run_validator 295 "$upper #295"
  assert_pass
done

# A non-closing keyword (e.g. `See`, `Refs`, `Related to`) must NOT count.
for nonkw in "See #295" "Refs #295" "Related to #295" "Part of #295" "#295"; do
  run_validator 295 "$nonkw"
  assert_fail
done

# === The reference must match the TARGET iid, not just any iid. ===
run_validator 295 $'Closes #294\n'
assert_fail
run_validator 295 $'Closes #2950\n'   # #2950 must not satisfy #295 (no substring match)
assert_fail
run_validator 295 $'Closes #295\n'
assert_pass

# A description closing a DIFFERENT issue plus the target one passes for the target.
run_validator 295 $'Closes #294\nCloses #295\n'
assert_pass
# ...and fails for an iid that is referenced only in bolded form.
run_validator 294 $'Closes #295\n**Closes:** #294\n'
assert_fail

# === Usage / argument errors fail closed (not a silent pass). ===
set +e
bash "$VALIDATOR" </dev/null >/dev/null 2>&1   # no --issue-iid
[[ $? -ne 0 ]] || fail "missing --issue-iid should fail closed"
bash "$VALIDATOR" --issue-iid notanumber </dev/null >/dev/null 2>&1
[[ $? -ne 0 ]] || fail "non-numeric --issue-iid should fail closed"
bash "$VALIDATOR" --issue-iid 295 /no/such/file >/dev/null 2>&1
[[ $? -ne 0 ]] || fail "unreadable input file should fail closed"
set -e

# === No network call: helper must not reference glab/curl/wget. ===
if grep -Eq '(^|[^a-zA-Z_])(glab|curl|wget)([^a-zA-Z_]|$)' "$VALIDATOR"; then
  fail "validator must make no network call (found glab/curl/wget reference)"
fi

echo "closes-keyword-lint: PASS"
