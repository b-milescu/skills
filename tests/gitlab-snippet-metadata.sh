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

function parseMarkdownRows(markdown) {
  const rows = new Map();
  for (const line of markdown.split(/\r?\n/)) {
    if (!line.startsWith('| `')) continue;
    const cells = line.split('|').slice(1, -1).map((cell) => cell.trim());
    assert(cells.length === 7, `transport row does not have 7 cells: ${line}`);
    const nameMatch = cells[0].match(/^`([^`]+)`$/);
    assert(nameMatch, `transport row has invalid snippet cell: ${line}`);
    rows.set(nameMatch[1], {
      mcp_primary_tools: cells[1],
      inputs: cells[2],
      outputs: cells[3],
      required_guards: cells[4],
      fallback_conditions: cells[5],
      post_mutation_reread: cells[6]
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
  'markdown'
]) {
  assert(requiredSnippetFields.includes(field), `required snippet field inventory missing ${field}`);
}

const snippets = metadata.snippets;
assert(Array.isArray(snippets), 'metadata snippets must be an array');
sameList('metadata stable snippet names', snippets.map((snippet) => snippet.name), expectedNames);
assert(new Set(snippets.map((snippet) => snippet.name)).size === snippets.length, 'metadata snippet names must be unique');

const skillSnippetNames = [...skill.matchAll(/^### Snippet: ([^\r\n]+)$/gm)].map((match) => match[1]);
sameList('SKILL stable snippet names', skillSnippetNames, expectedNames);

const markdownRows = parseMarkdownRows(contract);
sameList('Markdown stable snippet names', [...markdownRows.keys()], expectedNames);

const allowedRereadModes = new Set(['none', 'conditional', 'required']);
const markdownFields = [
  'mcp_primary_tools',
  'inputs',
  'outputs',
  'required_guards',
  'fallback_conditions',
  'post_mutation_reread'
];

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
  for (const field of markdownFields) {
    assert(typeof snippet.markdown[field] === 'string', `${snippet.name} metadata markdown.${field} missing`);
    if (row[field] !== snippet.markdown[field]) {
      fail(`${snippet.name} Markdown ${field} disagrees with metadata\nmarkdown: ${row[field]}\nmetadata: ${snippet.markdown[field]}`);
    }
  }
}

console.log('gitlab-snippet-metadata: PASS');
NODE
