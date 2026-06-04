#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
VALIDATOR="$REPO_ROOT/gitlab-local/scripts/validate-finish-result.sh"
SCHEMA="$REPO_ROOT/gitlab-local/reference/finish-result-schema.json"

CAPTURE_STATUS=0
CAPTURE_OUTPUT=""

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# run_validator <json> -> sets CAPTURE_STATUS / CAPTURE_OUTPUT, input via stdin.
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

# === Schema artifact: every required field/enum from the issue is present. ===
# Read the schema and assert each enumerated field carries every issue value, so
# the schema cannot silently drop e.g. identity_changed or cleanup_failed.
schema_assert() {
  # schema_assert <field> <value1> [value2 ...]: each value must be in the field enum.
  local field="$1"; shift
  local value
  for value in "$@"; do
    SCHEMA_PATH="$SCHEMA" FIELD="$field" VALUE="$value" node -e '
      const s = require(process.env.SCHEMA_PATH);
      const p = (s.properties || {})[process.env.FIELD];
      if (!p || !Array.isArray(p.enum)) { process.exit(2); }
      process.exit(p.enum.map(String).includes(process.env.VALUE) ? 0 : 1);
    ' || fail "schema field '$field' is missing enum value '$value'"
  done
}

# required fields present in schema.required
for required_field in result action sha blocker ci_guard issue_state \
  worktree_cleanup branch_cleanup authority_verification_source \
  caller_user_id_verification_source cleanup_verified cleanup_failure_reason \
  override_recorded conflict_type retry_count; do
  SCHEMA_PATH="$SCHEMA" FIELD="$required_field" node -e '
    const s = require(process.env.SCHEMA_PATH);
    const req = Array.isArray(s.required) ? s.required : [];
    process.exit(req.includes(process.env.FIELD) ? 0 : 1);
  ' || fail "schema.required is missing '$required_field'"
done

schema_assert result merged auto_merge_queued handoff held escalated
schema_assert action approve merge auto_merge none
schema_assert blocker none mcp_unavailable identity_unavailable identity_changed \
  authority head_changed ci_not_green not_mergeable description_lost cleanup_failed
schema_assert ci_guard green pending stale missing
schema_assert issue_state closed closure_pending n/a
schema_assert worktree_cleanup done pending n/a
schema_assert branch_cleanup done pending retained_by_policy
schema_assert authority_verification_source description-verified description-mismatch \
  parameter-assumed parameter-verified
schema_assert caller_user_id_verification_source fresh-call cached unknown
schema_assert cleanup_verified true false pending
schema_assert cleanup_failure_reason none dirty_worktree git_error other
schema_assert conflict_type none already_merged stale_head merge_blocked

# === Every embedded example validates (covers merged, auto_merge_queued, ===
# === handoff, and each held/escalated blocker example). ===
example_count="$(SCHEMA_PATH="$SCHEMA" node -e '
  const s = require(process.env.SCHEMA_PATH);
  process.stdout.write(String((s.examples || []).length));
')"
[[ "$example_count" -ge 12 ]] || \
  fail "expected at least 12 schema examples (success + handoff + each blocker), found $example_count"

# Drive the validator with each example object (minus the _label helper key).
for ((i = 0; i < example_count; i++)); do
  label="$(SCHEMA_PATH="$SCHEMA" IDX="$i" node -e '
    const s = require(process.env.SCHEMA_PATH);
    process.stdout.write(String(s.examples[Number(process.env.IDX)]._label || ("example#" + process.env.IDX)));
  ')"
  example_json="$(SCHEMA_PATH="$SCHEMA" IDX="$i" node -e '
    const s = require(process.env.SCHEMA_PATH);
    const { _label, ...rest } = s.examples[Number(process.env.IDX)];
    process.stdout.write(JSON.stringify(rest));
  ')"
  run_validator "$example_json"
  assert_status 0 || fail "example '$label' should validate"
done

# Assert the examples actually cover every result value and every blocker value.
covered_results="$(SCHEMA_PATH="$SCHEMA" node -e '
  const s = require(process.env.SCHEMA_PATH);
  process.stdout.write([...new Set(s.examples.map((e) => e.result))].sort().join(","));
')"
for r in merged auto_merge_queued handoff held escalated; do
  [[ ",$covered_results," == *",$r,"* ]] || fail "examples do not cover result=$r"
done
covered_blockers="$(SCHEMA_PATH="$SCHEMA" node -e '
  const s = require(process.env.SCHEMA_PATH);
  process.stdout.write([...new Set(s.examples.map((e) => e.blocker))].sort().join(","));
')"
for b in none mcp_unavailable identity_unavailable identity_changed authority \
  head_changed ci_not_green not_mergeable description_lost cleanup_failed; do
  [[ ",$covered_blockers," == *",$b,"* ]] || fail "examples do not cover blocker=$b"
done

# === A minimal, fully valid object validates from stdin and from a file. ===
VALID='{"result":"merged","action":"merge","sha":"0123456789abcdef0123456789abcdef01234567","blocker":"none","ci_guard":"green","issue_state":"closed","worktree_cleanup":"done","branch_cleanup":"done","authority_verification_source":"description-verified","caller_user_id_verification_source":"fresh-call","cleanup_verified":true,"cleanup_failure_reason":"none","override_recorded":false,"conflict_type":"none","retry_count":0}'
run_validator "$VALID"
assert_status 0

tmp_input="$(mktemp)"
trap 'rm -f "$tmp_input"' EXIT
printf '%s' "$VALID" > "$tmp_input"
set +e
file_output="$("$VALIDATOR" "$tmp_input" 2>&1)"
file_status=$?
set -e
[[ "$file_status" -eq 0 ]] || fail "file-input validation should pass; status=$file_status output=$file_output"

# === Negative: malformed JSON fails (exit 5, reason=bad_json). ===
run_validator '{not valid json'
assert_status 5
assert_contains "reason=bad_json"

run_validator ''
assert_status 5
assert_contains "reason=bad_json"

# A JSON array is valid JSON but not a finish_result object.
run_validator '[]'
assert_status 5
assert_contains "reason=bad_json"

# === Negative: bad enum value on each enumerated field fails (exit 3). ===
bad_enum_case() {
  # bad_enum_case <field> <bad-value-json-fragment>
  local field="$1" badval="$2"
  local json
  json="$(VALID="$VALID" FIELD="$field" BAD="$badval" node -e '
    const o = JSON.parse(process.env.VALID);
    o[process.env.FIELD] = JSON.parse(process.env.BAD);
    process.stdout.write(JSON.stringify(o));
  ')"
  run_validator "$json"
  assert_status 3
  assert_contains "field=$field"
}

bad_enum_case result '"bogus"'
bad_enum_case action '"delete"'
bad_enum_case blocker '"identity_gone"'
bad_enum_case ci_guard '"red"'
bad_enum_case issue_state '"open"'
bad_enum_case worktree_cleanup '"skipped"'
bad_enum_case branch_cleanup '"deleted"'
bad_enum_case authority_verification_source '"guessed"'
bad_enum_case caller_user_id_verification_source '"stale"'
bad_enum_case cleanup_failure_reason '"network"'
bad_enum_case conflict_type '"rebase"'

# === Negative: missing required field fails (exit 3, reason=missing_field). ===
missing_json="$(VALID="$VALID" node -e '
  const o = JSON.parse(process.env.VALID);
  delete o.blocker;
  process.stdout.write(JSON.stringify(o));
')"
run_validator "$missing_json"
assert_status 3
assert_contains "reason=missing_field"
assert_contains "field=blocker"

# === Negative: unknown extra field fails (additionalProperties=false). ===
extra_json="$(VALID="$VALID" node -e '
  const o = JSON.parse(process.env.VALID);
  o.surprise = "x";
  process.stdout.write(JSON.stringify(o));
')"
run_validator "$extra_json"
assert_status 3
assert_contains "reason=unknown_field"

# === Negative: wrong type on retry_count (string, not integer) fails. ===
type_json="$(VALID="$VALID" node -e '
  const o = JSON.parse(process.env.VALID);
  o.retry_count = "1";
  process.stdout.write(JSON.stringify(o));
')"
run_validator "$type_json"
assert_status 3
assert_contains "field=retry_count"

# negative retry_count violates minimum.
neg_json="$(VALID="$VALID" node -e '
  const o = JSON.parse(process.env.VALID);
  o.retry_count = -1;
  process.stdout.write(JSON.stringify(o));
')"
run_validator "$neg_json"
assert_status 3
assert_contains "field=retry_count"

# === Negative: malformed sha pattern fails. ===
sha_json="$(VALID="$VALID" node -e '
  const o = JSON.parse(process.env.VALID);
  o.sha = "nothex";
  process.stdout.write(JSON.stringify(o));
')"
run_validator "$sha_json"
assert_status 3
assert_contains "field=sha"

# === No network call: validator must not reference glab/curl/wget/git. ===
if grep -Eq '(^|[^a-zA-Z_])(glab|curl|wget)([^a-zA-Z_]|$)' "$VALIDATOR"; then
  fail "validator must make no network call (found glab/curl/wget reference)"
fi

echo "finish-result-schema: PASS"
