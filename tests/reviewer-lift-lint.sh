#!/usr/bin/env bash
set -euo pipefail

# Regression for gitlab/scripts/validate-reviewer-lift.sh (issue #265).
#
# The helper is a pure-local, no-network presence linter: it parses a Reviewer
# Lift block (the markdown `| Field | Value |` table) from a file or stdin and
# exits 0 only when every required row named in
# start-build/templates/reviewer-lift-schema.md (the `## Required fields` table)
# is present. Any missing required row fails closed.
#
# This test proves:
#   - the required-row list the helper enforces matches the schema EXACTLY
#     (no invented rows, none dropped);
#   - a valid full Lift block passes (stdin and file input);
#   - removing EACH required row, one at a time, fails with a missing-row
#     diagnostic naming that row;
#   - malformed/empty input fails closed;
#   - the helper makes no network call.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
VALIDATOR="$REPO_ROOT/gitlab/scripts/validate-reviewer-lift.sh"
SCHEMA="$REPO_ROOT/start-build/templates/reviewer-lift-schema.md"

CAPTURE_STATUS=0
CAPTURE_OUTPUT=""

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# run_validator <block-text> -> sets CAPTURE_STATUS / CAPTURE_OUTPUT via stdin.
run_validator() {
  set +e
  CAPTURE_OUTPUT="$(printf '%s' "$1" | "$VALIDATOR" 2>&1)"
  CAPTURE_STATUS=$?
  set -e
}

assert_status() {
  local expected="$1"
  [[ "$CAPTURE_STATUS" -eq "$expected" ]] || \
    fail "expected status $expected, got $CAPTURE_STATUS; output: $CAPTURE_OUTPUT"
}

assert_contains() {
  [[ "$CAPTURE_OUTPUT" == *"$1"* ]] || \
    fail "expected output to contain '$1'; got: $CAPTURE_OUTPUT"
}

[[ -f "$VALIDATOR" ]] || fail "validator script missing at $VALIDATOR"
[[ -f "$SCHEMA" ]] || fail "schema file missing at $SCHEMA"
command -v node >/dev/null 2>&1 || fail "node required to run this test"

# === Source of truth: extract the required rows from the schema markdown. ===
# The test derives the expected required-row list straight from the schema so it
# (like the helper) cannot drift to an invented/dropped row.
mapfile -t REQUIRED_ROWS < <(SCHEMA="$SCHEMA" node -e '
  const fs = require("fs");
  const lines = fs.readFileSync(process.env.SCHEMA, "utf8").split(/\r?\n/);
  let state = "";
  const rows = [];
  for (const l of lines) {
    if (/^## Required fields/.test(l)) { state = "pre"; continue; }
    if (state === "pre" && /^\|\s*Field\s*\|/.test(l)) { state = "head"; continue; }
    if (state === "head" && /^\|\s*-+\s*\|/.test(l)) { state = "rows"; continue; }
    if (state === "rows") {
      if (/^\|/.test(l)) {
        const field = l.split("|")[1].trim();
        if (field) rows.push(field);
      } else if (l.trim() === "") { break; }
    }
  }
  process.stdout.write(rows.join("\n"));
')

[[ "${#REQUIRED_ROWS[@]}" -eq 20 ]] || \
  fail "expected 20 required rows in schema, extracted ${#REQUIRED_ROWS[@]}: ${REQUIRED_ROWS[*]}"

# build_block prints a Lift table containing every required row except an
# optionally named row to omit ($1; empty means omit nothing).
build_block() {
  local omit="${1:-}"
  printf '| Field | Value |\n'
  printf '|---|---|\n'
  local row
  for row in "${REQUIRED_ROWS[@]}"; do
    [[ "$row" == "$omit" ]] && continue
    printf '| %s | filled-value |\n' "$row"
  done
}

# === A valid, full Lift block passes (stdin). ===
FULL_BLOCK="$(build_block "")"
run_validator "$FULL_BLOCK"
assert_status 0

# === A valid, full Lift block passes (file input). ===
tmp_input="$(mktemp)"
trap 'rm -f "$tmp_input"' EXIT
printf '%s' "$FULL_BLOCK" > "$tmp_input"
set +e
file_output="$("$VALIDATOR" "$tmp_input" 2>&1)"
file_status=$?
set -e
[[ "$file_status" -eq 0 ]] || fail "file-input validation should pass; status=$file_status output=$file_output"

# === A full block embedded between surrounding prose / markers still passes. ===
EMBEDDED="$(printf '## Reviewer Lift\n\nsome prose\n\n%s\n\n## Summary\nmore prose\n' "$FULL_BLOCK")"
run_validator "$EMBEDDED"
assert_status 0

# === Negative: removing EACH required row, one at a time, fails closed. ===
for row in "${REQUIRED_ROWS[@]}"; do
  block="$(build_block "$row")"
  run_validator "$block"
  assert_status 3
  assert_contains "$row"
done

# === Negative: an empty block (no rows at all) fails closed. ===
run_validator ''
[[ "$CAPTURE_STATUS" -ne 0 ]] || fail "empty input should fail closed"

run_validator 'no table here, just prose'
[[ "$CAPTURE_STATUS" -ne 0 ]] || fail "input with no Lift table should fail closed"

# === No network call: helper must not reference glab/curl/wget. ===
if grep -Eq '(^|[^a-zA-Z_])(glab|curl|wget)([^a-zA-Z_]|$)' "$VALIDATOR"; then
  fail "validator must make no network call (found glab/curl/wget reference)"
fi

echo "reviewer-lift-lint: PASS"
