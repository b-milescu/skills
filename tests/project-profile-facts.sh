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
assert(defaultProfile.label_vocabulary.triage_role_labels.needs_info === 'needs-info', 'this repo needs-info label mapping drifted');
assert(defaultProfile.label_vocabulary.triage_role_labels.human_decision === 'human-decision', 'this repo human-decision label mapping drifted');
assert(defaultProfile.check_gate.gate_policy_ref === 'docs/agents/check-gate.md#full-local-gate', 'default gate_policy_ref drifted');
assert(defaultProfile.check_gate.command === 'npm run check', 'default Check Gate command drifted');
assert(defaultProfile.dev_workflows.path === 'docs/agents/dev-workflows.md', 'default Dev Workflow path drifted');
assert(defaultProfile.dev_workflows.acceptance_surfaces_ref === 'docs/agents/dev-workflows.md#acceptance-surface-vocabulary', 'default acceptance_surfaces_ref drifted');
assert(defaultProfile.branch_naming.pattern === 'issue-<iid>-<slug>', 'default branch naming drifted');
assert(defaultProfile.ci_parity.required_jobs.includes('check'), 'default CI required jobs missing check');
assert(!defaultProfile.ci_parity.required_jobs.includes('validation'), 'default CI required jobs must name the check job, not the validate stage');
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
// Fail-closed default: a target repo that declares no acceptance_surfaces_ref must omit it,
// so acceptance_surfaces is forced to []/none rather than borrowing this repo's vocabulary.
assert(fixture.dev_workflows.acceptance_surfaces_ref === undefined, 'no-vocabulary fixture must omit acceptance_surfaces_ref to demonstrate the fail-closed default');

const planToIssuesSkill = read('plan-to-issues/SKILL.md');
const readinessScorecard = facts.skill_resources.plan_to_issues_readiness_scorecard;

function assertPlanToIssuesProfileFlow(profile, expected) {
  assert(profile.agent_setup_docs.issue_tracker === expected.issueTracker, `${expected.name} issue-tracker path drifted`);
  assert(profile.agent_setup_docs.triage_labels === expected.triageLabels, `${expected.name} triage-label path drifted`);
  assert(profile.label_vocabulary.triage_role_labels.afk_ready === expected.afkReady, `${expected.name} AFK-ready label drifted`);
  assert(profile.label_vocabulary.kind_labels.docs === expected.docs, `${expected.name} docs label drifted`);
  assert(readinessScorecard === 'skill://plan-to-issues/docs/agents/agent-readiness-scorecard.md', `${expected.name} readiness scorecard must stay skill-owned`);
}

assertPlanToIssuesProfileFlow(defaultProfile, {
  name: 'default profile',
  issueTracker: 'docs/agents/issue-tracker.md',
  triageLabels: 'docs/agents/triage-labels.md',
  afkReady: 'ready-for-agent',
  docs: 'docs'
});
assertPlanToIssuesProfileFlow(fixture, {
  name: 'non-default profile',
  issueTracker: 'engineering/agent-docs/tracker.md',
  triageLabels: 'engineering/agent-docs/labels.md',
  afkReady: 'agent-ready',
  docs: 'documentation'
});
for (const binding of [
  'project_profile.agent_setup_docs.issue_tracker',
  'project_profile.agent_setup_docs.triage_labels',
  '<issue-tracker-doc>',
  '<triage-labels-doc>'
]) {
  assert(planToIssuesSkill.includes(binding), `plan-to-issues skill missing selected-profile binding ${binding}`);
}
assert(planToIssuesSkill.includes(readinessScorecard), 'plan-to-issues Agent Readiness must use the skill-owned scorecard');

const setupSkill = read('setup-dev-skills/SKILL.md');
assert(setupSkill.includes(factsResource), 'setup skill must name the skill:// fact source');
for (const term of ['Agent Setup Doc paths', 'tracker fields', 'Triage Role mapping', 'Check Gate refs', 'Dev Workflow refs', 'branch naming', 'CI parity', 'runtime skill-resource URIs']) {
  assert(setupSkill.includes(term), `setup skill missing fact-source term ${term}`);
}

for (const pathToken of [
  '<agent_setup_docs.issue_tracker>',
  '<agent_setup_docs.triage_labels>',
  '<agent_setup_docs.domain>',
  '<agent_setup_docs.check_gate>',
  '<agent_setup_docs.coding_guardrails>',
  '<agent_setup_docs.dev_workflows>'
]) {
  assert(setupSkill.includes(pathToken), `setup skill Agent skills block missing ${pathToken}`);
}
assert(setupSkill.includes('Substitute each `<agent_setup_docs.*>` placeholder'), 'setup skill must require target-profile path substitution for the Agent skills block');

for (const file of [
  'setup-dev-skills/dev-workflows-generic.md',
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
assert(liveLabels.includes('| `needs_info` | `needs-info` |'), 'live docs must map needs_info Triage Role to the needs-info label, not N/A');
assert(liveLabels.includes('| `human_decision` | `human-decision` |'), 'live docs must map human_decision Triage Role to the human-decision label, not N/A');
assert(liveLabels.includes('reusable skills must read `project_profile.label_profile_ref`'), 'live labels doc must forbid global label assumptions');

const liveDevWorkflows = read('docs/agents/dev-workflows.md');
assert(liveDevWorkflows.includes('acceptance_surfaces_ref'), 'live dev-workflows must declare the acceptance_surfaces_ref hook');
assert(liveDevWorkflows.includes('Acceptance-surface vocabulary'), 'live dev-workflows must host the acceptance-surface vocabulary section');
for (const surface of ['docs', 'prompt', 'agent_inventory', 'install_surface', 'transport', 'authority', 'ci_finish', 'mutation_guard']) {
  assert(liveDevWorkflows.includes(surface), `live dev-workflows acceptance-surface vocabulary must list ${surface}`);
}

const deliverySchema = read('start-build/templates/delivery-schema.md');
assert(deliverySchema.includes('acceptance_surfaces_ref'), 'delivery schema must expose acceptance_surfaces_ref hook');
for (const surface of ['agent_inventory', 'install_surface', 'ci_finish', 'mutation_guard']) {
  assert(!deliverySchema.includes(surface), `delivery schema must not hardcode this repo acceptance surface ${surface} as a global value`);
}

const genericTriageSeed = read('setup-dev-skills/triage-labels.md');
assert(!genericTriageSeed.includes('ready-for-agent'), 'generic triage seed must not hardcode this repo AFK-ready label');
assert(genericTriageSeed.includes('Do not assume a global label string'), 'generic triage seed must document label mapping');

const gitlabSkill = read('gitlab/SKILL.md');
assert(!gitlabSkill.includes('--label ready-for-agent'), 'gitlab issue-pickup fallback must not hardcode ready-for-agent');
assert(gitlabSkill.includes('project_profile.label_profile_ref'), 'gitlab issue-pickup fallback must point to project_profile.label_profile_ref');

const snippetMetadata = read('gitlab/reference/snippet-metadata.json');
const snippetTransport = read('gitlab/reference/snippet-transports.md');
assert(!snippetMetadata.includes('selection filters (`ready-for-agent`'), 'snippet metadata must not hardcode ready-for-agent as a filter');
assert(snippetMetadata.includes('target repo AFK-ready label from `project_profile.label_profile_ref`'), 'snippet metadata must describe label-profile-derived filters');
assert(snippetTransport.includes('target repo AFK-ready label from `project_profile.label_profile_ref`'), 'snippet transport table must match label-profile-derived filters');

console.log('project-profile-facts: PASS');
NODE
