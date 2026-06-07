#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import yaml from 'js-yaml';

const REPO_ROOT = findRepoRoot();
const DIALECTS = new Set(['claude', 'pi']);
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
const PI_ALLOWED_FIELDS = new Set([
  'name',
  'package',
  'description',
  'tools',
  'extensions',
  'model',
  'fallbackModels',
  'thinking',
  'systemPromptMode',
  'inheritProjectContext',
  'inheritSkills',
  'defaultContext',
  'skills',
  'output',
  'defaultReads',
  'defaultProgress',
  'completionGuard',
  'interactive',
  'maxSubagentDepth',
]);
const PI_ONLY_FIELDS = new Set([...PI_ALLOWED_FIELDS].filter((field) => !CLAUDE_ALLOWED_FIELDS.has(field)));
const CLAUDE_ONLY_FIELDS = new Set(['effort', 'color']);

const CLAUDE_MCP_SELECTORS = new Set(['mcp__gitlab-mcp__*', 'mcp__wowtools-mcp__*']);
const PI_MCP_SELECTIONS = new Set(['mcp:gitlab-mcp', 'mcp:wowtools-mcp']);
const ALLOWED_CLAUDE_MCP_SELECTORS = [...CLAUDE_MCP_SELECTORS].join(', ');
const ALLOWED_PI_MCP_SELECTIONS = [...PI_MCP_SELECTIONS].join(', ');

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
const PI_TOOLS = new Set([
  'bash',
  'edit',
  'find',
  'grep',
  'intercom',
  'ls',
  'read',
  'subagent',
  'write',
]);
const PI_TO_CLAUDE_TOOL = new Map([
  ['bash', 'Bash'],
  ['edit', 'Edit'],
  ['glob', 'Glob'],
  ['grep', 'Grep'],
  ['ls', 'LS'],
  ['read', 'Read'],
  ['write', 'Write'],
]);
const CLAUDE_TO_PI_TOOL = new Map([
  ['Bash', 'bash'],
  ['Edit', 'edit'],
  ['Grep', 'grep'],
  ['LS', 'ls'],
  ['Read', 'read'],
  ['Write', 'write'],
]);
const CLAUDE_FORBIDDEN_BODY_TERMS = ['contact_supervisor', 'intercom'];

const diagnostics = [];
const files = collectInputFiles();
const counts = { claude: 0, pi: 0 };

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

console.log(`agents-schema: checked ${counts.claude} Claude agent(s), ${counts.pi} pi agent(s)`);

function findRepoRoot() {
  try {
    return execFileSync('git', ['rev-parse', '--show-toplevel'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return process.cwd();
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
        diagnostics.push(`${displayPath(absolute)}:1: cannot infer agent dialect from path; expected path under agents/claude or agents/pi`);
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
  validateNameMatchesFile(file, data, fieldLines);
  validateTools(file, data, fieldLines);
  validateBody(file, lines, frontmatter.endLine);
}

function extractFrontmatter(file, lines) {
  if (lines[0] !== '---') {
    addDiagnostic(file, 1, 'missing YAML frontmatter fence');
    return null;
  }

  const closingIndex = lines.findIndex((line, index) => index > 0 && line === '---');
  if (closingIndex === -1) {
    addDiagnostic(file, 1, 'missing closing YAML frontmatter fence');
    return null;
  }

  return {
    source: lines.slice(1, closingIndex).join('\n'),
    fieldLines: collectFieldLines(lines.slice(1, closingIndex)),
    endLine: closingIndex + 1,
  };
}

function collectFieldLines(frontmatterLines) {
  const fieldLines = new Map();
  for (let index = 0; index < frontmatterLines.length; index += 1) {
    const match = frontmatterLines[index].match(/^([A-Za-z_][A-Za-z0-9_-]*):/u);
    if (match && !fieldLines.has(match[1])) {
      fieldLines.set(match[1], index + 2);
    }
  }
  return fieldLines;
}

function parseFrontmatter(file, frontmatter) {
  let parsed;
  try {
    parsed = yaml.load(frontmatter.source, { filename: file.display });
  } catch (error) {
    const markLine = Number.isInteger(error?.mark?.line) ? error.mark.line + 2 : 1;
    addDiagnostic(file, markLine, `frontmatter YAML does not parse: ${firstLine(error.message)}`);
    return { data: null, fieldLines: frontmatter.fieldLines };
  }

  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    addDiagnostic(file, 1, 'frontmatter YAML must parse to an object');
    return { data: null, fieldLines: frontmatter.fieldLines };
  }

  return { data: parsed, fieldLines: frontmatter.fieldLines };
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
  const allowed = file.dialect === 'claude' ? CLAUDE_ALLOWED_FIELDS : PI_ALLOWED_FIELDS;

  for (const field of Object.keys(data)) {
    if (file.dialect === 'claude' && PI_ONLY_FIELDS.has(field)) {
      addDiagnostic(file, lineFor(fieldLines, field), `pi-only frontmatter field "${field}" is not allowed in Claude agent`);
      continue;
    }
    if (file.dialect === 'pi' && CLAUDE_ONLY_FIELDS.has(field)) {
      addDiagnostic(file, lineFor(fieldLines, field), `Claude-only frontmatter field "${field}" is not allowed in pi agent`);
      continue;
    }
    if (!allowed.has(field)) {
      addDiagnostic(file, lineFor(fieldLines, field), `frontmatter field "${field}" is not allowed in ${file.dialect} agent schema`);
    }
  }
}

function validateNameMatchesFile(file, data, fieldLines) {
  if (typeof data.name !== 'string' || data.name.length === 0) {
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
      validatePiTool(file, fieldLines, tool);
    }
  }
}

function parseToolsValue(value) {
  if (typeof value === 'string') {
    return { tools: splitList(value) };
  }
  if (Array.isArray(value)) {
    const tools = [];
    for (const item of value) {
      if (typeof item !== 'string') {
        return { error: 'frontmatter field "tools" entries must be strings' };
      }
      tools.push(...splitList(item));
    }
    return { tools };
  }
  return { error: 'frontmatter field "tools" must be a comma-separated string or string list' };
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

  const expected = PI_TO_CLAUDE_TOOL.get(tool);
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

function validatePiTool(file, fieldLines, tool) {
  if (PI_TOOLS.has(tool) || PI_MCP_SELECTIONS.has(tool)) {
    return;
  }

  const expected = CLAUDE_TO_PI_TOOL.get(tool);
  if (expected) {
    addDiagnostic(file, lineFor(fieldLines, 'tools'), `pi tool "${tool}" must use lowercase pi casing "${expected}"`);
    return;
  }

  if (isPiMcpDirectSelection(tool)) {
    addDiagnostic(
      file,
      lineFor(fieldLines, 'tools'),
      `pi MCP selection "${tool}" is not approved; allowed selections: ${ALLOWED_PI_MCP_SELECTIONS}`,
    );
    return;
  }

  addDiagnostic(file, lineFor(fieldLines, 'tools'), `pi tool "${tool}" is not a pi tool`);
}

function isClaudeMcpSelector(tool) {
  return tool === 'mcp' || tool.startsWith('mcp__');
}

function isPiMcpDirectSelection(tool) {
  return tool === 'mcp' || tool.startsWith('mcp:');
}

function validateBody(file, lines, frontmatterEndLine) {
  if (file.dialect !== 'claude') {
    return;
  }

  for (let index = frontmatterEndLine; index < lines.length; index += 1) {
    const line = lines[index];
    for (const term of CLAUDE_FORBIDDEN_BODY_TERMS) {
      if (new RegExp(`\\b${escapeRegExp(term)}\\b`, 'iu').test(line)) {
        addDiagnostic(file, index + 1, `Claude agent body must not contain pi bridge wording "${term}"`);
      }
    }
    if (/^##\s+Supervisor coordination/iu.test(line)) {
      addDiagnostic(file, index + 1, 'Claude agent body must not contain pi bridge wording "Supervisor coordination"');
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
