#!/usr/bin/env bash
# Focus: runtime schemas, native project paths, scoped-selector syntax and
# non-empty requested validation. Native availability is a separate proof.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT
checker="$REPO_ROOT/scripts/check-agent-schemas.mjs"
mkdir -p "$TMP_ROOT/project/.claude/agents" "$TMP_ROOT/project/.omp/agents" "$TMP_ROOT/empty/.omp/agents"
cat > "$TMP_ROOT/project/.claude/agents/neutral-worker.md" <<'MD'
---
name: neutral-worker
description: Claude project worker
tools: Read, Bash, Skill, mcp__custom-server__*, mcp__independent_tracker__read_item
skills: start-build, forge
model: inherit
---

Invoke start-build via Skill; use the target's confirmed integration.
MD
cat > "$TMP_ROOT/project/.omp/agents/neutral-worker.md" <<'MD'
---
name: neutral-worker
description: OMP project worker
tools: read, bash, mcp__custom_server_*, mcp__independent_tracker_read_item
autoload-skills: start-build, forge
---

Read skill://start-build and the target's confirmed integration.
MD
expect_fail() {
  if bun "$checker" "$@" >"$TMP_ROOT/diagnostic" 2>&1; then
    echo "expected schema rejection: $*" >&2
    exit 1
  fi
}
# Invoke from a foreign CWD: paths, not an unrelated checkout, define the input.
(cd "$TMP_ROOT" && bun "$checker" "$TMP_ROOT/project/.claude/agents" "$TMP_ROOT/project/.omp/agents")
bun "$checker" "$TMP_ROOT/project/.claude/agents/neutral-worker.md" "$TMP_ROOT/project/.omp/agents/neutral-worker.md"
bun "$checker" "$TMP_ROOT/project"
bash "$REPO_ROOT/agents/check.sh" "$TMP_ROOT/project/.claude/agents" "$TMP_ROOT/project/.omp/agents"
# One source interpreted in two runtime scopes must still reject the wrong dialect.
mkdir -p "$TMP_ROOT/alias/.omp/agents"
ln -s "$TMP_ROOT/project/.claude/agents/neutral-worker.md" "$TMP_ROOT/alias/.omp/agents/neutral-worker.md"
expect_fail "$TMP_ROOT/alias/.omp/agents" "$TMP_ROOT/project/.claude/agents"
if ! grep -Fq 'Claude-only frontmatter field' "$TMP_ROOT/diagnostic"; then
  echo 'cross-dialect symlink concealed invalid OMP metadata' >&2
  exit 1
fi
expect_fail "$TMP_ROOT/empty/.omp/agents"
if bash "$REPO_ROOT/agents/check.sh" "$TMP_ROOT/empty/.omp/agents" >"$TMP_ROOT/native-empty.out" 2>&1; then
  echo 'real native-location checker accepted an empty request' >&2
  exit 1
fi
# An empty request cannot be concealed by a second valid request.
expect_fail "$TMP_ROOT/project/.omp/agents" "$TMP_ROOT/empty/.omp/agents"
expect_fail "$TMP_ROOT/missing/.claude/agents"
mkdir -p "$TMP_ROOT/unrecognized"
printf '%s\n' '# Not an agent' >"$TMP_ROOT/unrecognized/not-agent.md"
expect_fail "$TMP_ROOT/unrecognized/not-agent.md"
# A plugin's `agents/` root in a checkout other than this one: its top-level presets are OMP
# dialect, `claude/` holds the Claude ones and README.md is no agent. Recognition must follow
# the directory layout, not the location of the checker.
plugin="$TMP_ROOT/plugin-tree/agents"
mkdir -p "$plugin/claude" "$TMP_ROOT/readme-only/agents"
printf '%s\n' '# Not an agent' >"$plugin/README.md"
cp "$plugin/README.md" "$TMP_ROOT/readme-only/agents/README.md"
cat > "$plugin/claude/neutral-worker.md" <<'MD'
---
name: neutral-worker
description: Claude plugin preset
skills: start-build, forge
model: inherit
---
MD
cat > "$plugin/neutral-worker.md" <<'MD'
---
name: neutral-worker
description: OMP plugin preset
autoload-skills: start-build, forge
---
MD
expect_checked() { # "<N> Claude agent(s), <M> OMP agent(s)", then checker arguments
  local summary="$1"
  shift
  if ! bun "$checker" "$@" >"$TMP_ROOT/summary" 2>&1 || ! grep -Fxq "agents-schema: checked $summary" "$TMP_ROOT/summary"; then
    echo "expected '$summary' from: $*" >&2
    cat "$TMP_ROOT/summary" >&2
    exit 1
  fi
}
expect_checked '1 Claude agent(s), 1 OMP agent(s)' "$plugin"
expect_checked '0 Claude agent(s), 1 OMP agent(s)' "$plugin/neutral-worker.md"
expect_checked '1 Claude agent(s), 0 OMP agent(s)' "$plugin/claude"
expect_fail "$plugin/README.md"
expect_fail "$TMP_ROOT/readme-only/agents"
# A corrupted root preset must fail whether the plugin root or the file itself is the target.
printf -- '---\nmodel: 42\ntools: Bogus\n---\n' >"$plugin/neutral-worker.md"
for target in "$plugin" "$plugin/neutral-worker.md"; do
  expect_fail "$target"
  for error in 'missing required frontmatter field: name' 'missing required frontmatter field: description' 'frontmatter field "model" must be a non-empty string or string list' 'OMP tool "Bogus" is not an OMP tool'; do
    if ! grep -F 'plugin-tree/agents/neutral-worker.md:' "$TMP_ROOT/diagnostic" | grep -Fq "$error"; then
      echo "corrupted plugin root preset not rejected for $target: $error" >&2
      cat "$TMP_ROOT/diagnostic" >&2
      exit 1
    fi
  done
done
if bash "$REPO_ROOT/agents/check.sh" "$plugin" >"$TMP_ROOT/plugin-check.out" 2>&1; then
  echo 'agents/check.sh accepted a corrupted plugin root preset' >&2
  exit 1
fi

bad="$TMP_ROOT/bad/.omp/agents"
mkdir -p "$bad"
for selector in mcp 'mcp:*' 'mcp__*' 'mcp__server_*_tool' 'mcp__server-name__*' 'mcp__custom_server__read_item'; do
  cat > "$bad/neutral-worker.md" <<MD
---
name: neutral-worker
description: Invalid scope selector
tools: read, $selector
---
MD
  expect_fail "$bad/neutral-worker.md"
done
cat > "$bad/neutral-worker.md" <<'MD'
---
name: other-worker
tools: Bash, Read, search, find, ls, intercom
skills: start-build
effort: high
thinking: high
thinkingLevel: medium
model: bare-model
---
MD
expect_fail "$bad/neutral-worker.md"
for error in 'missing required frontmatter field' 'does not match file name' 'Claude-only frontmatter field' 'retired Pi frontmatter field' 'canonical key' 'not an approved model/provider' 'must use OMP tool' 'must use OMP-native tool'; do
  if ! grep -Fq "$error" "$TMP_ROOT/diagnostic"; then
    echo "missing schema rejection category: $error" >&2
    cat "$TMP_ROOT/diagnostic" >&2
    exit 1
  fi
done
cat > "$bad/neutral-worker.md" <<'MD'
---
name: [broken
description: Invalid YAML
tools: read
---
MD
expect_fail "$bad/neutral-worker.md"
cat > "$bad/neutral-worker.md" <<'MD'
---
name: neutral-worker
description: Invalid semantic field
tools: read
thinking-level: med
---
MD
expect_fail "$bad/neutral-worker.md"
cat > "$bad/forbidden-gpt-55.md" <<'MD'
---
name: forbidden-gpt-55
description: Model-free route boundary
tools: read
model: openai-codex/gpt-5.5
---
MD
expect_fail "$bad/forbidden-gpt-55.md"
claude_bad="$TMP_ROOT/bad/.claude/agents"
mkdir -p "$claude_bad"
for selector in mcp 'mcp__*' 'mcp__server*__*' 'mcp__server__tool*'; do
  cat > "$claude_bad/neutral-worker.md" <<MD
---
name: neutral-worker
description: Invalid Claude scope selector
tools: Read, $selector
---
MD
  expect_fail "$claude_bad/neutral-worker.md"
done
cat > "$claude_bad/neutral-worker.md" <<'MD'
---
name: neutral-worker
description: Invalid Claude dialect fields
tools: read
thinking-level: medium
---
MD
expect_fail "$claude_bad/neutral-worker.md"
# Tool tables: current builtins and the Agent/Task pair pass; retired or foreign names fail
# with their exact replacement, so a dropped entry or a changed mapping cannot go unnoticed.
probe="$TMP_ROOT/tools"
mkdir -p "$probe/.claude/agents" "$probe/.omp/agents"
probe_tools() { # dialect, tools value
  printf -- '---\nname: tool-probe\ndescription: Tool table probe\ntools: %s\n---\n' "$2" >"$probe/.$1/agents/tool-probe.md"
}
expect_tool_error() { # dialect, tools value, exact diagnostic
  probe_tools "$1" "$2"
  expect_fail "$probe/.$1/agents/tool-probe.md"
  if ! grep -Fq "$3" "$TMP_ROOT/diagnostic"; then
    echo "missing tool rejection: $3" >&2
    cat "$TMP_ROOT/diagnostic" >&2
    exit 1
  fi
}
probe_tools omp '"read, todo, hub"'
bun "$checker" "$probe/.omp/agents/tool-probe.md"
probe_tools omp '"debug, github, computer, checkpoint, rewind, security_scan, memory_edit, retain, recall, reflect, learn, manage_skill, goal, think"'
bun "$checker" "$probe/.omp/agents/tool-probe.md"
probe_tools claude '"Read, Agent, Task"'
bun "$checker" "$probe/.claude/agents/tool-probe.md"
expect_tool_error claude '"LS, MultiEdit"' 'Claude tool "LS" is not a Claude Code tool'
expect_tool_error claude '"LS, MultiEdit"' 'Claude tool "MultiEdit" is not a Claude Code tool'
expect_tool_error omp irc 'OMP tool "irc" must use OMP-native tool "hub"'
expect_tool_error omp intercom 'OMP tool "intercom" must use OMP-native tool "hub"'
# `tools` is optional: a route that omits it inherits every parent tool in both runtimes.
cat > "$probe/.claude/agents/tool-probe.md" <<'MD'
---
name: tool-probe
description: Inherits every parent tool
skills: start-build, forge
model: inherit
---
MD
bun "$checker" "$probe/.claude/agents/tool-probe.md"
cat > "$probe/.omp/agents/tool-probe.md" <<'MD'
---
name: tool-probe
description: Inherits every parent tool
autoload-skills: start-build, forge
---
MD
bun "$checker" "$probe/.omp/agents/tool-probe.md"
# Real project declarations and shared presets are checked together by default.
bun "$checker"
echo 'agents-schema regression: PASS'
