#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

node <<'NODE'
const fs = require('node:fs');

const factsPath = 'setup-dev-skills/reference/project-profile-facts.json';
const factsResource = 'skill://setup-dev-skills/reference/project-profile-facts.json';

function fail(message) {
  console.error(`project-profile-facts: FAIL: ${message}`);
  process.exit(1);
}

function assert(condition, message) {
  if (!condition) fail(message);
}

function read(file) {
  return fs.readFileSync(file, 'utf8');
}

function has(file, needle) {
  assert(read(file).includes(needle), `${file} missing ${needle}`);
}

function allRepoRelative(paths, label) {
  for (const [key, value] of Object.entries(paths)) {
    assert(!value.startsWith('skill://'), `${label}.${key} must be repo-relative, got ${value}`);
  }
}

let facts;
try {
  facts = JSON.parse(read(factsPath));
} catch (error) {
  fail(`${factsPath} is not valid JSON: ${error.message}`);
}

assert(facts.kind === 'setup-dev-skills-project-profile-facts', 'facts kind drifted');
assert(facts.version === '1', 'facts version drifted');
assert(facts.machine_resource === factsResource, 'machine_resource must be skill://setup-dev-skills/reference/project-profile-facts.json');
assert(facts.$id === factsResource, '$id must be the skill:// project-profile facts URI');

const requiredFields = facts.required_project_profile_fields ?? [];
for (const field of [
  'tracker',
  'agent_setup_docs',
  'label_vocabulary',
  'check_gate',
  'dev_workflows',
  'branch_naming',
  'ci_parity',
  'skill_resources',
  'resource_addressing'
]) {
  assert(requiredFields.includes(field), `required project-profile field missing ${field}`);
}

const defaultProfile = facts.default_profile;
assert(defaultProfile.tracker.kind === 'gitlab', 'default tracker kind must be gitlab');
assert(defaultProfile.tracker.host === 'gitlab.example.com', 'default tracker host drifted');
assert(defaultProfile.tracker.project_path === 'agents/skills', 'default project path drifted');
assert(defaultProfile.agent_setup_docs.root === 'docs/agents', 'default Agent Setup Docs root drifted');
assert(defaultProfile.label_vocabulary.label_profile_ref === 'docs/agents/triage-labels.md#live-label-inventory', 'default label_profile_ref drifted');
assert(defaultProfile.label_vocabulary.triage_role_labels.afk_ready === 'ready-for-agent', 'this repo AFK-ready label mapping drifted');
assert(defaultProfile.check_gate.gate_policy_ref === 'docs/agents/check-gate.md#full-local-gate', 'default gate_policy_ref drifted');
assert(defaultProfile.check_gate.command === 'npm run check', 'default Check Gate command drifted');
assert(defaultProfile.dev_workflows.path === 'docs/agents/dev-workflows.md', 'default Dev Workflow path drifted');
assert(defaultProfile.branch_naming.pattern === 'issue-<iid>-<slug>', 'default branch naming drifted');
assert(defaultProfile.ci_parity.required_jobs.includes('validation'), 'default CI required jobs missing validation');
allRepoRelative(defaultProfile.agent_setup_docs, 'default_profile.agent_setup_docs');

for (const [key, value] of Object.entries(facts.skill_resources)) {
  assert(value.startsWith('skill://'), `skill_resources.${key} must use skill:// URI`);
}
assert(facts.resource_addressing.target_repo_docs.mode === 'repo-relative', 'target repo docs must stay repo-relative');
assert(facts.resource_addressing.runtime_skill_resources.mode === 'skill-uri', 'runtime skill resources must use skill-uri mode');

const fixture = facts.cross_project_fixtures.find((candidate) => candidate.profile_id === 'non-default-docs-and-labels');
assert(fixture, 'missing non-default docs/labels fixture');
assert(fixture.agent_setup_docs.root !== defaultProfile.agent_setup_docs.root, 'fixture must use a non-default Agent Setup Docs root');
assert(fixture.agent_setup_docs.check_gate !== defaultProfile.agent_setup_docs.check_gate, 'fixture must use a non-default Check Gate path');
assert(fixture.label_vocabulary.triage_role_labels.afk_ready !== defaultProfile.label_vocabulary.triage_role_labels.afk_ready, 'fixture AFK-ready label must be non-default');
assert(fixture.label_vocabulary.triage_role_labels.afk_ready === 'agent-ready', 'fixture AFK-ready label drifted');
allRepoRelative(fixture.agent_setup_docs, 'fixture.agent_setup_docs');
assert(fixture.check_gate.gate_policy_ref.startsWith(fixture.agent_setup_docs.check_gate), 'fixture gate ref must derive from fixture Check Gate path');
assert(fixture.dev_workflows.path === fixture.agent_setup_docs.dev_workflows, 'fixture Dev Workflow path must derive from fixture Agent Setup Docs');

const setupSkill = read('setup-dev-skills/SKILL.md');
assert(setupSkill.includes(factsResource), 'setup skill must name the skill:// fact source');
for (const term of ['Agent Setup Doc paths', 'tracker fields', 'Triage Role mapping', 'Check Gate refs', 'Dev Workflow refs', 'branch naming', 'CI parity', 'runtime skill-resource URIs']) {
  assert(setupSkill.includes(term), `setup skill missing fact-source term ${term}`);
}

for (const file of [
  'setup-dev-skills/dev-workflows-gitlab.md',
  'setup-dev-skills/issue-tracker-gitlab.md',
  'setup-dev-skills/triage-labels.md',
  'setup-dev-skills/check-gate.md',
  'setup-dev-skills/domain.md',
  'docs/agents/dev-workflows.md',
  'docs/agents/issue-tracker.md',
  'docs/agents/triage-labels.md',
  'docs/agents/check-gate.md'
]) {
  has(file, 'project-profile-facts.json');
}

const liveLabels = read('docs/agents/triage-labels.md');
assert(liveLabels.includes('| `afk_ready` | `ready-for-agent` |'), 'live docs must map afk_ready Triage Role to this repo label');
assert(liveLabels.includes('reusable skills must read `project_profile.label_profile_ref`'), 'live labels doc must forbid global label assumptions');

const genericTriageSeed = read('setup-dev-skills/triage-labels.md');
assert(!genericTriageSeed.includes('ready-for-agent'), 'generic triage seed must not hardcode this repo AFK-ready label');
assert(genericTriageSeed.includes('Do not assume a global label string'), 'generic triage seed must document label mapping');

const gitlabSkill = read('gitlab-local/SKILL.md');
assert(!gitlabSkill.includes('--label ready-for-agent'), 'gitlab-local issue-pickup fallback must not hardcode ready-for-agent');
assert(gitlabSkill.includes('project_profile.label_profile_ref'), 'gitlab-local issue-pickup fallback must point to project_profile.label_profile_ref');

const snippetMetadata = read('gitlab-local/reference/snippet-metadata.json');
const snippetTransport = read('gitlab-local/reference/snippet-transports.md');
assert(!snippetMetadata.includes('selection filters (`ready-for-agent`'), 'snippet metadata must not hardcode ready-for-agent as a filter');
assert(snippetMetadata.includes('target repo AFK-ready label from `project_profile.label_profile_ref`'), 'snippet metadata must describe label-profile-derived filters');
assert(snippetTransport.includes('target repo AFK-ready label from `project_profile.label_profile_ref`'), 'snippet transport table must match label-profile-derived filters');

console.log('project-profile-facts: PASS');
NODE
