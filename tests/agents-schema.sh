#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/good/agents/claude" "$TMPDIR/good/agents/omp"
cat > "$TMPDIR/good/agents/claude/mr-worker.md" <<'MD'
---
name: mr-worker
description: Claude worker fixture
tools: "Bash, Read, Edit, Write, Grep, Glob, Skill, TodoWrite, AskUserQuestion, mcp__gitlab-mcp__*, mcp__wowtools__*"
skills: start-build, tdd, gitlab
model: inherit
effort: high
---

Claude body.
MD

cat > "$TMPDIR/good/agents/omp/mr-worker.md" <<'MD'
---
name: mr-worker
description: OMP worker fixture
tools: "read, search, find, bash, edit, write, todo, irc, mcp__gitlab_mcp_get_issue, mcp__gitlab_mcp_get_merge_request, mcp__wowtools_get_active_build"
model: anthropic/claude-opus-4-8
thinking-level: high
autoload-skills: start-build, tdd, gitlab
---

OMP body may mention irc for coordination.
MD

mkdir -p "$TMPDIR/bad/agents/claude" "$TMPDIR/bad/agents/omp"
cat > "$TMPDIR/bad/agents/claude/wrong-name.md" <<'MD'
---
name: other-name
description: Claude bad fixture
tools: bash, irc
thinking-level: high
---

Claude body mentions contact_supervisor and intercom.
MD

cat > "$TMPDIR/bad/agents/claude/missing-description.md" <<'MD'
---
name: missing-description
tools: Read
---

Missing description fixture.
MD

cat > "$TMPDIR/bad/agents/omp/wrong-tools.md" <<'MD'
---
name: wrong-tools
description: OMP bad fixture
tools: "Bash, Read, grep, ls, intercom, mcp:gitlab-mcp"
effort: high
color: green
skills: start-build
thinking: high
systemPromptMode: replace
---

OMP bad fixture.
MD

cat > "$TMPDIR/bad/agents/omp/mr-builder.md" <<'MD'
---
name: mr-builder
description: OMP MCP bad fixture
tools: "read, mcp, mcp__gitlab_mcp_missing_tool, mcp__wowtools_missing_tool"
---

OMP MR agents must use exact approved MCP tool names.
MD

cat > "$TMPDIR/bad/agents/omp/bad-yaml.md" <<'MD'
---
name: [bad
description: parse failure fixture
tools: read
---

Bad YAML body.
MD

cat > "$TMPDIR/bad/agents/omp/omp-bare-model.md" <<'MD'
---
name: omp-bare-model
description: OMP bare model fixture
tools: read, bash
model: claude-opus-4-8
---

OMP body.
MD

cat > "$TMPDIR/bad/agents/omp/omp-bad-thinking.md" <<'MD'
---
name: omp-bad-thinking
description: OMP bad thinking fixture
tools: read, bash
thinking-level: med
---

OMP body.
MD

cat > "$TMPDIR/bad/agents/omp/omp-camel-fields.md" <<'MD'
---
name: omp-camel-fields
description: OMP camel field fixture
tools: read, bash
thinkingLevel: high
autoloadSkills: start-build
readSummarize: false
---

OMP body.
MD

set +e
output="$(node "$REPO_ROOT/scripts/check-agent-schemas.mjs" "$TMPDIR/bad/agents" 2>&1)"
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "expected schema check to fail for bad fixtures" >&2
  exit 1
fi

for expected in \
  "frontmatter name \"other-name\" does not match file name \"wrong-name\"" \
  "OMP-only frontmatter field \"thinking-level\" is not allowed in Claude agent" \
  "Claude tool \"bash\" must use Claude Code casing \"Bash\"" \
  "Claude tool \"irc\" is not a Claude Code tool" \
  "claude agent body must not contain retired Pi bridge wording \"contact_supervisor\"" \
  "claude agent body must not contain retired Pi bridge wording \"intercom\"" \
  "missing required frontmatter field: description" \
  "Claude-only frontmatter field \"effort\" is not allowed in OMP agent" \
  "Claude-only frontmatter field \"color\" is not allowed in OMP agent" \
  "Claude-only frontmatter field \"skills\" is not allowed in OMP agent" \
  "retired Pi frontmatter field \"thinking\" is not allowed in OMP agent" \
  "retired Pi frontmatter field \"systemPromptMode\" is not allowed in OMP agent" \
  "OMP tool \"Bash\" must use OMP tool name \"bash\"" \
  "OMP tool \"Read\" must use OMP tool name \"read\"" \
  "OMP tool \"grep\" must use OMP-native tool \"search\"" \
  "OMP tool \"ls\" must use OMP-native tool \"directory reads via read\"" \
  "OMP tool \"intercom\" must use OMP-native tool \"irc\"" \
  "OMP MCP tool \"mcp:gitlab-mcp\" must use runtime-real mcp__ server tool names" \
  "OMP MCP tool \"mcp\" is not approved" \
  "OMP MCP tool \"mcp__gitlab_mcp_missing_tool\" is not approved" \
  "OMP MCP tool \"mcp__wowtools_missing_tool\" is not approved" \
  "frontmatter YAML does not parse" \
  "OMP model \"claude-opus-4-8\" is not an approved route; allowed provider prefixes: anthropic/, openai-codex/, pi/" \
  "OMP thinking-level \"med\" is not a valid value; allowed: inherit, off, minimal, low, medium, high, xhigh" \
  "OMP frontmatter field \"thinkingLevel\" must use canonical key \"thinking-level\"" \
  "OMP frontmatter field \"autoloadSkills\" must use canonical key \"autoload-skills\"" \
  "OMP frontmatter field \"readSummarize\" must use canonical key \"read-summarize\""; do
  if [[ "$output" != *"$expected"* ]]; then
    echo "missing expected diagnostic: $expected" >&2
    echo "--- output ---" >&2
    printf '%s\n' "$output" >&2
    exit 1
  fi
done

clean_output="$(node "$REPO_ROOT/scripts/check-agent-schemas.mjs" "$TMPDIR/good/agents")"
if [[ "$clean_output" != "agents-schema: checked 1 Claude agent(s), 1 OMP agent(s)" ]]; then
  echo "unexpected clean output: $clean_output" >&2
  exit 1
fi

mkdir -p "$TMPDIR/good-models/agents/omp"
cat > "$TMPDIR/good-models/agents/omp/model-anthropic.md" <<'MD'
---
name: model-anthropic
description: model fixture
tools: read
model: anthropic/claude-opus-4-8
---

Body.
MD

cat > "$TMPDIR/good-models/agents/omp/model-codex.md" <<'MD'
---
name: model-codex
description: model fixture
tools: read
model: openai-codex/gpt-5.5
---

Body.
MD

cat > "$TMPDIR/good-models/agents/omp/model-role.md" <<'MD'
---
name: model-role
description: model fixture
tools: read
model: pi/slow
---

Body.
MD

models_output="$(node "$REPO_ROOT/scripts/check-agent-schemas.mjs" "$TMPDIR/good-models/agents")"
if [[ "$models_output" != "agents-schema: checked 0 Claude agent(s), 3 OMP agent(s)" ]]; then
  echo "unexpected models output: $models_output" >&2
  exit 1
fi

echo "agents-schema regression: PASS"
