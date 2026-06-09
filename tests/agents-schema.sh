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

REPO_ROOT_PATH="$REPO_ROOT" node --input-type=module <<'NODE'
import fs from 'node:fs';
import path from 'node:path';
import yaml from 'js-yaml';

const repoRoot = process.env.REPO_ROOT_PATH;
const routedAgents = [
  ['mr-builder-sonnet-low', 'anthropic/claude-sonnet-4-6', 'low'],
  ['mr-builder-opus48', 'anthropic/claude-opus-4-8', 'medium'],
  ['mr-builder-opus48-high', 'anthropic/claude-opus-4-8', 'high'],
  ['mr-reviewer-gpt55-xhigh', 'openai-codex/gpt-5.5', 'xhigh'],
  ['mr-reviewer-opus48-xhigh', 'anthropic/claude-opus-4-8', 'xhigh'],
  ['mr-review-scout-gpt54-low', 'openai-codex/gpt-5.4', 'low'],
];

function fail(file, message) {
  console.error(`${file}: ${message}`);
  process.exit(1);
}

function readAgent(dialect, name) {
  const relative = `agents/${dialect}/${name}.md`;
  const file = path.join(repoRoot, relative);
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

for (const [name, expectedModel, expectedLevel] of routedAgents) {
  for (const dialect of ['claude', 'pi']) {
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
}

for (const dialect of ['claude', 'pi']) {
  const fallback = readAgent(dialect, 'mr-reviewer-opus48-xhigh');
  if (!/Provider-failure fallback only/u.test(fallback.body) || !/Never select it as a cost downgrade/u.test(fallback.body)) {
    fail(fallback.relative, 'must be provider-failure fallback only, never a cost downgrade');
  }

  const scout = readAgent(dialect, 'mr-review-scout-gpt54-low');
  for (const expected of ['non-gate', 'non-authoritative', 'must not approve', 'pass', 'fail']) {
    if (!scout.body.includes(expected)) {
      fail(scout.relative, `missing scout authority token: ${expected}`);
    }
  }
}
NODE


echo "agents-schema regression: PASS"
