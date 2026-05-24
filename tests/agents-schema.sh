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
tools: Bash, Read, Edit, Write, Grep, Glob, Skill, TodoWrite, AskUserQuestion
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
tools: read, bash, edit, write, intercom, mcp:chrome-devtools, mcp:github/search_repositories
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
  "pi tool \"mcp:\" is not a pi tool" \
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

echo "agents-schema regression: PASS"
