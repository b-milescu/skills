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
model: claude-opus-4-8
effort: medium
---

Invoke start-build via Skill; use the target's confirmed integration.
MD
cat > "$TMP_ROOT/project/.omp/agents/neutral-worker.md" <<'MD'
---
name: neutral-worker
description: OMP project worker
tools: read, bash, mcp__custom_server_*, mcp__independent_tracker_read_item
model: pi/task
thinking-level: medium
autoload-skills: start-build, forge
---

Read skill://start-build and the target's confirmed integration.
MD
expect_fail() {
  if node "$checker" "$@" >"$TMP_ROOT/diagnostic" 2>&1; then
    echo "expected schema rejection: $*" >&2
    exit 1
  fi
}
# Invoke from a foreign CWD: paths, not an unrelated checkout, define the input.
(cd "$TMP_ROOT" && node "$checker" "$TMP_ROOT/project/.claude/agents" "$TMP_ROOT/project/.omp/agents")
node "$checker" "$TMP_ROOT/project/.claude/agents/neutral-worker.md" "$TMP_ROOT/project/.omp/agents/neutral-worker.md"
node "$checker" "$TMP_ROOT/project"
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
# Real project declarations and shared presets are checked together by default.
node "$checker"
echo 'agents-schema regression: PASS'
