#!/usr/bin/env bash
# Focus: Claude/OMP agent frontmatter parsing, required fields, name/filename
# matching, runtime-only field drift, dialect-specific tool casing, OMP MCP
# inventory, retired Pi fields/bridge wording, OMP model-provider allowlist,
# OMP thinking-level values, canonical OMP multiword keys, and model-token-free
# route names.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/good/agents/claude" "$TMPDIR/good/agents/omp"
cat > "$TMPDIR/good/agents/claude/neutral-worker.md" <<'MD'
---
name: neutral-worker
description: Claude worker fixture
tools: "Bash, Read, Edit, Write, Grep, Glob, Skill, TodoWrite, AskUserQuestion, mcp__gitlab-mcp__*, mcp__azure-devops__*, mcp__wowtools__*, mcp__codebase-memory-mcp__*"
skills: start-build, forge
model: inherit
effort: high
---

Claude body.
MD

cat > "$TMPDIR/good/agents/omp/neutral-worker.md" <<'MD'
---
name: neutral-worker
description: OMP worker fixture
tools: "read, grep, glob, bash, edit, write, todo, irc, mcp__gitlab_mcp_*, mcp__azure_devops_*, mcp__wowtools_*, mcp__codebase_memory_mcp_*"
model: anthropic/claude-opus-4-8
thinking-level: high
autoload-skills: start-build, forge
---

OMP body may mention irc coordination.
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
tools: "Bash, Read, search, find, ls, intercom, mcp:gitlab-mcp"
effort: high
color: green
skills: start-build
thinking: high
systemPromptMode: replace
---

OMP bad fixture.
MD

cat > "$TMPDIR/bad/agents/omp/bad-mcp-selectors.md" <<'MD'
---
name: bad-mcp-selectors
description: OMP MCP bad fixture
tools: "read, mcp, mcp:*, mcp:codebase-memory-mcp, mcp__*, mcp__gitlab-mcp__*, mcp__codebase-memory-mcp__*, mcp__gitlab_mcp_get_project, mcp__codebase_memory_mcp_search_graph"
---

OMP MR agents may only use the server-scoped mcp__ wildcard selectors.
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

cat > "$TMPDIR/bad/agents/omp/forbidden-gpt-55.md" <<'MD'
---
name: forbidden-gpt-55
description: OMP forbidden route-name token fixture
tools: read
model: openai-codex/gpt-5.5
---

OMP body.
MD

cat > "$TMPDIR/bad/agents/omp/forbidden-gpt.55.md" <<'MD'
---
name: forbidden-gpt.55
description: OMP forbidden route-name token fixture
tools: read
model: openai-codex/gpt-5.5
---

OMP body.
MD

cat > "$TMPDIR/bad/agents/claude/forbidden-opus48.md" <<'MD'
---
name: forbidden-opus48
description: Claude forbidden route-name token fixture
tools: Read
model: inherit
---

Claude body.
MD

cat > "$TMPDIR/bad/agents/claude/forbidden-sonnet.md" <<'MD'
---
name: forbidden-sonnet
description: Claude forbidden route-name token fixture
tools: Read
model: inherit
---

Claude body.
MD

cat > "$TMPDIR/bad/agents/claude/forbidden-claude.md" <<'MD'
---
name: forbidden-claude
description: Claude forbidden route-name token fixture
tools: Read
model: inherit
---

Claude body.
MD

cat > "$TMPDIR/bad/agents/omp/forbidden-openai.md" <<'MD'
---
name: forbidden-openai
description: OMP forbidden route-name token fixture
tools: read
model: openai-codex/gpt-5.5
---

OMP body.
MD

cat > "$TMPDIR/bad/agents/omp/forbidden-anthropic.md" <<'MD'
---
name: forbidden-anthropic
description: OMP forbidden route-name token fixture
tools: read
model: anthropic/claude-opus-4-8
---

OMP body.
MD

cat > "$TMPDIR/bad/agents/omp/forbidden-codex.md" <<'MD'
---
name: forbidden-codex
description: OMP forbidden route-name token fixture
tools: read
model: openai-codex/gpt-5.5
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
  "OMP tool \"search\" must use OMP-native tool \"grep\"" \
  "OMP tool \"find\" must use OMP-native tool \"glob\"" \
  "OMP tool \"ls\" must use OMP-native tool \"directory reads via read\"" \
  "OMP tool \"intercom\" must use OMP-native tool \"irc\"" \
 "OMP MCP selector \"mcp:gitlab-mcp\" is not approved; allowed selectors: mcp__gitlab_mcp_*, mcp__azure_devops_*, mcp__wowtools_*, mcp__codebase_memory_mcp_*" \
 "OMP MCP selector \"mcp\" is not approved; allowed selectors: mcp__gitlab_mcp_*, mcp__azure_devops_*, mcp__wowtools_*, mcp__codebase_memory_mcp_*" \
 "OMP MCP selector \"mcp:*\" is not approved; allowed selectors: mcp__gitlab_mcp_*, mcp__azure_devops_*, mcp__wowtools_*, mcp__codebase_memory_mcp_*" \
 "OMP MCP selector \"mcp:codebase-memory-mcp\" is not approved; allowed selectors: mcp__gitlab_mcp_*, mcp__azure_devops_*, mcp__wowtools_*, mcp__codebase_memory_mcp_*" \
 "OMP MCP selector \"mcp__*\" is not approved; allowed selectors: mcp__gitlab_mcp_*, mcp__azure_devops_*, mcp__wowtools_*, mcp__codebase_memory_mcp_*" \
 "OMP MCP selector \"mcp__gitlab-mcp__*\" is not approved; allowed selectors: mcp__gitlab_mcp_*, mcp__azure_devops_*, mcp__wowtools_*, mcp__codebase_memory_mcp_*" \
 "OMP MCP selector \"mcp__codebase-memory-mcp__*\" is not approved; allowed selectors: mcp__gitlab_mcp_*, mcp__azure_devops_*, mcp__wowtools_*, mcp__codebase_memory_mcp_*" \
 "OMP MCP selector \"mcp__gitlab_mcp_get_project\" is not approved; allowed selectors: mcp__gitlab_mcp_*, mcp__azure_devops_*, mcp__wowtools_*, mcp__codebase_memory_mcp_*" \
 "OMP MCP selector \"mcp__codebase_memory_mcp_search_graph\" is not approved; allowed selectors: mcp__gitlab_mcp_*, mcp__azure_devops_*, mcp__wowtools_*, mcp__codebase_memory_mcp_*" \
  "frontmatter YAML does not parse" \
  "OMP model \"claude-opus-4-8\" not an approved model/provider; allowed provider prefixes: anthropic/, openai-codex/, pi/, zai/" \
  "OMP thinking-level \"med\" is not a valid value; allowed: inherit, off, minimal, low, medium, high, xhigh" \
  "OMP frontmatter field \"thinkingLevel\" must use canonical key \"thinking-level\"" \
  "OMP frontmatter field \"autoloadSkills\" must use canonical key \"autoload-skills\"" \
  "OMP frontmatter field \"readSummarize\" must use canonical key \"read-summarize\"" \
  "file name \"forbidden-gpt-55\" must not include provider/model token \"gpt-55\"; use shared model-free route name" \
  "frontmatter name \"forbidden-gpt-55\" must not include provider/model token \"gpt-55\"; use shared model-free route name" \
  "file name \"forbidden-gpt.55\" must not include provider/model token \"gpt.55\"; use shared model-free route name" \
  "frontmatter name \"forbidden-gpt.55\" must not include provider/model token \"gpt.55\"; use shared model-free route name" \
  "file name \"forbidden-opus48\" must not include provider/model token \"opus48\"; use shared model-free route name" \
  "frontmatter name \"forbidden-opus48\" must not include provider/model token \"opus48\"; use shared model-free route name" \
  "file name \"forbidden-sonnet\" must not include provider/model token \"sonnet\"; use shared model-free route name" \
  "frontmatter name \"forbidden-sonnet\" must not include provider/model token \"sonnet\"; use shared model-free route name" \
  "file name \"forbidden-claude\" must not include provider/model token \"claude\"; use shared model-free route name" \
  "frontmatter name \"forbidden-claude\" must not include provider/model token \"claude\"; use shared model-free route name" \
  "file name \"forbidden-openai\" must not include provider/model token \"openai\"; use shared model-free route name" \
  "frontmatter name \"forbidden-openai\" must not include provider/model token \"openai\"; use shared model-free route name" \
  "file name \"forbidden-anthropic\" must not include provider/model token \"anthropic\"; use shared model-free route name" \
  "frontmatter name \"forbidden-anthropic\" must not include provider/model token \"anthropic\"; use shared model-free route name" \
  "file name \"forbidden-codex\" must not include provider/model token \"codex\"; use shared model-free route name" \
  "frontmatter name \"forbidden-codex\" must not include provider/model token \"codex\"; use shared model-free route name"; do
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
cat > "$TMPDIR/good-models/agents/omp/allowed-alpha.md" <<'MD'
---
name: allowed-alpha
description: model fixture
tools: read
model: anthropic/claude-opus-4-8
---

Body.
MD

cat > "$TMPDIR/good-models/agents/omp/allowed-beta.md" <<'MD'
---
name: allowed-beta
description: model fixture
tools: read
model: openai-codex/gpt-5.5
---

Body.
MD

cat > "$TMPDIR/good-models/agents/omp/allowed-gamma.md" <<'MD'
---
name: allowed-gamma
description: model fixture
tools: read
model: pi/slow
---

Body.
MD

cat > "$TMPDIR/good-models/agents/omp/allowed-delta.md" <<'MD'
---
name: allowed-delta
description: model fixture
tools: read
model: zai/glm-5.2
---

Body.
MD

models_output="$(node "$REPO_ROOT/scripts/check-agent-schemas.mjs" "$TMPDIR/good-models/agents")"
if [[ "$models_output" != "agents-schema: checked 0 Claude agent(s), 4 OMP agent(s)" ]]; then
  echo "unexpected models output: $models_output" >&2
  exit 1
fi

echo "agents-schema regression: PASS"
