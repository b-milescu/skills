# Shared command-output capture/assertions for shell regression tests.
# Source from tests after setting REPO_ROOT or from any tests/lib sibling.

_TEST_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=tests/lib/assertions.sh
source "$_TEST_LIB_DIR/assertions.sh"
unset _TEST_LIB_DIR

CAPTURE_STATUS=0
CAPTURE_OUTPUT=""

run_capture() {
  set +e
  CAPTURE_OUTPUT="$({ "$@"; } 2>&1)"
  CAPTURE_STATUS=$?
  set -e
}


assert_status() {
  local expected="$1"
  [[ "$CAPTURE_STATUS" -eq "$expected" ]] || fail "expected status $expected, got $CAPTURE_STATUS; output: $CAPTURE_OUTPUT"
}

assert_capture_contains() {
  local needle="$1" label="${2:-$1}"
  assert_text_contains "$CAPTURE_OUTPUT" "$needle" "$label"
}

assert_capture_not_contains() {
  local needle="$1" label="${2:-$1}"
  assert_text_not_contains "$CAPTURE_OUTPUT" "$needle" "$label"
}
