#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
GUARD="$REPO_ROOT/gitlab/scripts/gitlab-content-guard.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

CAPTURE_STATUS=0
CAPTURE_OUTPUT=""

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# run_guard_stdin <input-file> [extra-args...] — feed the file body on stdin, capture status+output.
run_guard_stdin() {
  local body="$1"; shift
  set +e
  CAPTURE_OUTPUT="$("$GUARD" "$@" < "$body" 2>&1)"
  CAPTURE_STATUS=$?
  set -e
}

# run_guard_file <body-file> [extra-args...] — pass body via --file, capture status+output.
run_guard_file() {
  local body="$1"; shift
  set +e
  CAPTURE_OUTPUT="$("$GUARD" --file "$body" "$@" 2>&1)"
  CAPTURE_STATUS=$?
  set -e
}

assert_status() {
  local expected="$1"
  [[ "$CAPTURE_STATUS" -eq "$expected" ]] || \
    fail "expected status $expected, got $CAPTURE_STATUS; output: $CAPTURE_OUTPUT"
}

assert_contains() {
  [[ "$CAPTURE_OUTPUT" == *"$1"* ]] || fail "expected output to contain '$1'; got: $CAPTURE_OUTPUT"
}

assert_not_contains() {
  [[ "$CAPTURE_OUTPUT" != *"$1"* ]] || fail "expected output NOT to contain '$1'; got: $CAPTURE_OUTPUT"
}

# === Reject case: a crafted body with a NUL byte ===
# The body carries a recognizable secret-like marker around the NUL so we can
# prove the diagnostics never echo the body back.
nul_body="$TMPDIR/nul-body.md"
printf 'safe prefix LEAK_MARKER_SECRET=topsecret\000more text\n' > "$nul_body"

run_guard_stdin "$nul_body" --role mcp_body
[[ "$CAPTURE_STATUS" -ne 0 ]] || fail "NUL body must exit non-zero, got 0; output: $CAPTURE_OUTPUT"
# MCP-body-style diagnostics must name the failing role + byte offset.
assert_contains "invalid_control_character:mcp_body:byte_"
# Diagnostics must NEVER print the body.
assert_not_contains "LEAK_MARKER_SECRET"
assert_not_contains "topsecret"
assert_not_contains "more text"

# Same reject case via --file: still non-zero, still no body leak.
run_guard_file "$nul_body" --role file_backed_body
[[ "$CAPTURE_STATUS" -ne 0 ]] || fail "NUL body via --file must exit non-zero; output: $CAPTURE_OUTPUT"
assert_contains "invalid_control_character:file_backed_body:byte_"
assert_not_contains "LEAK_MARKER_SECRET"
assert_not_contains "topsecret"

# === Reject case: a non-whitespace C0 control (e.g. BEL 0x07) ===
bel_body="$TMPDIR/bel-body.md"
printf 'before\007after\n' > "$bel_body"
run_guard_stdin "$bel_body"
[[ "$CAPTURE_STATUS" -ne 0 ]] || fail "BEL (C0) body must exit non-zero; output: $CAPTURE_OUTPUT"
assert_contains "byte"

# === Reject case: DEL (0x7f) ===
del_body="$TMPDIR/del-body.md"
printf 'before\177after\n' > "$del_body"
run_guard_stdin "$del_body"
[[ "$CAPTURE_STATUS" -ne 0 ]] || fail "DEL body must exit non-zero; output: $CAPTURE_OUTPUT"

# === Accept case: clean Markdown body with backticks, $vars, tabs, newlines, CR ===
clean_body="$TMPDIR/clean-body.md"
printf '# Review Packet\n\n- `echo "$EXAMPLE_VAR"` stays literal.\ttabbed cell\r\nMultiple lines are fine.\n' > "$clean_body"

run_guard_stdin "$clean_body"
assert_status 0

run_guard_file "$clean_body"
assert_status 0

# === No network call: the guard must not reference glab/curl/wget ===
if grep -Eq '(^|[^a-zA-Z_])(glab|curl|wget)([^a-zA-Z_]|$)' "$GUARD"; then
  fail "guard script must make no network call (found glab/curl/wget reference)"
fi

echo "gitlab-content-guard: PASS"
