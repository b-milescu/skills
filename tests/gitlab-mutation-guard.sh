#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

node <<'NODE'
const fs = require('node:fs');

const schemaPath = 'gitlab/reference/mutation-guard.schema.json';
const docPath = 'gitlab/reference/mutation-guard.md';
const metadataPath = 'gitlab/reference/snippet-metadata.json';
const guardDocResource = 'skill://gitlab/reference/mutation-guard.md';
const guardSchemaResource = 'skill://gitlab/reference/mutation-guard.schema.json';

function fail(message) {
  console.error(`gitlab-mutation-guard: FAIL: ${message}`);
  process.exit(1);
}
function assert(condition, message) {
  if (!condition) fail(message);
}
function sameList(label, actual, expected) {
  if (actual.length !== expected.length || actual.some((value, index) => value !== expected[index])) {
    fail(`${label} drifted\nactual:   ${JSON.stringify(actual)}\nexpected: ${JSON.stringify(expected)}`);
  }
}
function readJson(path) {
  try {
    return JSON.parse(fs.readFileSync(path, 'utf8'));
  } catch (error) {
    fail(`${path} is not valid JSON: ${error.message}`);
  }
}
function requireText(path, pattern, label) {
  const text = fs.readFileSync(path, 'utf8');
  assert(pattern.test(text), `${path} missing ${label}`);
  return text;
}

const schema = readJson(schemaPath);
const metadata = readJson(metadataPath);
const doc = requireText(docPath, /GitLab Mutation Guard/, 'guard title');

assert(schema.kind === 'gitlab-mutation-guard-schema', 'schema kind drifted');
assert(schema.version === '1', 'schema version drifted');
assert(schema.$id === guardSchemaResource, 'schema $id must be skill:// resource URI');
assert(schema.human_resource === guardDocResource, 'schema human_resource must use skill:// guard doc URI');
assert(schema.cross_project_guidance.guard_docs === guardDocResource, 'cross-project guard doc resource drifted');
assert(schema.cross_project_guidance.guard_schema === guardSchemaResource, 'cross-project guard schema resource drifted');
assert(Array.isArray(schema.cross_project_guidance.mcp_helper_tools), 'cross-project MCP helper tool inventory must be present');
for (const tool of ['validate_gitlab_text', 'safe_update_merge_request_description', 'safe_create_merge_request_note', 'safe_create_issue_note', 'get_merge_request_workflow_snapshot', 'finish_merge_request', 'get_post_merge_snapshot']) {
  assert(schema.cross_project_guidance.mcp_helper_tools.includes(tool), `cross-project MCP helper tool missing ${tool}`);
}
assert(schema.cross_project_guidance.target_repo_docs.includes('docs/agents/'), 'target repo docs guidance must stay repo-relative');
assert(!doc.includes('skill://gitlab/docs/agents/'), 'guard doc must not convert target docs/agents refs to gitlab skill docs');

sameList('ordered guard steps', schema.ordered_steps.map((step) => step.id), [
  'project_binding',
  'current_target_reread',
  'reviewed_sha_guard',
  'exact_sha_ci_observation',
  'exact_candidate_gate_receipt',
  'authority_verification',
  'caller_identity_and_context',
  'safe_gitlab_text',
  'fallback_eligibility',
  'single_mutation',
  'post_mutation_mcp_reread'
]);
for (const [index, step] of schema.ordered_steps.entries()) {
  assert(step.order === index + 1, `${step.id} order must be ${index + 1}`);
  assert(Array.isArray(step.blocks), `${step.id} blocks must be an array`);
  if (step.id === 'exact_sha_ci_observation') assert(step.blocks.length === 0, 'advisory CI observation must not block');
  else assert(step.blocks.length > 0, `${step.id} must name blocker states`);
}

const currentTargetReread = schema.ordered_steps.find((step) => step.id === 'current_target_reread');
assert(currentTargetReread.requires[0] === 'get_merge_request_workflow_snapshot for default MR guard-grade state/SHA', 'MR current-target re-read must prefer the workflow snapshot');
assert(currentTargetReread.requires[1] === 'get_merge_request(include_description:false) only for required MR fields absent from the snapshot', 'body-free MR read must be secondary and field-driven');
const snapshotIndex = doc.indexOf('get_merge_request_workflow_snapshot');
const bodyFreeIndex = doc.indexOf('get_merge_request(include_description:false)');
assert(snapshotIndex !== -1 && bodyFreeIndex > snapshotIndex, 'guard doc must order snapshot before the body-free supplemental MR read');
assert(!doc.includes('first per-MR full read'), 'guard doc must not preserve obsolete first-full-read discipline');

const blockerByToken = new Map(schema.blocker_states.map((blocker) => [blocker.token, blocker]));
for (const token of [
  'head_changed',
  'stale_head',
  'stale_or_missing_gate_receipt',
  'missing_authority',
  'authority_source_mismatch',
  'permission_uncertain',
  'self_merge_risk',
  'content_byte_failure',
  'post_reread_unavailable'
]) {
  assert(blockerByToken.has(token), `missing blocker token ${token}`);
  assert(blockerByToken.get(token).fallback_allowed === false, `${token} must forbid fallback`);
  assert(schema.fallback_forbidden_when.includes(token), `${token} missing from fallback_forbidden_when`);
}
for (const token of ['stale_ci', 'red_ci', 'missing_ci']) {
  assert(!blockerByToken.has(token), `${token} must not remain a mutation blocker`);
  assert(!schema.fallback_forbidden_when.includes(token), `${token} must not affect fallback eligibility`);
}
assert(schema.input_fields.includes('gate_receipt'), 'Gate Receipt input must be machine-readable');
assert(schema.output_fields.includes('gate_receipt_verification'), 'Gate Receipt verification output must be machine-readable');
for (const profile of ['sha_bound_finish', 'ready_transition']) {
  const steps = schema.mutation_profiles[profile].required_steps;
  assert(steps.includes('exact_candidate_gate_receipt'), `${profile} must require exact-candidate Gate Receipt`);
  assert(steps.indexOf('exact_sha_ci_observation') < steps.indexOf('exact_candidate_gate_receipt'), `${profile} Gate Receipt order drifted`);
  assert(steps.indexOf('exact_candidate_gate_receipt') < steps.indexOf('authority_verification'), `${profile} Gate Receipt must precede authority`);
}

const gapTokens = schema.mcp_gap_states.map((gap) => gap.token);
for (const token of ['mcp_unavailable', 'mcp_merge_robustness_gap', 'mcp_pagination_gap']) {
  assert(gapTokens.includes(token), `missing first-class MCP gap state ${token}`);
}
assert(schema.mcp_gap_states.find((gap) => gap.token === 'mcp_merge_robustness_gap').fallback_allowed === true, 'merge robustness gap must allow guarded fallback');
assert(schema.mcp_gap_states.find((gap) => gap.token === 'mcp_pagination_gap').meaning.includes('pagination'), 'pagination gap meaning must be explicit');

sameList('transport evidence tokens', schema.transport_evidence.tokens, ['via=mcp', 'via=glab-fallback', 'via=n/a']);
for (const classification of ['verified', 'note_created', 'merged', 'auto_merge_queued', 'stale_head', 'merge_blocked', 'post_reread_unavailable']) {
  assert(schema.post_mutation_reread_classifications.includes(classification), `missing post-mutation classification ${classification}`);
}

const examples = new Map(schema.examples.map((example) => [example.label, example]));
function requireExample(label, expected) {
  const example = examples.get(label);
  assert(example, `missing example ${label}`);
  for (const [key, value] of Object.entries(expected)) {
    assert(example[key] === value, `${label} expected ${key}=${value}, got ${example[key]}`);
  }
  return example;
}

for (const [label, blocker] of [
  ['blocked: stale head', 'head_changed'],
  ['blocked: missing authority', 'missing_authority'],
  ['blocked: self-merge risk', 'self_merge_risk']
]) {
  requireExample(label, {
    result: 'blocked',
    blocker,
    transport_evidence: 'via=n/a',
    mutation_performed: false,
    fallback_allowed: false
  });
}

const robustnessFallback = requireExample('fallback: MCP merge robustness gap verified', {
  result: 'passed',
  blocker: 'none',
  mcp_gap_state: 'mcp_merge_robustness_gap',
  transport_evidence: 'via=glab-fallback',
  mutation_performed: true,
  fallback_allowed: true
});
assert(robustnessFallback.post_mutation_reread?.classification === 'verified', 'MCP merge robustness fallback must require successful post-mutation re-read classification');

const postReadSuccess = requireExample('success: post-mutation reread verified', {
  result: 'passed',
  blocker: 'none',
  transport_evidence: 'via=mcp',
  mutation_performed: true,
  fallback_allowed: false
});
assert(postReadSuccess.post_mutation_reread?.required === true, 'successful mutation example must require post-mutation re-read');
assert(postReadSuccess.post_mutation_reread?.classification === 'note_created', 'successful mutation example must classify the post-mutation re-read');

assert(metadata.mutation_guard?.resource === guardDocResource, 'snippet metadata must point at the guard doc resource');
assert(metadata.mutation_guard?.schema === guardSchemaResource, 'snippet metadata must point at the guard schema resource');
for (const token of ['mcp_unavailable', 'mcp_merge_robustness_gap', 'mcp_pagination_gap']) {
  assert(metadata.mutation_guard.gap_states.includes(token), `snippet metadata missing guard gap state ${token}`);
}
const shaBoundMerge = metadata.snippets.find((snippet) => snippet.name === 'sha-bound-merge');
assert(shaBoundMerge, 'top-level sha-bound-merge metadata missing');
for (const guard of ['current head equals reviewed SHA before action', 'passing exact-candidate Gate Receipt bound to reviewed SHA', 'merge authority/source before action', 'caller identity/token-stability before action', 'provider-native post-mutation readback']) {
  assert(shaBoundMerge.required_guards.includes(guard), `sha-bound-merge top-level metadata missing ${guard}`);
}
assert(shaBoundMerge.required_guards.some((guard) => guard.includes('advisory exact-SHA CI attribution') && guard.includes('non-blocking')), 'sha-bound-merge CI metadata must be advisory');
assert(!shaBoundMerge.required_guards.some((guard) => /green CI|required CI/i.test(guard)), 'sha-bound-merge metadata must not require CI');
assert(!shaBoundMerge.fallback_conditions.some((condition) => /stale\/red\/missing/i.test(condition)), 'sha-bound-merge fallback must not use CI blocker states');
assert(metadata.mutation_guard.fallback_forbidden_when.includes('stale_or_missing_gate_receipt'), 'global metadata must forbid fallback on stale/missing Gate Receipt');
assert(doc.includes('- `stale_or_missing_gate_receipt`'), 'human guard must forbid fallback on stale/missing Gate Receipt');

const shaBoundApproval = metadata.snippets.find((snippet) => snippet.name === 'sha-bound-approval');
assert(shaBoundApproval, 'top-level sha-bound-approval metadata missing');
const finishProfile = schema.mutation_profiles.sha_bound_finish.required_steps;
assert(finishProfile.includes('reviewed_sha_guard'), 'SHA-bound profile must require reviewed-head equality');
assert(finishProfile.includes('exact_candidate_gate_receipt'), 'SHA-bound profile must require exact-candidate Gate Receipt');
assert(shaBoundApproval.required_guards.includes('current MR head equals reviewed SHA before action'), 'approval metadata must implement reviewed_sha_guard');
assert(shaBoundApproval.required_guards.includes('passing exact-candidate Gate Receipt bound to reviewed SHA'), 'approval metadata must implement exact_candidate_gate_receipt');
const approvalRow = fs.readFileSync('gitlab/reference/snippet-transports.md', 'utf8')
  .split(/\r?\n/)
  .find((line) => line.startsWith('| `sha-bound-approval` |'));
assert(approvalRow, 'snippet-transports.md is missing the sha-bound-approval row');
const approvalGuards = approvalRow.split('|').slice(1, -1)[3];
assert(approvalGuards.includes('current head equals reviewed SHA'), 'approval transport row must state reviewed-head equality');
assert(approvalGuards.includes('passing exact-candidate Gate Receipt bound to reviewed SHA'), 'approval transport row must state Gate Receipt guard');
assert(!shaBoundApproval.required_guards.some((guard) => /CI/i.test(guard)), 'approval eligibility metadata must not contain a CI guard');

const transportDoc = requireText('gitlab/reference/snippet-transports.md', /GitLab Mutation Guard/, 'Mutation Guard reference');
assert(transportDoc.includes(guardSchemaResource), 'snippet-transports.md must name guard schema skill URI');
const ciFinishDoc = requireText('gitlab/reference/ci-finish-guards.md', /GitLab Mutation Guard/, 'Mutation Guard reference');
assert(ciFinishDoc.includes(guardDocResource), 'ci-finish-guards.md must name guard doc skill URI');
assert(!/### Guard and authority order/.test(ciFinishDoc), 'ci-finish-guards.md must not restate the old full guard order section');
const devWorkflowsDoc = requireText('docs/agents/dev-workflows.md', /skill:\/\/forge\/reference\/common-guard\.md/, 'cross-project common guard skill URI');
assert(devWorkflowsDoc.includes('docs/agents/...'), 'dev-workflows cross-project guidance must keep target docs repo-relative');

for (const path of [
  'gitlab/SKILL.md'
]) {
  const text = requireText(path, /Mutation Guard/, 'Mutation Guard reference');
  assert(text.includes('mutation-guard.md') || text.includes(guardDocResource), `${path} must link the guard doc`);
}

console.log('gitlab-mutation-guard: PASS');
NODE
