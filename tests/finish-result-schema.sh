#!/usr/bin/env bash
# Focus: `gitlab/reference/finish-result-schema.json` carries the finish
# result/action/SHA/blocker, optional nullable advisory `ci`, issue state,
# cleanup, authority/caller evidence, transport, conflict, and retry
# vocabulary.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCHEMA="$REPO_ROOT/gitlab/reference/finish-result-schema.json"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -f "$SCHEMA" ]] || fail "schema file missing at $SCHEMA"
command -v node >/dev/null 2>&1 || fail "node required to run this test"

# One Node process validates every required field, enum value, CI rule, and
# example-coverage case below.
node - "$SCHEMA" <<'JS'
const s = require(process.argv[2]);
const fail = (msg) => {
  console.error(`FAIL: ${msg}`);
  process.exit(1);
};

// === Schema artifact: every required field/enum from the issue is present. ===
const schemaAssert = (field, ...values) => {
  const p = (s.properties || {})[field];
  for (const value of values) {
    if (!p || !Array.isArray(p.enum) || !p.enum.map(String).includes(value)) {
      fail(`schema field '${field}' is missing enum value '${value}'`);
    }
  }
};

for (const field of ["result", "action", "transport", "sha", "blocker", "issue_state",
  "worktree_cleanup", "branch_cleanup", "authority_verification_source",
  "caller_user_id_verification_source", "cleanup_verified", "cleanup_failure_reason",
  "override_recorded", "conflict_type", "retry_count"]) {
  if (!(s.required || []).includes(field)) fail(`schema.required is missing ${field}`);
}

schemaAssert("result", "merged", "auto_merge_queued", "handoff", "held", "escalated");
schemaAssert("action", "approve", "merge", "auto_merge", "none");
schemaAssert("transport", "mcp", "glab-fallback", "n/a");
schemaAssert("blocker", "none", "mcp_unavailable", "identity_unavailable", "identity_changed",
  "authority", "head_changed", "not_mergeable", "description_lost", "cleanup_failed");
{
  const ciFail = "CI must be optional nullable advisory evidence with no eligibility guard/blocker";
  const ci = s.properties.ci;
  if (!ci || !Array.isArray(ci.type) || !ci.type.includes("object") || !ci.type.includes("null")) fail(ciFail);
  const retiredGuard = "ci_" + "guard";
  const retiredBlocker = "ci_not_" + "green";
  if (s.required.includes("ci") || s.required.includes(retiredGuard)) fail(ciFail);
  if (retiredGuard in s.properties || s.properties.blocker.enum.includes(retiredBlocker)) fail(ciFail);
}
schemaAssert("issue_state", "closed", "closure_pending", "n/a");
schemaAssert("worktree_cleanup", "done", "pending", "n/a");
schemaAssert("branch_cleanup", "done", "pending", "retained_by_policy");
schemaAssert("authority_verification_source", "description-verified", "description-mismatch",
  "parameter-assumed", "parameter-verified");
schemaAssert("caller_user_id_verification_source", "fresh-call", "cached", "unknown");
schemaAssert("cleanup_verified", "true", "false", "pending");
schemaAssert("cleanup_failure_reason", "none", "dirty_worktree", "git_error", "other");
schemaAssert("conflict_type", "none", "already_merged", "stale_head", "merge_blocked");

const examples = s.examples || [];
if (examples.length < 11) {
  fail(`expected at least 11 schema examples (success + handoff + each non-CI blocker), found ${examples.length}`);
}
const covers = (key, ...values) => {
  const covered = new Set(examples.map((e) => e[key]));
  for (const v of values) if (!covered.has(v)) fail(`examples do not cover ${key}=${v}`);
};
covers("result", "merged", "auto_merge_queued", "handoff", "held", "escalated");
covers("blocker", "none", "mcp_unavailable", "identity_unavailable", "identity_changed",
  "authority", "head_changed", "not_mergeable", "description_lost", "cleanup_failed");
covers("transport", "mcp", "glab-fallback", "n/a");
JS

echo "finish-result-schema: PASS"
