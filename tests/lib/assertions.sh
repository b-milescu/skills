# Shared shell assertion primitives for repo regression tests.
# Source from tests; do not execute directly.

: "${TEST_NAME:=${0##*/}}"

fail() {
  printf '%s: FAIL: %s\n' "$TEST_NAME" "$*" >&2
  exit 1
}

assert_equals() {
  local expected="$1" actual="$2" label="${3:-value}"
  [[ "$actual" == "$expected" ]] || fail "expected $label '$expected', got '$actual'"
}

assert_path_readable() {
  local path="$1" label="${2:-readable path}"
  [[ -r "$path" ]] || fail "expected $label: $path"
}

assert_path_absent() {
  local path="$1" label="${2:-absent path}"
  [[ ! -e "$path" && ! -L "$path" ]] || fail "unexpected $label: $path"
}

assert_not_empty_file() {
  local file="$1" label="${2:-file}"
  [[ -s "$file" ]] || fail "$label is empty: $file"
}

assert_text_contains() {
  local haystack="$1" needle="$2" label="${3:-$2}"
  [[ "$haystack" == *"$needle"* ]] || fail "missing $label: $needle"
}

assert_text_not_contains() {
  local haystack="$1" needle="$2" label="${3:-$2}"
  [[ "$haystack" != *"$needle"* ]] || fail "unexpected $label: $needle"
}

assert_contains() {
  assert_text_contains "$@"
}

assert_not_contains() {
  assert_text_not_contains "$@"
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

require_text_case_sensitive() {
  local file="$1" pattern="$2" label="$3"
  grep -Eq -- "$pattern" "$file" || fail "$file missing $label"
}

reject_text() {
  local file="$1" pattern="$2" label="$3"
  if grep -Eni -- "$pattern" "$file" >&2; then
    fail "$file contains $label"
  fi
}

require_exact_line() {
  local file="$1" line="$2" label="${3:-$2}"
  grep -Fxq -- "$line" "$file" || fail "$file missing $label"
}

assert_file_contains() {
  local file="$1" needle="$2" label="${3:-$2}"
  [[ -f "$file" ]] || fail "missing file for $label: $file"
  grep -Fq -- "$needle" "$file" || fail "$file missing $label: $needle"
}

assert_file_not_contains() {
  local file="$1" needle="$2" label="${3:-$2}"
  [[ ! -f "$file" ]] || return 0
  if grep -Fq -- "$needle" "$file"; then
    fail "$file contains unexpected $label: $needle"
  fi
}

assert_log_contains() {
  assert_file_contains "$@"
}

assert_log_not_contains() {
  assert_file_not_contains "$@"
}
