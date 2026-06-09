#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

node <<'NODE'
const fs = require('node:fs');

const schemaPath = 'gitlab/reference/authority-verification.schema.json';
const docPath = 'gitlab/reference/authority-verification.md';
const schemaResource = 'skill://gitlab/reference/authority-verification.schema.json';
const docResource = 'skill://gitlab/reference/authority-verification.md';

function fail(message) {
  console.error(`authority-verification-schema: FAIL: ${message}`);
  process.exit(1);
}
function assert(condition, message) {
  if (!condition) fail(message);
}
function readText(path) {
  try {
    return fs.readFileSync(path, 'utf8');
  } catch (error) {
    fail(`${path} unreadable: ${error.message}`);
  }
}
function readJson(path) {
  try {
    return JSON.parse(readText(path));
  } catch (error) {
    fail(`${path} invalid JSON: ${error.message}`);
  }
}
function sameList(label, actual, expected) {
  if (actual.length !== expected.length || actual.some((value, index) => value !== expected[index])) {
    fail(`${label} drifted\nactual:   ${JSON.stringify(actual)}\nexpected: ${JSON.stringify(expected)}`);
  }
}
function requireText(path, pattern, label) {
  const text = readText(path);
  assert(pattern.test(text), `${path} missing ${label}`);
  return text;
}
function enumValues(path) {
  return path.reduce((value, key) => value?.[key], schema)?.enum || [];
}

const schema = readJson(schemaPath);
const doc = requireText(docPath, /# Authority Verification/, 'Authority Verification title');

assert(schema.kind === 'gitlab-authority-verification-schema', 'schema kind drifted');
assert(schema.version === '1', 'schema version drifted');
assert(schema.$id === schemaResource, 'schema $id must use skill:// URI');
assert(schema.human_resource === docResource, 'schema human_resource must use skill:// URI');
assert(doc.includes(schemaResource), 'human doc must point at machine schema skill URI');
assert(doc.includes('GitLab Mutation Guard'), 'human doc must place Authority Verification inside the Mutation Guard');
assert(/transport evidence/i.test(doc) && /Authority Verification evidence/i.test(doc), 'human doc must keep authority and transport evidence separate');
assert(/source_evidence:[\s\S]*grants_authority: true/.test(doc), 'human input shape must document source_evidence grants_authority');
assert(/source_precedence\[\]\.granted_actions/.test(doc), 'human doc must describe action-scoped source precedence grants');
assert(/Repo defaults do not imply merge\/auto-merge\/release\/cleanup authority/.test(doc), 'human doc must keep repo defaults from implying finish authority');

for (const field of [
  'requested_action',
  'caller',
  'approval',
  'merge',
  'source_evidence',
  'result',
  'decision',
  'blocker',
  'next_actor',
  'next_action',
  'conflicts',
  'evidence'
]) {
  assert(schema.required.includes(field), `schema missing required field ${field}`);
}

sameList('requested actions', enumValues(['properties', 'requested_action']), [
  'handoff',
  'approve',
  'merge',
  'queue-auto-merge'
]);
sameList('source precedence', schema.source_precedence.map((entry) => entry.source_type), [
  'human-explicit',
  'parent-explicit',
  'mr-or-issue-policy',
  'project-rulebook',
  'repo-default',
  'builder-claim'
]);
assert(schema.source_precedence.find((entry) => entry.source_type === 'builder-claim').grants_authority === false, 'builder-claim must not grant authority');
const sourceEvidence = schema.$defs.sourceEvidence;
sameList('source evidence required fields', sourceEvidence.required, [
  'source_type',
  'source',
  'value',
  'grants_authority'
]);
for (const entry of schema.source_precedence) {
  assert(Array.isArray(entry.granted_actions), `${entry.source_type} must declare granted_actions`);
}
const repoDefaultSource = schema.source_precedence.find((entry) => entry.source_type === 'repo-default');
assert(repoDefaultSource.grants_authority === true, 'repo-default may grant approval authority only');
sameList('repo-default granted actions', repoDefaultSource.granted_actions, ['approve']);
assert(!repoDefaultSource.granted_actions.includes('merge'), 'repo-default must not grant merge authority');
assert(!repoDefaultSource.granted_actions.includes('queue-auto-merge'), 'repo-default must not grant auto-merge authority');
const builderClaimSource = schema.source_precedence.find((entry) => entry.source_type === 'builder-claim');
sameList('builder-claim granted actions', builderClaimSource.granted_actions, []);
sameList('result states', schema.result_states, ['verified', 'restricted', 'conflict', 'missing', 'handoff', 'blocked']);
sameList('action decisions', schema.action_decisions, ['proceed', 'must-handoff', 'ask-human', 'blocked']);
for (const token of [
  'none',
  'missing_authority',
  'authority_source_mismatch',
  'restricted_authority',
  'permission_uncertain',
  'self_merge_risk',
  'identity_unavailable',
  'identity_changed'
]) {
  assert(schema.blocker_tokens.includes(token), `missing blocker token ${token}`);
}

const examples = new Map(schema.examples.map((example) => [example._label, example]));
function requireExample(label, expected) {
  const example = examples.get(label);
  assert(example, `missing example ${label}`);
  for (const [key, value] of Object.entries(expected)) {
    assert(example[key] === value, `${label} expected ${key}=${value}, got ${example[key]}`);
  }
  return example;
}

requireExample('approval default after pass', {requested_action: 'approve', result: 'verified', decision: 'proceed', blocker: 'none'});
requireExample('missing merge authority', {requested_action: 'merge', result: 'missing', decision: 'must-handoff', blocker: 'missing_authority'});
requireExample('conflicting authority sources', {requested_action: 'queue-auto-merge', result: 'conflict', decision: 'ask-human', blocker: 'authority_source_mismatch'});
requireExample('restricted approval authority', {requested_action: 'approve', result: 'restricted', decision: 'blocked', blocker: 'restricted_authority'});
requireExample('reviewer approval-only', {requested_action: 'approve', result: 'verified', decision: 'proceed', blocker: 'none'});
requireExample('parent merge authority', {requested_action: 'merge', result: 'verified', decision: 'proceed', blocker: 'none'});
requireExample('builder always handoff', {requested_action: 'handoff', result: 'handoff', decision: 'must-handoff', blocker: 'none'});
requireExample('self approval block', {requested_action: 'approve', result: 'blocked', decision: 'blocked', blocker: 'self_merge_risk'});
requireExample('self merge block', {requested_action: 'merge', result: 'blocked', decision: 'blocked', blocker: 'self_merge_risk'});

const defaultApproval = examples.get('approval default after pass');
const defaultApprovalRepoEvidence = defaultApproval.source_evidence.find((entry) => entry.source_type === 'repo-default');
assert(defaultApproval.approval.value === 'default-after-pass', 'default approval example must use default-after-pass');
assert(defaultApprovalRepoEvidence?.grants_authority === true, 'default approval example must include repo-default source_evidence grant');
const missingMerge = examples.get('missing merge authority');
assert(missingMerge.merge.source_type === 'builder-claim' && missingMerge.merge.verified === false, 'missing merge example must not infer finish authority');
for (const example of schema.examples) {
  if (example.requested_action === 'merge' || example.requested_action === 'queue-auto-merge') {
    const hasRepoDefaultFinishGrant = example.source_evidence.some((entry) => entry.source_type === 'repo-default' && entry.grants_authority === true);
    assert(!hasRepoDefaultFinishGrant, `${example._label} must not use repo-default as finish-action grant`);
  }
}
const conflict = examples.get('conflicting authority sources');
assert(conflict.conflicts.length === 1 && conflict.conflicts[0].resolution === 'human-required', 'conflict example must require human resolution');
const selfMerge = examples.get('self merge block');
assert(selfMerge.caller.caller_user_id === selfMerge.caller.mr_author_id, 'self merge example should bind caller/author ids for audit');
assert(selfMerge.caller.context_relation === 'builder-session', 'self merge block must be context-based, not GitLab-account-only');

for (const [path, label] of [
  ['start-build/templates/reviewer-lift-schema.md', 'Reviewer Lift schema'],
  ['start-review/templates/review-report.md', 'Review Report template'],
  ['start-build/templates/gitlab-delivery-schema.md', 'delivery schema'],
  ['start-build/templates/builder-final-handoff.md', 'builder delivery handoff'],
  ['start-review/templates/reviewer-final-handoff.md', 'reviewer delivery handoff'],
  ['gitlab/reference/finish-result-schema.json', 'finish result schema'],
  ['gitlab/reference/authority-matrix.md', 'authority matrix'],
  ['gitlab/reference/mutation-guard.md', 'Mutation Guard'],
  ['gitlab/reference/mutation-guard.schema.json', 'Mutation Guard schema'],
  ['gitlab/reference/identity-and-authentication.md', 'identity/authentication doc']
]) {
  requireText(path, /authority-verification\.md|authority-verification\.schema\.json|Authority Verification/, `${label} canonical authority seam reference`);
}

const finishSchema = readJson('gitlab/reference/finish-result-schema.json');
for (const field of ['transport', 'authority_verification_source']) {
  assert(finishSchema.required.includes(field), `finish_result must keep separate required ${field} evidence`);
}
assert(finishSchema.properties.transport.description.includes('via=mcp'), 'finish_result transport must describe transport evidence');
assert(/authority-verification/i.test(finishSchema.properties.authority_verification_source.description), 'finish_result authority field must cite Authority Verification');

console.log('authority-verification-schema: PASS');
NODE
