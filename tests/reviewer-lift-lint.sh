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
VOCAB="$REPO_ROOT/docs/agents/dev-workflows.md"

CAPTURE_STATUS=0
CAPTURE_OUTPUT=""

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# run_validator <block-text> -> sets CAPTURE_STATUS / CAPTURE_OUTPUT via stdin.
run_validator() {
  set +e
  CAPTURE_OUTPUT="$(printf '%s' "$1" | bash "$VALIDATOR" 2>&1)"
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
[[ -f "$VOCAB" ]] || fail "acceptance-surface vocabulary file missing at $VOCAB"
command -v node >/dev/null 2>&1 || fail "node required to run this test"

# valid_value_for <row> -> a membership-valid value for closed-set rows, else a
# generic non-empty filler. Closed-set rows must carry a valid enum/vocabulary
# value so the "valid block passes" assertions exercise value validation rather
# than tripping over a placeholder.
valid_value_for() {
  case "$1" in
    "Merge authority")      printf 'approval-only' ;;
    "Review gate")          printf 'mandatory' ;;
    "Gate owner")           printf 'parent' ;;
    "Gate coverage")        printf 'full-local' ;;
    "Acceptance surfaces")  printf 'docs:docs-read' ;;
    "Touched safety surfaces") printf 'wire-protocol' ;;
    *)                      printf 'filled-value' ;;
  esac
}

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

[[ "${#REQUIRED_ROWS[@]}" -eq 21 ]] || \
  fail "expected 21 required rows in schema, extracted ${#REQUIRED_ROWS[@]}: ${REQUIRED_ROWS[*]}"

# build_block prints a Lift table containing every required row except an
# optionally named row to omit ($1; empty means omit nothing).
build_block() {
  local omit="${1:-}"
  printf '| Field | Value |\n'
  printf '|---|---|\n'
  local row
  for row in "${REQUIRED_ROWS[@]}"; do
    [[ "$row" == "$omit" ]] && continue
    printf '| %s | %s |\n' "$row" "$(valid_value_for "$row")"
  done
}

# build_block_override prints a full, present Lift block but replaces a single
# named row's value with $2 (used to inject a bad closed-set value).
build_block_override() {
  local target="$1" value="$2"
  printf '| Field | Value |\n'
  printf '|---|---|\n'
  local row
  for row in "${REQUIRED_ROWS[@]}"; do
    if [[ "$row" == "$target" ]]; then
      printf '| %s | %s |\n' "$row" "$value"
    else
      printf '| %s | %s |\n' "$row" "$(valid_value_for "$row")"
    fi
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
file_output="$(bash "$VALIDATOR" "$tmp_input" 2>&1)"
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

# === Closed-set ROW VALUE validation (issue #270). ===
# Membership only: each closed-set row's value must be drawn from its allowed
# set. The acceptance-surface vocabulary is read at runtime from the project
# acceptance_surfaces_ref doc, so it auto-tracks vocabulary additions.

EXPECTED_BAD_STATUS=4

# A block with all-valid enum/vocab values passes (already exercised by
# build_block above, but assert the closed-set variants explicitly).
for v in "approval-only" "reviewer may merge" "queue auto-merge" "human release" "project default: minister approval" "none — requires explicit human/parent instruction"; do
  run_validator "$(build_block_override "Merge authority" "$v")"
  assert_status 0
done
# RF-1 (issue #293): the fail-closed default value
# `none — requires explicit human/parent instruction` is a member of the Merge
# authority closed set. A bare `none` is NOT a member (the value must carry the
# explicit-instruction qualifier so it cannot be confused with a silent grant).
run_validator "$(build_block_override "Merge authority" "none")"
assert_status "$EXPECTED_BAD_STATUS"
assert_contains "Merge authority"
for v in "mandatory" "bypassed (human override)"; do
  run_validator "$(build_block_override "Review gate" "$v")"
  assert_status 0
done
for v in "builder" "parent"; do
  run_validator "$(build_block_override "Gate owner" "$v")"
  assert_status 0
done
# Regression (issue #270 MF-1): the canonical Gate owner enum is {builder, parent}
# per reviewer-lift-schema.md:11. An otherwise-valid Lift whose Gate owner is
# `builder` (the default builder-owned path) MUST pass; the prior {child, parent}
# predicate wrongly failed this schema-correct value closed with exit 4.
run_validator "$(build_block_override "Gate owner" "builder")"
assert_status 0
for v in "full-local" "hybrid" "ci-only"; do
  run_validator "$(build_block_override "Gate coverage" "$v")"
  assert_status 0
done
# Acceptance surfaces: valid vocabulary tokens (single, multi, and `none`),
# each bound to an evidence status.
for v in "docs:docs-read" "prompt:test, transport:ci" "none"; do
  run_validator "$(build_block_override "Acceptance surfaces" "$v")"
  assert_status 0
done

# Values wrapped in a markdown code span (`value`) — as in the generated-copy
# template — are accepted: a surrounding backtick pair is stripped before the
# membership check.
run_validator "$(build_block_override "Merge authority" '`project default: parent owns merge`')"
assert_status 0
run_validator "$(build_block_override "Gate coverage" '`full-local`')"
assert_status 0
run_validator "$(build_block_override "Acceptance surfaces" '`docs:docs-read, prompt:test`')"
assert_status 0
# A backtick-wrapped BAD value still fails closed (no smuggling past the check).
run_validator "$(build_block_override "Gate owner" '`reviewer`')"
assert_status "$EXPECTED_BAD_STATUS"
assert_contains "Gate owner"

# Every surface token currently in the live vocabulary must be accepted, proving
# the helper reads the vocabulary at runtime rather than hardcoding a list.
mapfile -t VOCAB_SURFACES < <(VOCAB="$VOCAB" node -e '
  const fs = require("fs");
  const lines = fs.readFileSync(process.env.VOCAB, "utf8").split(/\r?\n/);
  let state = "";
  const rows = [];
  for (const l of lines) {
    if (/^### Acceptance-surface vocabulary/.test(l)) { state = "pre"; continue; }
    if (state === "pre" && /^\|\s*Surface value\s*\|/.test(l)) { state = "head"; continue; }
    if (state === "head" && /^\|\s*-+\s*\|/.test(l)) { state = "rows"; continue; }
    if (state === "rows") {
      if (/^\|/.test(l)) {
        const cell = l.split("|")[1].trim().replace(/`/g, "");
        if (cell) rows.push(cell);
      } else if (l.trim() === "") { break; }
    }
  }
  process.stdout.write(rows.join("\n"));
')
[[ "${#VOCAB_SURFACES[@]}" -ge 1 ]] || fail "extracted no surface tokens from $VOCAB"
for surface in "${VOCAB_SURFACES[@]}"; do
  run_validator "$(build_block_override "Acceptance surfaces" "${surface}:docs-read")"
  assert_status 0
done

# Negative: for EACH closed-set row, a bad value fails closed naming that row.
run_validator "$(build_block_override "Merge authority" "default-after-pass")"
assert_status "$EXPECTED_BAD_STATUS"
assert_contains "Merge authority"

run_validator "$(build_block_override "Review gate" "optional")"
assert_status "$EXPECTED_BAD_STATUS"
assert_contains "Review gate"

run_validator "$(build_block_override "Gate owner" "reviewer")"
assert_status "$EXPECTED_BAD_STATUS"
assert_contains "Gate owner"

# Regression (issue #270 MF-1, #273): the retired `child` value is not a Lift
# Gate owner value (and after #273 is not the launch-prompt selector either). With
# the enum {builder, parent}, a `child` Gate owner and any other out-of-set value
# must still FAIL CLOSED (exit 4) naming the row.
for bad in "child" "nonsense"; do
  run_validator "$(build_block_override "Gate owner" "$bad")"
  assert_status "$EXPECTED_BAD_STATUS"
  assert_contains "Gate owner"
done

run_validator "$(build_block_override "Gate coverage" "parent-owned")"
assert_status "$EXPECTED_BAD_STATUS"
assert_contains "Gate coverage"

run_validator "$(build_block_override "Acceptance surfaces" "dev-workflow:docs-read")"
assert_status "$EXPECTED_BAD_STATUS"
assert_contains "Acceptance surfaces"

# A bad surface token mixed with a valid one still fails closed naming the row.
run_validator "$(build_block_override "Acceptance surfaces" "docs:docs-read, bogus-surface:test")"
assert_status "$EXPECTED_BAD_STATUS"
assert_contains "Acceptance surfaces"

# === Touched safety surfaces closed-set (issue #283). ===
# `wire-protocol` is a first-class safety-surface value (wire formats, opcode
# encoders/decoders, on-the-wire byte layout). `other` keeps catch-all semantics
# and may carry a free-text parenthetical annotation; multiple comma-separated
# surfaces are allowed; `none` declares no surface.
for v in "wire-protocol" "none" "[]" "other" "state, gates" "wire-protocol, state" \
         "other (wire-protocol encoder bytes: foo, bar)" "deploy, other (notes)"; do
  run_validator "$(build_block_override "Touched safety surfaces" "$v")"
  assert_status 0
done
# Backtick-wrapped value is accepted (matches generated-copy presentation).
run_validator "$(build_block_override "Touched safety surfaces" '`wire-protocol`')"
assert_status 0
# Unknown safety surface fails closed naming the row; `other` catch-all does not
# leak to typos or invented values.
for bad in "wire-protcol" "protocol" "bogus-surface" "state, bogus-surface"; do
  run_validator "$(build_block_override "Touched safety surfaces" "$bad")"
  assert_status "$EXPECTED_BAD_STATUS"
  assert_contains "Touched safety surfaces"
done
# Blank/whitespace value fails closed naming the row (issue #283 MF-1): the only
# empty-equivalents are explicit `none` / `[]`; a present-but-empty required row
# is an invalid value, not a free pass.
for blank in "" "   "; do
  run_validator "$(build_block_override "Touched safety surfaces" "$blank")"
  assert_status "$EXPECTED_BAD_STATUS"
  assert_contains "Touched safety surfaces"
done
# An annotation-only value (no real surface token) also fails closed.
run_validator "$(build_block_override "Touched safety surfaces" "(just a note)")"
assert_status "$EXPECTED_BAD_STATUS"
assert_contains "Touched safety surfaces"

# Presence still wins precedence: a missing required row reports missing_row (3),
# not a value error, so the #265 presence contract is unchanged.
run_validator "$(build_block "Merge authority")"
assert_status 3
assert_contains "Merge authority"

# === Merge-authority source affirmative-grant WARNING (issue #294). ===
# Warn-only, heuristic, layered on top of the closed-set membership check (#270)
# and RF-1 default (#293). When `Merge authority` is a finish-authority-GRANTING
# value (`reviewer may merge`, `queue auto-merge`, or a granting
# `project default: <policy>`) AND the paired `Merge authority source` cell
# carries NO quotable affirmative grant, the linter emits an advisory stderr
# diagnostic naming the offending row and EXITS 0 — it never fails closed and
# never blocks. The three non-granting values must NEVER warn. (Maintainer
# decision recorded on issue #294 note 25512.)

# build_block_override2 prints a full, present Lift block but replaces TWO named
# rows' values, so a granting Merge authority can be paired with a chosen
# Merge authority source.
build_block_override2() {
  local t1="$1" v1="$2" t2="$3" v2="$4"
  printf '| Field | Value |\n'
  printf '|---|---|\n'
  local row
  for row in "${REQUIRED_ROWS[@]}"; do
    if [[ "$row" == "$t1" ]]; then
      printf '| %s | %s |\n' "$row" "$v1"
    elif [[ "$row" == "$t2" ]]; then
      printf '| %s | %s |\n' "$row" "$v2"
    else
      printf '| %s | %s |\n' "$row" "$(valid_value_for "$row")"
    fi
  done
}

WARN_TOKEN="merge_authority_unquoted_grant"

# --- Granting authority + NO quotable affirmative grant in source => WARN + exit 0.
for granting in "reviewer may merge" "queue auto-merge" "project default: reviewer merges on green"; do
  # An empty-equivalent / disclaiming / bare-path source has no quotable grant.
  for weak_source in "none" "n/a" "setup docs do not grant finish authority"; do
    run_validator "$(build_block_override2 "Merge authority" "$granting" "Merge authority source" "$weak_source")"
    assert_status 0
    assert_contains "$WARN_TOKEN"
    assert_contains "Merge authority source"
  done
done

# A backtick-wrapped granting value with a weak source still warns (presentation
# is stripped before the grant check, matching the membership check).
run_validator "$(build_block_override2 "Merge authority" '`queue auto-merge`' "Merge authority source" "none")"
assert_status 0
assert_contains "$WARN_TOKEN"

# --- Granting authority WITH a quotable affirmative grant => NO warn, exit 0.
# A quoted rulebook sentence granting merge, or a recorded human/parent
# instruction, satisfies the heuristic. The advisory token must NOT appear.
for good_source in \
  'rulebook: "the reviewer may merge after a passing review"' \
  'parent task prompt: reviewer may merge on green' \
  'human MR comment https://gitlab.example.com/agents/skills/-/merge_requests/1#note_1' \
  '“queue auto-merge once CI is green”'; do
  run_validator "$(build_block_override2 "Merge authority" "reviewer may merge" "Merge authority source" "$good_source")"
  assert_status 0
  [[ "$CAPTURE_OUTPUT" != *"$WARN_TOKEN"* ]] || \
    fail "granting value WITH affirmative grant must not warn; got: $CAPTURE_OUTPUT"
done

# --- The three NON-GRANTING values must NEVER warn, regardless of source. ---
# Even with an empty/disclaiming source, a non-granting authority is silent.
for nongranting in "none — requires explicit human/parent instruction" "approval-only" "human release"; do
  for src in "none" "setup docs do not grant finish authority" ""; do
    run_validator "$(build_block_override2 "Merge authority" "$nongranting" "Merge authority source" "$src")"
    assert_status 0
    [[ "$CAPTURE_OUTPUT" != *"$WARN_TOKEN"* ]] || \
      fail "non-granting value '$nongranting' must never warn; got: $CAPTURE_OUTPUT"
  done
done

# --- A non-granting `project default: <policy>` (silent on / disclaiming
# merge) must NOT warn: only granting project-default policies are in scope.
run_validator "$(build_block_override2 "Merge authority" "project default: approval-only, human releases" "Merge authority source" "none")"
assert_status 0
[[ "$CAPTURE_OUTPUT" != *"$WARN_TOKEN"* ]] || \
  fail "non-granting project default must not warn; got: $CAPTURE_OUTPUT"

# --- The warning is advisory only: closed-set membership still fails closed
# first. A bad (out-of-set) Merge authority reports invalid_value (4), not warn.
run_validator "$(build_block_override2 "Merge authority" "default-after-pass" "Merge authority source" "none")"
assert_status "$EXPECTED_BAD_STATUS"
assert_contains "Merge authority"

# === No network call: helper must not reference glab/curl/wget. ===
if grep -Eq '(^|[^a-zA-Z_])(glab|curl|wget)([^a-zA-Z_]|$)' "$VALIDATOR"; then
  fail "validator must make no network call (found glab/curl/wget reference)"
fi

echo "reviewer-lift-lint: PASS"
