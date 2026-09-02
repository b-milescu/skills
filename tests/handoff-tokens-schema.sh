#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

node --input-type=module <<'NODE'
import fs from "node:fs";

const schemaPath = "start-review/reference/handoff-tokens.schema.json";
const mutationGuardPath = "gitlab/reference/mutation-guard.schema.json";
const finishResultPath = "gitlab/reference/finish-result-schema.json";

function fail(message) {
  console.error(`handoff-tokens-schema: FAIL: ${message}`);
  process.exit(1);
}
function assert(condition, message) {
  if (!condition) fail(message);
}
function sameList(label, actual, expected) {
  assert(Array.isArray(actual), `${label} must be an array`);
  if (actual.length !== expected.length || actual.some((value, index) => value !== expected[index])) {
    fail(`${label} drifted\nactual:   ${JSON.stringify(actual)}\nexpected: ${JSON.stringify(expected)}`);
  }
}
function readJson(path) {
  try {
    return JSON.parse(fs.readFileSync(path, "utf8"));
  } catch (error) {
    fail(`${path} is not valid JSON: ${error.message}`);
  }
}

const verdicts = ["pass", "request-changes", "reject", "blocked"];
const blockers = [
  "none",
  "missing-authority",
  "changed-head-sha",
  "merge-conflict",
  "sha-bound-action-unsupported",
  "preflight-failure",
  "permission-failure",
  "human-decision-needed",
  "partial-review",
  "secret-exposure-suspected",
  "other"
];
const nextActions = [
  "finish-by-authorized-actor",
  "revise",
  "human-escalation",
  "rerun-review",
  "fix-blocker"
];
const expectedCrosswalk = {
  "missing-authority": {
    mutation_guard_blocker_states: ["missing_authority", "authority_source_mismatch"],
    finish_result_blocker: ["authority"],
    finish_result_conflict_type: []
  },
  "changed-head-sha": {
    mutation_guard_blocker_states: ["head_changed", "stale_head"],
    finish_result_blocker: ["head_changed"],
    finish_result_conflict_type: ["stale_head"]
  },
  "merge-conflict": {
    mutation_guard_blocker_states: ["merge_blocked"],
    finish_result_blocker: ["not_mergeable"],
    finish_result_conflict_type: ["merge_blocked"]
  },
  "sha-bound-action-unsupported": {
    mutation_guard_blocker_states: [],
    finish_result_blocker: [],
    finish_result_conflict_type: []
  },
  "preflight-failure": {
    mutation_guard_blocker_states: ["project_binding_mismatch", "target_reread_unavailable", "identity_unavailable", "identity_changed"],
    finish_result_blocker: ["identity_unavailable", "identity_changed"],
    finish_result_conflict_type: []
  },
  "permission-failure": {
    mutation_guard_blocker_states: ["permission_uncertain"],
    finish_result_blocker: [],
    finish_result_conflict_type: []
  },
  "human-decision-needed": {
    mutation_guard_blocker_states: [],
    finish_result_blocker: [],
    finish_result_conflict_type: []
  },
  "partial-review": {
    mutation_guard_blocker_states: [],
    finish_result_blocker: [],
    finish_result_conflict_type: []
  },
  "secret-exposure-suspected": {
    mutation_guard_blocker_states: [],
    finish_result_blocker: [],
    finish_result_conflict_type: []
  }
};

const schema = readJson(schemaPath);
const mutationGuard = readJson(mutationGuardPath);
const finishResult = readJson(finishResultPath);

assert(schema.$schema === "https://json-schema.org/draft/2020-12/schema", "$schema drifted");
assert(schema.$id === "skill://start-review/reference/handoff-tokens.schema.json", "$id drifted");
assert(schema.kind === "reviewer-handoff-tokens-schema", "kind drifted");
assert(schema.version === "1", "version drifted");
assert(schema.owner === "start-review", "owner drifted");
assert(schema.human_resource === "skill://start-review/templates/filling-guide.md", "human_resource drifted");
sameList("review_verdict", schema.review_verdict, verdicts);
sameList("action_blocker", schema.action_blocker, blockers);
sameList("next_action", schema.next_action, nextActions);
sameList("blocker_token", schema.blocker_token, blockers);

assert(Array.isArray(schema.crosswalk), "crosswalk must be an array");
assert(schema.crosswalk.length === 9, `crosswalk must have 9 entries, found ${schema.crosswalk.length}`);
const crosswalk = new Map(schema.crosswalk.map((entry) => [entry.action_blocker, entry]));
sameList("crosswalk action blockers", [...crosswalk.keys()], blockers.slice(1, -1));
assert(crosswalk.size === schema.crosswalk.length, "crosswalk action_blocker values must be unique");

const mutationTokens = new Set(mutationGuard.blocker_states.map(({token}) => token));
const finishBlockers = new Set(finishResult.properties.blocker.enum);
const finishConflicts = new Set(finishResult.properties.conflict_type.enum);
const allowedMcpCodes = new Set(["stale_sha", "branch_mismatch", "ci_stale", "post_action_mismatch"]);
for (const [token, expected] of Object.entries(expectedCrosswalk)) {
  const entry = crosswalk.get(token);
  assert(entry, `missing crosswalk entry for ${token}`);
  assert(typeof entry.meaning === "string" && entry.meaning.trim(), `${token} needs a one-line meaning`);
  assert(!entry.meaning.includes("\n"), `${token} meaning must stay one line`);
  for (const [field, values] of Object.entries(expected)) sameList(`${token}.${field}`, entry[field], values);
  for (const target of entry.mutation_guard_blocker_states) assert(mutationTokens.has(target), `${token} references missing mutation-guard blocker ${target}`);
  for (const target of entry.finish_result_blocker) assert(finishBlockers.has(target), `${token} references missing finish-result blocker ${target}`);
  for (const target of entry.finish_result_conflict_type) assert(finishConflicts.has(target), `${token} references missing finish-result conflict_type ${target}`);
  if (entry.mcp_codes !== undefined) {
    assert(Array.isArray(entry.mcp_codes) && entry.mcp_codes.length > 0, `${token}.mcp_codes must be a non-empty informational list when present`);
    for (const code of entry.mcp_codes) assert(allowedMcpCodes.has(code), `${token} references unsupported informational MCP code ${code}`);
  }
}

const enumText = {
  "start-review/templates/filling-guide.md": "`missing-authority`, `changed-head-sha`, `merge-conflict`, `sha-bound-action-unsupported`, `preflight-failure`, `permission-failure`, `human-decision-needed`, `partial-review`, `secret-exposure-suspected`, or `other`",
  "start-review/templates/review-report.md": "<none / missing-authority / changed-head-sha / merge-conflict / sha-bound-action-unsupported / preflight-failure / permission-failure / human-decision-needed / partial-review / secret-exposure-suspected / other>",
  "start-review/templates/reviewer-final-handoff.md": "action_blocker: \"none / missing-authority / changed-head-sha / merge-conflict / sha-bound-action-unsupported / preflight-failure / permission-failure / human-decision-needed / partial-review / secret-exposure-suspected / other\""
};
let pointerCount = 0;
for (const [path, enumNeedle] of Object.entries(enumText)) {
  const text = fs.readFileSync(path, "utf8");
  assert(text.includes(enumNeedle), `${path} enum string drifted`);
  const pointerLines = text.split("\n").filter((line) => line.includes("handoff-tokens.schema.json"));
  assert(pointerLines.length === 1, `${path} must contain exactly one canonical-schema pointer line`);
  pointerCount += pointerLines.length;
}
assert(pointerCount === 3, "expected exactly three template schema pointers");

const invariantTest = fs.readFileSync("tests/token-grep-invariants.sh", "utf8");
assert(invariantTest.includes(schemaPath), "token-grep-invariants.sh must read the handoff token schema");
assert(invariantTest.includes("node --input-type=module"), "token-grep-invariants.sh must use the established Node module reader");
assert(!invariantTest.includes("blockers=$'none"), "token-grep-invariants.sh still owns an inline blocker enum");

console.log("handoff-tokens-schema: PASS");
NODE
