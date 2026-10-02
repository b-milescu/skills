#!/usr/bin/env bash
# Focus: Shared regression harness self-check for shell assertion primitives and
# command-output capture.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

TEST_NAME="regression-harness"
TEST_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/regression-harness.XXXXXX")"
trap 'rm -rf "$TEST_TMPDIR"' EXIT

# shellcheck source=tests/lib/command-capture.sh
source "$REPO_ROOT/tests/lib/command-capture.sh"

fixture_doc="$TEST_TMPDIR/fixture.md"
cat > "$fixture_doc" <<'MARKDOWN'
# Fixture

Alpha invariant line.
MARKDOWN

require_text "$fixture_doc" 'alpha invariant' 'case-insensitive text assertion'
reject_text "$fixture_doc" 'missing invariant' 'unexpected text assertion'
assert_text_contains 'command output: ok' 'output: ok' 'literal output assertion'
assert_text_not_contains 'command output: ok' 'secret-token' 'negative output assertion'

run_capture bash -c 'printf "captured output"; exit 7'
assert_status 7
assert_capture_contains 'captured output'
assert_capture_not_contains 'not captured'

echo "regression-harness: PASS"
