#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCHEMA="$REPO_ROOT/gitlab/reference/finish-result-schema.json"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -f "$SCHEMA" ]] || fail "schema file missing at $SCHEMA"
command -v node >/dev/null 2>&1 || fail "node required to run this test"

# === Schema artifact: every required field/enum from the issue is present. ===
schema_assert() {
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

for required_field in result action transport sha blocker issue_state \
  worktree_cleanup branch_cleanup authority_verification_source \
  caller_user_id_verification_source cleanup_verified cleanup_failure_reason \
  override_recorded conflict_type retry_count; do
  SCHEMA_PATH="$SCHEMA" FIELD="$required_field" node -e '
    const s = require(process.env.SCHEMA_PATH);
    process.exit((s.required || []).includes(process.env.FIELD) ? 0 : 1);
  ' || fail "schema.required is missing $required_field"
done

schema_assert result merged auto_merge_queued handoff held escalated
schema_assert action approve merge auto_merge none
schema_assert transport mcp glab-fallback n/a
schema_assert blocker none mcp_unavailable identity_unavailable identity_changed \
  authority head_changed not_mergeable description_lost cleanup_failed
SCHEMA_PATH="$SCHEMA" node -e '
  const s = require(process.env.SCHEMA_PATH);
  const ci = s.properties.ci;
  if (!ci || !Array.isArray(ci.type) || !ci.type.includes("object") || !ci.type.includes("null")) process.exit(1);
  const retiredGuard = "ci_" + "guard";
  const retiredBlocker = "ci_not_" + "green";
  if (s.required.includes("ci") || s.required.includes(retiredGuard)) process.exit(2);
  if (retiredGuard in s.properties || s.properties.blocker.enum.includes(retiredBlocker)) process.exit(3);
' || fail "CI must be optional nullable advisory evidence with no eligibility guard/blocker"
schema_assert issue_state closed closure_pending n/a
schema_assert worktree_cleanup done pending n/a
schema_assert branch_cleanup done pending retained_by_policy
schema_assert authority_verification_source description-verified description-mismatch \
  parameter-assumed parameter-verified
schema_assert caller_user_id_verification_source fresh-call cached unknown
schema_assert cleanup_verified true false pending
schema_assert cleanup_failure_reason none dirty_worktree git_error other
schema_assert conflict_type none already_merged stale_head merge_blocked

example_count="$(SCHEMA_PATH="$SCHEMA" node -e '
  const s = require(process.env.SCHEMA_PATH);
  process.stdout.write(String((s.examples || []).length));
')"
[[ "$example_count" -ge 11 ]] || \
  fail "expected at least 11 schema examples (success + handoff + each non-CI blocker), found $example_count"

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
  head_changed not_mergeable description_lost cleanup_failed; do
  [[ ",$covered_blockers," == *",$b,"* ]] || fail "examples do not cover blocker=$b"
done
covered_transports="$(SCHEMA_PATH="$SCHEMA" node -e '
  const s = require(process.env.SCHEMA_PATH);
  process.stdout.write([...new Set(s.examples.map((e) => e.transport))].sort().join(","));
')"
for t in mcp glab-fallback n/a; do
  [[ ",$covered_transports," == *",$t,"* ]] || fail "examples do not cover transport=$t"
done

echo "finish-result-schema: PASS"
