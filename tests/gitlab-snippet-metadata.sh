#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

node <<'NODE'
const fs = require('node:fs');

const metadataPath = 'gitlab/reference/snippet-metadata.json';
const contractPath = 'gitlab/reference/snippet-transports.md';
const skillPath = 'gitlab/SKILL.md';
const metadataResource = 'skill://gitlab/reference/snippet-metadata.json';
const expectedNames = [
  'local-repo-preflight',
  'issue-pickup',
  'draft-mr-create',
  'mr-description-update',
  'draft-mr-mark-ready',
  'mr-pickup',
  'artifact-capture',
  'ci-decision-snapshot',
  'ci-watch-sha-pinned',
  'mr-note-create',
  'issue-note-create',
  'label-reconcile',
  'safe-mr-json',
  'auto-merge-api-fallback',
  'sha-guard',
  'sha-bound-approval',
  'sha-bound-merge',
  'sha-bound-auto-merge-queue',
  'approval-confirmation',
  'finish-mr-authority-aware',
  'mr-handoff-evidence'
];

function fail(message) {
  console.error(`gitlab-snippet-metadata: FAIL: ${message}`);
  process.exit(1);
}

function assert(condition, message) {
  if (!condition) fail(message);
}

function sameList(label, actual, expected) {
  assert(Array.isArray(actual), `${label} is not an array`);
  if (actual.length !== expected.length || actual.some((value, index) => value !== expected[index])) {
    fail(`${label} drifted\nactual:   ${JSON.stringify(actual)}\nexpected: ${JSON.stringify(expected)}`);
  }
}

// Group-file membership is phase-ordered, so equality there is set equality.
function sameSet(label, actual, expected) {
  assert(Array.isArray(actual), `${label} is not an array`);
  const sortedActual = [...actual].sort();
  const sortedExpected = [...expected].sort();
  if (new Set(actual).size !== actual.length) {
    fail(`${label} has duplicates\nactual: ${JSON.stringify(sortedActual)}`);
  }
  sameList(label, sortedActual, sortedExpected);
}

function parseMarkdownRows(markdown) {
  const rows = new Map();
  for (const line of markdown.split(/\r?\n/)) {
    if (!line.startsWith('| `')) continue;
    const cells = line.split('|').slice(1, -1).map((cell) => cell.trim());
    assert(cells.length === 5, `transport row does not have 5 cells: ${line}`);
    const nameMatch = cells[0].match(/^`([^`]+)`$/);
    assert(nameMatch, `transport row has invalid snippet cell: ${line}`);
    rows.set(nameMatch[1], {
      mcp_primary_tools: cells[1],
      inputs: cells[2],
      required_guards: cells[3],
      fallback_conditions: cells[4]
    });
  }
  return rows;
}

const metadataText = fs.readFileSync(metadataPath, 'utf8');
let metadata;
try {
  metadata = JSON.parse(metadataText);
} catch (error) {
  fail(`${metadataPath} is not valid JSON: ${error.message}`);
}

const contract = fs.readFileSync(contractPath, 'utf8');
const skill = fs.readFileSync(skillPath, 'utf8');

assert(metadata.kind === 'gitlab-snippet-metadata', 'metadata kind must be gitlab-snippet-metadata');
assert(metadata.version === '1', 'metadata version must be 1');
assert(metadata.machine_resource === metadataResource, 'metadata machine_resource must use skill:// resource URI');
assert(metadata.$id === metadataResource, 'metadata $id must use skill:// resource URI');
assert(metadata.markdown_contract === contractPath, 'metadata markdown_contract path drifted');
assert(metadata.stable_snippet_count === expectedNames.length, 'stable_snippet_count drifted');
assert(contract.includes(metadataResource), 'snippet-transports.md must name the skill:// metadata resource');
assert(skill.includes(metadataResource), 'gitlab/SKILL.md must name the skill:// metadata resource');
assert(contract.includes('checked against this metadata by `tests/gitlab-snippet-metadata.sh`'), 'snippet-transports.md must state the Markdown is checked against metadata');
assert(metadata.via_evidence_requirement?.required === true, 'top-level via evidence requirement must be present');
assert(metadata.via_evidence_requirement.mcp_token === 'via=mcp', 'MCP via evidence token drifted');
assert(metadata.via_evidence_requirement.fallback_token === 'via=glab-fallback', 'fallback via evidence token drifted');

const requiredSnippetFields = metadata.required_snippet_fields ?? [];
for (const field of [
  'name',
  'mcp_primary_tools',
  'input_category',
  'output_category',
  'allowed_mutations',
  'required_guards',
  'fallback_conditions',
  'post_mutation_reread',
  'via_evidence',
]) {
  assert(requiredSnippetFields.includes(field), `required snippet field inventory missing ${field}`);
}

const snippets = metadata.snippets;
assert(Array.isArray(snippets), 'metadata snippets must be an array');
sameList('metadata stable snippet names', snippets.map((snippet) => snippet.name), expectedNames);
assert(new Set(snippets.map((snippet) => snippet.name)).size === snippets.length, 'metadata snippet names must be unique');

// Bodies live in the three phase-grouped files (ADR-0002); the entry procedure
// keeps the index. The hard count survives as a sum across the group.
const groupPaths = [
  'gitlab/reference/snippets-read-evidence.md',
  'gitlab/reference/snippets-publish-body.md',
  'gitlab/reference/snippets-mutate-finish.md'
];
const groupSnippetNames = groupPaths.flatMap((path) =>
  [...fs.readFileSync(path, 'utf8').matchAll(/^## Snippet: ([^\r\n]+)$/gm)].map((match) => match[1])
);
sameSet('group-file stable snippet names', groupSnippetNames, expectedNames);
assert(
  !/^### Snippet:/m.test(skill),
  'gitlab/SKILL.md must keep the snippet index only; bodies belong in the group files'
);
for (const name of expectedNames) {
  assert(skill.includes(`\`${name}\``), `gitlab/SKILL.md snippet index is missing a row for ${name}`);
}

const markdownRows = parseMarkdownRows(contract);
sameList('Markdown stable snippet names', [...markdownRows.keys()], expectedNames);

const allowedRereadModes = new Set(['none', 'conditional', 'required']);
const markdownCells = ['mcp_primary_tools', 'inputs', 'required_guards', 'fallback_conditions'];

for (const snippet of snippets) {
  for (const field of requiredSnippetFields) {
    assert(Object.hasOwn(snippet, field), `${snippet.name} missing required field ${field}`);
  }
  assert(Array.isArray(snippet.mcp_primary_tools) && snippet.mcp_primary_tools.length > 0, `${snippet.name} must list MCP primary tool(s)`);
  assert(typeof snippet.input_category === 'string' && snippet.input_category.length > 0, `${snippet.name} missing input_category`);
  assert(typeof snippet.output_category === 'string' && snippet.output_category.length > 0, `${snippet.name} missing output_category`);
  assert(Array.isArray(snippet.allowed_mutations), `${snippet.name} allowed_mutations must be an array`);
  assert(Array.isArray(snippet.required_guards) && snippet.required_guards.length > 0, `${snippet.name} must list required guards`);
  assert(Array.isArray(snippet.fallback_conditions) && snippet.fallback_conditions.length > 0, `${snippet.name} must list fallback conditions`);
  assert(allowedRereadModes.has(snippet.post_mutation_reread?.mode), `${snippet.name} has invalid post-mutation re-read mode`);
  assert(typeof snippet.post_mutation_reread.expectation === 'string' && snippet.post_mutation_reread.expectation.length > 0, `${snippet.name} missing post-mutation re-read expectation`);
  if (snippet.allowed_mutations.length > 0) {
    assert(snippet.post_mutation_reread.mode !== 'none', `${snippet.name} allows mutation but has no post-mutation re-read expectation`);
  }
  assert(snippet.via_evidence?.required === true, `${snippet.name} must carry a via evidence requirement`);
  assert(Array.isArray(snippet.via_evidence.tokens), `${snippet.name} via evidence tokens must be an array`);
  assert(snippet.via_evidence.tokens.includes('via=mcp'), `${snippet.name} missing via=mcp evidence token`);
  assert(snippet.via_evidence.tokens.includes('via=glab-fallback'), `${snippet.name} missing via=glab-fallback evidence token`);

  const row = markdownRows.get(snippet.name);
  assert(row, `${snippet.name} missing from ${contractPath}`);
  assert(!Object.hasOwn(snippet, 'markdown'), `${snippet.name} must not reintroduce the retired markdown mirror`);
  for (const cell of markdownCells) {
    assert(row[cell].length > 0, `${snippet.name} has an empty Markdown ${cell} cell in ${contractPath}`);
  }
}

console.log('gitlab-snippet-metadata: PASS');
NODE
