#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import yaml from 'js-yaml';

const REPO_ROOT = findRepoRoot();
const DIALECTS = new Set(['claude', 'omp']);
const REQUIRED_FIELDS = ['name', 'description', 'tools'];

const CLAUDE_ALLOWED_FIELDS = new Set([
  'name',
  'description',
  'tools',
  'skills',
  'model',
  'effort',
  'color',
]);
const OMP_ALLOWED_FIELDS = new Set([
  'name',
  'description',
  'tools',
  'spawns',
  'model',
  'thinking-level',
  'autoload-skills',
  'output',
  'read-summarize',
  'blocking',
]);
const OMP_ONLY_FIELDS = new Set([...OMP_ALLOWED_FIELDS].filter((field) => !CLAUDE_ALLOWED_FIELDS.has(field)));
const CLAUDE_ONLY_FIELDS = new Set(['effort', 'color', 'skills']);
const OMP_CANONICAL_FIELD_REPLACEMENTS = new Map([
  ['thinkingLevel', 'thinking-level'],
  ['autoloadSkills', 'autoload-skills'],
  ['readSummarize', 'read-summarize'],
]);
const RETIRED_PI_FIELDS = new Set([
  'package',
  'extensions',
  'fallbackModels',
  'thinking',
  'systemPromptMode',
  'inheritProjectContext',
  'inheritSkills',
  'defaultContext',
  'defaultReads',
  'defaultProgress',
  'completionGuard',
  'interactive',
  'maxSubagentDepth',
]);

const CLAUDE_MCP_SELECTORS = new Set(['mcp__gitlab-mcp__*', 'mcp__wowtools__*']);
const ALLOWED_CLAUDE_MCP_SELECTORS = [...CLAUDE_MCP_SELECTORS].join(', ');

const OMP_MCP_TOOLS = new Set([
  'mcp__gitlab_mcp_get_project',
  'mcp__gitlab_mcp_get_current_user',
  'mcp__gitlab_mcp_list_issues',
  'mcp__gitlab_mcp_get_issue',
  'mcp__gitlab_mcp_get_issue_discussions',
  'mcp__gitlab_mcp_create_issue_note',
  'mcp__gitlab_mcp_update_issue',
  'mcp__gitlab_mcp_list_merge_requests',
  'mcp__gitlab_mcp_get_merge_request',
  'mcp__gitlab_mcp_get_merge_request_discussions',
  'mcp__gitlab_mcp_get_merge_request_changes',
  'mcp__gitlab_mcp_get_merge_request_approvals',
  'mcp__gitlab_mcp_create_merge_request',
  'mcp__gitlab_mcp_update_merge_request',
  'mcp__gitlab_mcp_create_merge_request_note',
  'mcp__gitlab_mcp_approve_merge_request',
  'mcp__gitlab_mcp_merge_merge_request',
  'mcp__gitlab_mcp_list_pipelines',
  'mcp__gitlab_mcp_get_pipeline_jobs',
  'mcp__gitlab_mcp_list_branches',
  'mcp__gitlab_mcp_delete_branch',
  'mcp__gitlab_mcp_trigger_pipeline',
  'mcp__gitlab_mcp_search_repositories',
  'mcp__gitlab_mcp_create_issue',
  'mcp__gitlab_mcp_create_repository',
  'mcp__gitlab_mcp_push_files',
  'mcp__gitlab_mcp_create_or_update_file',
  'mcp__gitlab_mcp_create_branch',
  'mcp__gitlab_mcp_get_file_contents',
  'mcp__gitlab_mcp_fork_repository',
  'mcp__wowtools_get_active_build',
  'mcp__wowtools_list_tables',
  'mcp__wowtools_query_table',
  'mcp__wowtools_get_rows',
  'mcp__wowtools_get_table_schema',
]);
const ALLOWED_OMP_MCP_TOOLS = [...OMP_MCP_TOOLS].join(', ');

const CLAUDE_MODELS = new Set(['inherit', 'opus', 'sonnet', 'haiku', 'claude-opus-4-8', 'claude-sonnet-4-6']);
const OMP_MODEL_PROVIDER_PREFIXES = ['anthropic/', 'openai-codex/', 'pi/'];
const ALLOWED_CLAUDE_MODELS = [...CLAUDE_MODELS].join(', ');
const ALLOWED_OMP_MODEL_PREFIXES = OMP_MODEL_PROVIDER_PREFIXES.join(', ');

const OMP_THINKING_LEVELS = new Set(['inherit', 'off', 'minimal', 'low', 'medium', 'high', 'xhigh']);
const ALLOWED_OMP_THINKING_LEVELS = [...OMP_THINKING_LEVELS].join(', ');

const CLAUDE_TOOLS = new Set([
  'AskUserQuestion',
  'Bash',
  'Edit',
  'Glob',
  'Grep',
  'LS',
  'MultiEdit',
  'NotebookEdit',
  'Read',
  'Skill',
  'Task',
  'TodoWrite',
  'WebFetch',
  'WebSearch',
  'Write',
]);
const OMP_TOOLS = new Set([
  'ask',
  'ast_edit',
  'ast_grep',
  'bash',
  'browser',
  'edit',
  'eval',
  'find',
  'inspect_image',
  'irc',
  'lsp',
  'read',
  'search',
  'task',
  'todo',
  'web_search',
  'write',
  'yield',
]);
const OMP_TO_CLAUDE_TOOL = new Map([
  ['ask', 'AskUserQuestion'],
  ['bash', 'Bash'],
  ['edit', 'Edit'],
  ['find', 'Glob'],
  ['search', 'Grep'],
  ['read', 'Read'],
  ['task', 'Task'],
  ['todo', 'TodoWrite'],
  ['web_search', 'WebSearch'],
  ['write', 'Write'],
]);
const CLAUDE_TO_OMP_TOOL = new Map([
  ['AskUserQuestion', 'ask'],
  ['Bash', 'bash'],
  ['Edit', 'edit'],
  ['Glob', 'find'],
  ['Grep', 'search'],
  ['LS', 'directory reads via read'],
  ['Read', 'read'],
  ['Task', 'task'],
  ['TodoWrite', 'todo'],
  ['WebSearch', 'web_search'],
  ['Write', 'write'],
]);
const OMP_RETIRED_TOOL_REPLACEMENTS = new Map([
  ['grep', 'search'],
  ['ls', 'directory reads via read'],
  ['intercom', 'irc'],
]);
const NON_PI_FORBIDDEN_BODY_TERMS = ['contact_supervisor', 'intercom'];

const diagnostics = [];
const files = collectInputFiles();
const counts = { claude: 0, omp: 0 };

for (const file of files) {
  counts[file.dialect] += 1;
  validateAgent(file);
}

if (diagnostics.length > 0) {
  for (const diagnostic of diagnostics) {
    console.error(diagnostic);
  }
  process.exit(1);
}

console.log(`agents-schema: checked ${counts.claude} Claude agent(s), ${counts.omp} OMP agent(s)`);

function findRepoRoot() {
  try {
    return execFileSync('git', ['rev-parse', '--show-toplevel'], { encoding: 'utf8' }).trim();
  } catch {
    return path.resolve(path.join(path.dirname(new URL(import.meta.url).pathname), '..'));
  }
}

function collectInputFiles() {
  const targets = process.argv.slice(2);
  const roots = targets.length > 0 ? targets : [path.join(REPO_ROOT, 'agents')];
  const collected = [];

  for (const target of roots) {
    const absolute = path.resolve(target);
    if (!fs.existsSync(absolute)) {
      diagnostics.push(`${displayPath(absolute)}:1: target does not exist`);
      continue;
    }

    const stat = fs.statSync(absolute);
    if (stat.isFile()) {
      const dialect = inferDialect(absolute);
      if (dialect) {
        collected.push(agentFile(absolute, dialect));
      } else {
        diagnostics.push(`${displayPath(absolute)}:1: cannot infer agent dialect from path; expected path under agents/claude or agents/omp`);
      }
      continue;
    }

    if (!stat.isDirectory()) {
      diagnostics.push(`${displayPath(absolute)}:1: target is not a file or directory`);
      continue;
    }

    const base = path.basename(absolute);
    if (DIALECTS.has(base)) {
      collected.push(...markdownFiles(absolute).map((file) => agentFile(file, base)));
      continue;
    }

    for (const dialect of DIALECTS) {
      const dialectDir = path.join(absolute, dialect);
      if (fs.existsSync(dialectDir) && fs.statSync(dialectDir).isDirectory()) {
        collected.push(...markdownFiles(dialectDir).map((file) => agentFile(file, dialect)));
      }
    }
  }

  return collected.sort((left, right) => left.absolute.localeCompare(right.absolute));
}

function markdownFiles(dir) {
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith('.md'))
    .map((entry) => path.join(dir, entry.name));
}

function agentFile(absolute, dialect) {
  return {
    absolute,
    dialect,
    display: displayPath(absolute),
  };
}

function inferDialect(file) {
  const parts = file.split(path.sep);
  for (const dialect of DIALECTS) {
    if (parts.includes(dialect)) {
      return dialect;
    }
  }
  return null;
}

function displayPath(file) {
  const relative = path.relative(REPO_ROOT, file);
  return relative && !relative.startsWith('..') && !path.isAbsolute(relative) ? normalizePath(relative) : normalizePath(file);
}

function normalizePath(file) {
  return file.split(path.sep).join('/');
}

function validateAgent(file) {
  const content = fs.readFileSync(file.absolute, 'utf8');
  const lines = content.split(/\r?\n/);
  const frontmatter = extractFrontmatter(file, lines);
  if (!frontmatter) {
    return;
  }

  const { data, fieldLines } = parseFrontmatter(file, frontmatter);
  if (!data) {
    return;
  }

  validateRequiredFields(file, data, fieldLines);
  validateDialectFields(file, data, fieldLines);
  validateModel(file, data, fieldLines);
  validateOmpSemanticFields(file, data, fieldLines);
  validateNameMatchesFile(file, data, fieldLines);
  validateTools(file, data, fieldLines);
  validateBody(file, lines, frontmatter.endLine);
}

function extractFrontmatter(file, lines) {
  if (lines[0] !== '---') {
    addDiagnostic(file, 1, 'missing YAML frontmatter fence');
    return null;
  }

  for (let index = 1; index < lines.length; index += 1) {
    if (lines[index] === '---') {
      return {
        source: lines.slice(1, index).join('\n'),
        endLine: index + 1,
      };
    }
  }

  addDiagnostic(file, 1, 'unterminated YAML frontmatter fence');
  return null;
}

function collectFieldLines(frontmatterLines) {
  const fieldLines = new Map();
  frontmatterLines.forEach((line, index) => {
    const match = /^([A-Za-z0-9_-]+):/.exec(line);
    if (match && !fieldLines.has(match[1])) {
      fieldLines.set(match[1], index + 2);
    }
  });
  return fieldLines;
}

function parseFrontmatter(file, frontmatter) {
  const fieldLines = collectFieldLines(frontmatter.source.split('\n'));
  try {
    const data = yaml.load(frontmatter.source) ?? {};
    if (typeof data !== 'object' || Array.isArray(data)) {
      addDiagnostic(file, 1, 'frontmatter must be a YAML mapping');
      return { data: null, fieldLines };
    }
    return { data, fieldLines };
  } catch (error) {
    addDiagnostic(file, 1, `frontmatter YAML does not parse: ${firstLine(error.message)}`);
    return { data: null, fieldLines };
  }
}

function firstLine(value) {
  return String(value).split('\n')[0];
}

function validateRequiredFields(file, data, fieldLines) {
  for (const field of REQUIRED_FIELDS) {
    if (!Object.hasOwn(data, field) || data[field] === null || data[field] === '') {
      addDiagnostic(file, lineFor(fieldLines, field), `missing required frontmatter field: ${field}`);
    }
  }

  for (const field of ['name', 'description']) {
    if (Object.hasOwn(data, field) && typeof data[field] !== 'string') {
      addDiagnostic(file, lineFor(fieldLines, field), `frontmatter field "${field}" must be a string`);
    }
  }
}

function validateDialectFields(file, data, fieldLines) {
  const allowed = file.dialect === 'claude' ? CLAUDE_ALLOWED_FIELDS : OMP_ALLOWED_FIELDS;

  for (const field of Object.keys(data)) {
    if (file.dialect === 'claude' && OMP_ONLY_FIELDS.has(field)) {
      addDiagnostic(file, lineFor(fieldLines, field), `OMP-only frontmatter field "${field}" is not allowed in Claude agent`);
      continue;
    }
    if (file.dialect === 'omp') {
      if (OMP_CANONICAL_FIELD_REPLACEMENTS.has(field)) {
        addDiagnostic(file, lineFor(fieldLines, field), `OMP frontmatter field "${field}" must use canonical key "${OMP_CANONICAL_FIELD_REPLACEMENTS.get(field)}"`);
        continue;
      }
      if (CLAUDE_ONLY_FIELDS.has(field)) {
        addDiagnostic(file, lineFor(fieldLines, field), `Claude-only frontmatter field "${field}" is not allowed in OMP agent`);
        continue;
      }
      if (RETIRED_PI_FIELDS.has(field)) {
        addDiagnostic(file, lineFor(fieldLines, field), `retired Pi frontmatter field "${field}" is not allowed in OMP agent`);
        continue;
      }
    }
    if (!allowed.has(field)) {
      addDiagnostic(file, lineFor(fieldLines, field), `frontmatter field "${field}" is not allowed in ${file.dialect} agent schema`);
    }
  }
}

function validateModel(file, data, fieldLines) {
  if (!Object.hasOwn(data, 'model')) {
    return;
  }

  const models = Array.isArray(data.model) ? data.model : [data.model];
  if (models.length === 0) {
    addDiagnostic(file, lineFor(fieldLines, 'model'), 'frontmatter field "model" must be a non-empty string or string list');
    return;
  }

  for (const model of models) {
    if (typeof model !== 'string' || model.length === 0) {
      addDiagnostic(file, lineFor(fieldLines, 'model'), 'frontmatter field "model" must be a non-empty string or string list');
      continue;
    }

    if (file.dialect === 'claude') {
      if (!CLAUDE_MODELS.has(model)) {
        addDiagnostic(
          file,
          lineFor(fieldLines, 'model'),
          `Claude model "${model}" is not approved; allowed models: ${ALLOWED_CLAUDE_MODELS}`,
        );
      }
      continue;
    }

    if (!OMP_MODEL_PROVIDER_PREFIXES.some((prefix) => model.length > prefix.length && model.startsWith(prefix))) {
      addDiagnostic(
        file,
        lineFor(fieldLines, 'model'),
        `OMP model "${model}" is not an approved route; allowed provider prefixes: ${ALLOWED_OMP_MODEL_PREFIXES}`,
      );
    }
  }
}

function validateOmpSemanticFields(file, data, fieldLines) {
  if (file.dialect !== 'omp') {
    return;
  }

  if (Object.hasOwn(data, 'thinking-level')) {
    const value = data['thinking-level'];
    if (typeof value !== 'string' || !OMP_THINKING_LEVELS.has(value)) {
      addDiagnostic(file, lineFor(fieldLines, 'thinking-level'), `OMP thinking-level "${value}" is not a valid value; allowed: ${ALLOWED_OMP_THINKING_LEVELS}`);
    }
  }

  if (Object.hasOwn(data, 'autoload-skills')) {
    const result = parseStringListValue(data['autoload-skills'], 'autoload-skills');
    if (result.error) {
      addDiagnostic(file, lineFor(fieldLines, 'autoload-skills'), result.error);
    } else if (result.values.length === 0) {
      addDiagnostic(file, lineFor(fieldLines, 'autoload-skills'), 'frontmatter field "autoload-skills" must list at least one skill when present');
    }
  }

  for (const field of ['blocking', 'read-summarize']) {
    if (Object.hasOwn(data, field) && typeof data[field] !== 'boolean' && data[field] !== 'true' && data[field] !== 'false') {
      addDiagnostic(file, lineFor(fieldLines, field), `OMP frontmatter field "${field}" must be boolean true/false`);
    }
  }
}

function validateNameMatchesFile(file, data, fieldLines) {
  if (typeof data.name !== 'string') {
    return;
  }

  const expected = path.basename(file.absolute, '.md');
  if (data.name !== expected) {
    addDiagnostic(file, lineFor(fieldLines, 'name'), `frontmatter name "${data.name}" does not match file name "${expected}"`);
  }
}

function validateTools(file, data, fieldLines) {
  if (!Object.hasOwn(data, 'tools')) {
    return;
  }

  const result = parseToolsValue(data.tools);
  if (result.error) {
    addDiagnostic(file, lineFor(fieldLines, 'tools'), result.error);
    return;
  }
  if (result.tools.length === 0) {
    addDiagnostic(file, lineFor(fieldLines, 'tools'), 'frontmatter field "tools" must list at least one tool');
    return;
  }

  for (const tool of result.tools) {
    if (file.dialect === 'claude') {
      validateClaudeTool(file, fieldLines, tool);
    } else {
      validateOmpTool(file, fieldLines, tool);
    }
  }
}

function parseToolsValue(value) {
  const result = parseStringListValue(value, 'tools');
  if (result.error) {
    return { error: result.error.replace('string list', 'comma-separated string or string list') };
  }
  return { tools: result.values };
}

function parseStringListValue(value, field) {
  if (typeof value === 'string') {
    return { values: splitList(value) };
  }
  if (Array.isArray(value)) {
    const values = [];
    for (const item of value) {
      if (typeof item !== 'string') {
        return { error: `frontmatter field "${field}" entries must be strings` };
      }
      values.push(...splitList(item));
    }
    return { values };
  }
  return { error: `frontmatter field "${field}" must be a string list` };
}

function splitList(value) {
  return value
    .split(',')
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function validateClaudeTool(file, fieldLines, tool) {
  if (CLAUDE_TOOLS.has(tool) || CLAUDE_MCP_SELECTORS.has(tool)) {
    return;
  }

  const expected = OMP_TO_CLAUDE_TOOL.get(tool);
  if (expected) {
    addDiagnostic(file, lineFor(fieldLines, 'tools'), `Claude tool "${tool}" must use Claude Code casing "${expected}"`);
    return;
  }

  if (isClaudeMcpSelector(tool)) {
    addDiagnostic(
      file,
      lineFor(fieldLines, 'tools'),
      `Claude MCP selector "${tool}" is not approved; allowed selectors: ${ALLOWED_CLAUDE_MCP_SELECTORS}`,
    );
    return;
  }

  addDiagnostic(file, lineFor(fieldLines, 'tools'), `Claude tool "${tool}" is not a Claude Code tool`);
}

function validateOmpTool(file, fieldLines, tool) {
  if (OMP_TOOLS.has(tool) || OMP_MCP_TOOLS.has(tool)) {
    return;
  }

  const retiredExpected = OMP_RETIRED_TOOL_REPLACEMENTS.get(tool);
  if (retiredExpected) {
    addDiagnostic(file, lineFor(fieldLines, 'tools'), `OMP tool "${tool}" must use OMP-native tool "${retiredExpected}"`);
    return;
  }

  const expected = CLAUDE_TO_OMP_TOOL.get(tool);
  if (expected) {
    addDiagnostic(file, lineFor(fieldLines, 'tools'), `OMP tool "${tool}" must use OMP tool name "${expected}"`);
    return;
  }

  if (isOmpMcpTool(tool)) {
    addDiagnostic(
      file,
      lineFor(fieldLines, 'tools'),
      `OMP MCP tool "${tool}" is not approved; allowed tools: ${ALLOWED_OMP_MCP_TOOLS}`,
    );
    return;
  }

  if (tool === 'mcp' || tool.startsWith('mcp:')) {
    addDiagnostic(file, lineFor(fieldLines, 'tools'), `OMP MCP tool "${tool}" must use runtime-real mcp__ server tool names`);
    return;
  }

  addDiagnostic(file, lineFor(fieldLines, 'tools'), `OMP tool "${tool}" is not an OMP tool`);
}

function isClaudeMcpSelector(tool) {
  return tool === 'mcp' || tool.startsWith('mcp__');
}

function isOmpMcpTool(tool) {
  return tool === 'mcp' || tool.startsWith('mcp__');
}

function validateBody(file, lines, frontmatterEndLine) {
  for (let index = frontmatterEndLine; index < lines.length; index += 1) {
    const line = lines[index];
    for (const term of NON_PI_FORBIDDEN_BODY_TERMS) {
      if (new RegExp(`\\b${escapeRegExp(term)}\\b`, 'iu').test(line)) {
        addDiagnostic(file, index + 1, `${file.dialect} agent body must not contain retired Pi bridge wording "${term}"`);
      }
    }
    if (/^##\s+Supervisor coordination/iu.test(line)) {
      addDiagnostic(file, index + 1, `${file.dialect} agent body must not contain retired Pi bridge wording "Supervisor coordination"`);
    }
  }
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/gu, '\\$&');
}

function lineFor(fieldLines, field) {
  return fieldLines.get(field) ?? 1;
}

function addDiagnostic(file, line, message) {
  diagnostics.push(`${file.display}:${line}: ${message}`);
}
