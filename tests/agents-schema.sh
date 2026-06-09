#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/good/agents/claude" "$TMPDIR/good/agents/pi"
cat > "$TMPDIR/good/agents/claude/mr-worker.md" <<'MD'
---
name: mr-worker
description: Claude worker fixture
tools: "Bash, Read, Edit, Write, Grep, Glob, Skill, TodoWrite, AskUserQuestion, mcp__gitlab-mcp__*, mcp__wowtools-mcp__*"
skills: start-build, tdd, gitlab-local
model: inherit
effort: high
color: blue
---

Claude body without bridge-only wording.
MD

cat > "$TMPDIR/good/agents/pi/mr-worker.md" <<'MD'
---
name: mr-worker
description: pi worker fixture
tools: "read, bash, edit, write, intercom, mcp:gitlab-mcp, mcp:wowtools-mcp"
thinking: high
systemPromptMode: replace
inheritProjectContext: true
inheritSkills: true
defaultContext: fresh
---

Pi body may mention contact_supervisor for bridge coordination.
MD

mkdir -p "$TMPDIR/bad/agents/claude" "$TMPDIR/bad/agents/pi"
cat > "$TMPDIR/bad/agents/claude/wrong-name.md" <<'MD'
---
name: other-name
description: Claude bad fixture
tools: bash, intercom
thinking: high
---

Claude body mentions contact_supervisor and intercom.
MD

cat > "$TMPDIR/bad/agents/claude/mr-reviewer.md" <<'MD'
---
name: mr-reviewer
description: Claude MCP bad fixture
tools: "Bash, mcp__, mcp__github__*, mcp__*"
---

Claude MCP selectors must stay on the approved server scopes.
MD

cat > "$TMPDIR/bad/agents/claude/missing-description.md" <<'MD'
---
name: missing-description
tools: Bash
---

Missing description fixture.
MD

cat > "$TMPDIR/bad/agents/pi/wrong-tools.md" <<'MD'
---
name: wrong-tools
description: pi bad fixture
tools: "Bash, Read, mcp:"
effort: high
color: green
---

Pi bad fixture.
MD

cat > "$TMPDIR/bad/agents/pi/mr-builder.md" <<'MD'
---
name: mr-builder
description: pi MCP bad fixture
tools: "read, mcp, mcp:chrome-devtools"
---

Pi MR agents must not use bare or non-approved MCP selections.
MD

cat > "$TMPDIR/bad/agents/pi/bad-yaml.md" <<'MD'
---
name: [bad
description: parse failure fixture
tools: read
---

YAML should fail.
MD

cat > "$TMPDIR/bad/agents/claude/claude-bad-anthropic.md" <<'MD'
---
name: claude-bad-anthropic
description: Claude provider-prefixed model fixture
tools: Bash, Read
model: anthropic/claude-opus-4-8
---

Claude body without bridge wording.
MD

cat > "$TMPDIR/bad/agents/claude/claude-bad-codex.md" <<'MD'
---
name: claude-bad-codex
description: Claude codex-routed model fixture
tools: Bash, Read
model: openai-codex/gpt-5.5
---

Claude body without bridge wording.
MD

cat > "$TMPDIR/bad/agents/claude/claude-typo-model.md" <<'MD'
---
name: claude-typo-model
description: Claude typo model fixture
tools: Bash, Read
model: claude-opus-4-99
---

Claude body without bridge wording.
MD

cat > "$TMPDIR/bad/agents/pi/pi-bare-model.md" <<'MD'
---
name: pi-bare-model
description: pi bare model fixture
tools: read, bash
model: claude-opus-4-8
---

Pi body.
MD

cat > "$TMPDIR/bad/agents/pi/pi-bad-systempromptmode.md" <<'MD'
---
name: pi-bad-systempromptmode
description: pi invalid systemPromptMode fixture
tools: "read, bash"
systemPromptMode: rewrite
---

Pi body.
MD

cat > "$TMPDIR/bad/agents/pi/pi-bad-defaultcontext.md" <<'MD'
---
name: pi-bad-defaultcontext
description: pi invalid defaultContext fixture
tools: "read, bash"
defaultContext: shared
---

Pi body.
MD

cat > "$TMPDIR/bad/agents/pi/pi-bad-inheritskills.md" <<'MD'
---
name: pi-bad-inheritskills
description: pi uppercase boolean fixture
tools: "read, bash"
inheritSkills: TRUE
---

Pi body.
MD

cat > "$TMPDIR/bad/agents/pi/pi-bad-inheritprojectcontext.md" <<'MD'
---
name: pi-bad-inheritprojectcontext
description: pi capitalized boolean fixture
tools: "read, bash"
inheritProjectContext: False
---

Pi body.
MD

cat > "$TMPDIR/bad/agents/pi/pi-bad-completionguard.md" <<'MD'
---
name: pi-bad-completionguard
description: pi yes-boolean fixture
tools: "read, bash"
completionGuard: yes
---

Pi body.
MD

cat > "$TMPDIR/bad/agents/pi/pi-bad-maxsubagentdepth-negative.md" <<'MD'
---
name: pi-bad-maxsubagentdepth-negative
description: pi negative depth fixture
tools: "read, bash"
maxSubagentDepth: -1
---

Pi body.
MD

cat > "$TMPDIR/bad/agents/pi/pi-bad-maxsubagentdepth-float.md" <<'MD'
---
name: pi-bad-maxsubagentdepth-float
description: pi non-integer depth fixture
tools: "read, bash"
maxSubagentDepth: 2.5
---

Pi body.
MD

set +e
output="$(node "$REPO_ROOT/scripts/check-agent-schemas.mjs" "$TMPDIR/bad/agents" 2>&1)"
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "expected agent schema validator to fail for bad fixtures" >&2
  exit 1
fi

for expected in \
  "frontmatter name \"other-name\" does not match file name \"wrong-name\"" \
  "pi-only frontmatter field \"thinking\" is not allowed in Claude agent" \
  "Claude tool \"bash\" must use Claude Code casing \"Bash\"" \
  "Claude tool \"intercom\" is not a Claude Code tool" \
  "Claude agent body must not contain pi bridge wording \"contact_supervisor\"" \
  "Claude agent body must not contain pi bridge wording \"intercom\"" \
  "missing required frontmatter field: description" \
  "Claude-only frontmatter field \"effort\" is not allowed in pi agent" \
  "Claude-only frontmatter field \"color\" is not allowed in pi agent" \
  "pi tool \"Bash\" must use lowercase pi casing \"bash\"" \
  "pi tool \"Read\" must use lowercase pi casing \"read\"" \
  "pi MCP selection \"mcp:\" is not approved; allowed selections: mcp:gitlab-mcp, mcp:wowtools-mcp" \
  "Claude MCP selector \"mcp__\" is not approved; allowed selectors: mcp__gitlab-mcp__*, mcp__wowtools-mcp__*" \
  "Claude MCP selector \"mcp__github__*\" is not approved; allowed selectors: mcp__gitlab-mcp__*, mcp__wowtools-mcp__*" \
  "Claude MCP selector \"mcp__*\" is not approved; allowed selectors: mcp__gitlab-mcp__*, mcp__wowtools-mcp__*" \
  "pi MCP selection \"mcp\" is not approved; allowed selections: mcp:gitlab-mcp, mcp:wowtools-mcp" \
  "pi MCP selection \"mcp:chrome-devtools\" is not approved; allowed selections: mcp:gitlab-mcp, mcp:wowtools-mcp" \
  "Claude model \"anthropic/claude-opus-4-8\" is not approved; allowed models: inherit, opus, sonnet, haiku, claude-opus-4-8, claude-sonnet-4-6" \
  "Claude model \"openai-codex/gpt-5.5\" is not approved; allowed models: inherit, opus, sonnet, haiku, claude-opus-4-8, claude-sonnet-4-6" \
  "Claude model \"claude-opus-4-99\" is not approved; allowed models: inherit, opus, sonnet, haiku, claude-opus-4-8, claude-sonnet-4-6" \
  "pi model \"claude-opus-4-8\" is not an approved route; allowed provider prefixes: anthropic/, openai-codex/" \
  "pi systemPromptMode \"rewrite\" is not a valid value; allowed: \"append\" or \"replace\"" \
  "pi defaultContext \"shared\" is not a valid value; allowed: \"fresh\" or \"fork\"" \
  "pi inheritSkills \"TRUE\" is not a valid value; allowed: lowercase \"true\" or \"false\"" \
  "pi inheritProjectContext \"False\" is not a valid value; allowed: lowercase \"true\" or \"false\"" \
  "pi completionGuard \"yes\" is not a valid value; allowed: lowercase \"true\" or \"false\"" \
  "pi maxSubagentDepth \"-1\" is not a valid value; must be an integer >= 0" \
  "pi maxSubagentDepth \"2.5\" is not a valid value; must be an integer >= 0" \
  "frontmatter YAML does not parse"; do
  if [[ "$output" != *"$expected"* ]]; then
    echo "missing expected diagnostic: $expected" >&2
    echo "--- output ---" >&2
    printf '%s\n' "$output" >&2
    exit 1
  fi
done

clean_output="$(node "$REPO_ROOT/scripts/check-agent-schemas.mjs" "$TMPDIR/good/agents")"
if [[ "$clean_output" != "agents-schema: checked 1 Claude agent(s), 1 pi agent(s)" ]]; then
  echo "unexpected clean output" >&2
  printf '%s\n' "$clean_output" >&2
  exit 1
fi

mkdir -p "$TMPDIR/good-models/agents/claude" "$TMPDIR/good-models/agents/pi"
cat > "$TMPDIR/good-models/agents/claude/model-inherit.md" <<'MD'
---
name: model-inherit
description: Claude inherit model fixture
tools: Bash, Read
model: inherit
---

Claude body.
MD

cat > "$TMPDIR/good-models/agents/claude/model-alias-opus.md" <<'MD'
---
name: model-alias-opus
description: Claude opus alias fixture
tools: Bash, Read
model: opus
---

Claude body.
MD

cat > "$TMPDIR/good-models/agents/claude/model-alias-sonnet.md" <<'MD'
---
name: model-alias-sonnet
description: Claude sonnet alias fixture
tools: Bash, Read
model: sonnet
---

Claude body.
MD

cat > "$TMPDIR/good-models/agents/claude/model-alias-haiku.md" <<'MD'
---
name: model-alias-haiku
description: Claude haiku alias fixture
tools: Bash, Read
model: haiku
---

Claude body.
MD

cat > "$TMPDIR/good-models/agents/claude/model-bare-opus.md" <<'MD'
---
name: model-bare-opus
description: Claude bare opus id fixture
tools: Bash, Read
model: claude-opus-4-8
---

Claude body.
MD

cat > "$TMPDIR/good-models/agents/claude/model-bare-sonnet.md" <<'MD'
---
name: model-bare-sonnet
description: Claude bare sonnet id fixture
tools: Bash, Read
model: claude-sonnet-4-6
---

Claude body.
MD

cat > "$TMPDIR/good-models/agents/pi/model-anthropic.md" <<'MD'
---
name: model-anthropic
description: pi anthropic route fixture
tools: read, bash
model: anthropic/claude-opus-4-8
---

Pi body.
MD

cat > "$TMPDIR/good-models/agents/pi/model-codex.md" <<'MD'
---
name: model-codex
description: pi codex route fixture
tools: read, bash
model: openai-codex/gpt-5.5
---

Pi body.
MD

cat > "$TMPDIR/good-models/agents/pi/model-absent.md" <<'MD'
---
name: model-absent
description: pi fixture without model field
tools: read, bash
---

Pi body.
MD

models_output="$(node "$REPO_ROOT/scripts/check-agent-schemas.mjs" "$TMPDIR/good-models/agents")"
if [[ "$models_output" != "agents-schema: checked 6 Claude agent(s), 3 pi agent(s)" ]]; then
  echo "unexpected good-models output" >&2
  printf '%s\n' "$models_output" >&2
  exit 1
fi

mkdir -p "$TMPDIR/good-pi-semantics/agents/pi"
cat > "$TMPDIR/good-pi-semantics/agents/pi/pi-semantics-quoted.md" <<'MD'
---
name: pi-semantics-quoted
description: pi accepted quoted semantic values fixture
tools: "read, bash"
systemPromptMode: "append"
defaultContext: "fork"
inheritProjectContext: "true"
inheritSkills: "false"
completionGuard: "true"
maxSubagentDepth: "3"
---

Pi body.
MD

cat > "$TMPDIR/good-pi-semantics/agents/pi/pi-semantics-unquoted.md" <<'MD'
---
name: pi-semantics-unquoted
description: pi accepted unquoted semantic values fixture
tools: "read, bash"
systemPromptMode: replace
defaultContext: fresh
inheritProjectContext: false
inheritSkills: true
completionGuard: false
maxSubagentDepth: 0
---

Pi body.
MD

semantics_output="$(node "$REPO_ROOT/scripts/check-agent-schemas.mjs" "$TMPDIR/good-pi-semantics/agents")"
if [[ "$semantics_output" != "agents-schema: checked 0 Claude agent(s), 2 pi agent(s)" ]]; then
  echo "unexpected good-pi-semantics output" >&2
  printf '%s\n' "$semantics_output" >&2
  exit 1
fi

REPO_ROOT_PATH="$REPO_ROOT" node --input-type=module <<'NODE'
import fs from 'node:fs';
import path from 'node:path';
import yaml from 'js-yaml';

const repoRoot = process.env.REPO_ROOT_PATH;
// Routed agents present in both runtime dialects. The same model is expressed
// per dialect: Claude Code sub-agent frontmatter takes a bare model id, while pi
// routes through LiteLLM and takes the provider-prefixed anthropic/ form.
const dualDialectRoutedAgents = [
  ['mr-builder-sonnet-low', { claude: 'claude-sonnet-4-6', pi: 'anthropic/claude-sonnet-4-6' }, 'low'],
  ['mr-builder-opus48', { claude: 'claude-opus-4-8', pi: 'anthropic/claude-opus-4-8' }, 'medium'],
  ['mr-builder-opus48-high', { claude: 'claude-opus-4-8', pi: 'anthropic/claude-opus-4-8' }, 'high'],
  ['mr-reviewer-opus48-xhigh', { claude: 'claude-opus-4-8', pi: 'anthropic/claude-opus-4-8' }, 'xhigh'],
];

// GPT-routed agents exist only in the pi dialect: Claude Code has no
// openai-codex/* route, so these files must not exist under agents/claude.
const piOnlyRoutedAgents = [
  ['mr-reviewer-gpt55-xhigh', 'openai-codex/gpt-5.5', 'xhigh'],
  ['mr-review-scout-gpt54-low', 'openai-codex/gpt-5.4', 'low'],
];

function fail(file, message) {
  console.error(`${file}: ${message}`);
  process.exit(1);
}

function agentPath(dialect, name) {
  return path.join(repoRoot, `agents/${dialect}/${name}.md`);
}

function readAgent(dialect, name) {
  const relative = `agents/${dialect}/${name}.md`;
  const file = agentPath(dialect, name);
  const content = fs.readFileSync(file, 'utf8');
  const match = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/u);
  if (!match) {
    fail(relative, 'missing YAML frontmatter');
  }
  return {
    relative,
    data: yaml.load(match[1]),
    body: match[2],
  };
}

function validateRoute(dialect, name, expectedModel, expectedLevel) {
  const agent = readAgent(dialect, name);
  const expectedField = dialect === 'claude' ? 'effort' : 'thinking';
  const forbiddenField = dialect === 'claude' ? 'thinking' : 'effort';
  const data = agent.data;

  if (data.model !== expectedModel) {
    fail(agent.relative, `expected model ${expectedModel}, got ${data.model}`);
  }
  if (data[expectedField] !== expectedLevel) {
    fail(agent.relative, `expected ${expectedField} ${expectedLevel}, got ${data[expectedField]}`);
  }
  if (Object.hasOwn(data, forbiddenField)) {
    fail(agent.relative, `unexpected ${forbiddenField} frontmatter`);
  }
  if (Object.hasOwn(data, 'verbosity')) {
    fail(agent.relative, 'unsupported verbosity frontmatter is forbidden');
  }
  if (!/\bHigh verbosity\b/u.test(agent.body)) {
    fail(agent.relative, 'high verbosity requirement must live in the prompt body');
  }
}

for (const [name, expectedModels, expectedLevel] of dualDialectRoutedAgents) {
  for (const dialect of ['claude', 'pi']) {
    validateRoute(dialect, name, expectedModels[dialect], expectedLevel);
  }
}

for (const [name, expectedModel, expectedLevel] of piOnlyRoutedAgents) {
  validateRoute('pi', name, expectedModel, expectedLevel);
  if (fs.existsSync(agentPath('claude', name))) {
    fail(`agents/claude/${name}.md`, 'GPT-routed agent must not exist in the Claude dialect; Claude Code has no openai-codex/* route');
  }
}

// Pi keeps the Opus xhigh route as provider-failure fallback only; Claude Code
// promotes the Opus xhigh route to its primary final-review route.
const piFallback = readAgent('pi', 'mr-reviewer-opus48-xhigh');
if (!/Provider-failure fallback only/u.test(piFallback.body) || !/Never select it as a cost downgrade/u.test(piFallback.body)) {
  fail(piFallback.relative, 'must be provider-failure fallback only, never a cost downgrade');
}

const claudeFinal = readAgent('claude', 'mr-reviewer-opus48-xhigh');
if (!/Claude Code final-review route/u.test(claudeFinal.body)) {
  fail(claudeFinal.relative, 'must declare itself the primary Claude Code final-review route');
}
if (/Provider-failure fallback only/u.test(claudeFinal.body)) {
  fail(claudeFinal.relative, 'Claude Code final-review route must not be labeled provider-failure fallback only');
}

// The GPT non-gate scout is pi-only.
const scout = readAgent('pi', 'mr-review-scout-gpt54-low');
for (const expected of ['non-gate', 'non-authoritative', 'must not approve', 'pass', 'fail']) {
  if (!scout.body.includes(expected)) {
    fail(scout.relative, `missing scout authority token: ${expected}`);
  }
}
NODE


echo "agents-schema regression: PASS"
