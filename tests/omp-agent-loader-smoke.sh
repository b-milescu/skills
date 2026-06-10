#!/usr/bin/env bash
# Regression: install.sh exposes agents/omp/*.md to the real OMP task-agent loader.
#
# Proves a clean temp-HOME install surfaces every OMP agent to user-scope
# discovery, and that loaded runtime metadata matches the repo-owned OMP routing
# contract: lowercase OMP builtin tools, exact mcp__ server tool names,
# autoload-skills, and per-agent model/thinking pins.

set -euo pipefail
shopt -s nullglob

TEST_NAME="omp-agent-loader-smoke"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=tests/lib/assertions.sh
source "$REPO_ROOT/tests/lib/assertions.sh"

command -v bun >/dev/null 2>&1 || fail "bun required to run this test"

# GNU realpath for symlink resolution (matches install.sh and sibling tests).
if realpath --relative-to=/ / >/dev/null 2>&1; then
  REALPATH=realpath
elif command -v grealpath >/dev/null 2>&1; then
  REALPATH=grealpath
else
  fail "GNU realpath required"
fi

OMP_SOURCE_DIR="$REPO_ROOT/agents/omp"
[[ -d "$OMP_SOURCE_DIR" ]] || fail "missing OMP agent source dir: $OMP_SOURCE_DIR"

expected_names=()
for f in "$OMP_SOURCE_DIR"/*.md; do
  expected_names+=("$(basename "$f" .md)")
done
[[ ${#expected_names[@]} -gt 0 ]] || fail "no OMP agent files found in $OMP_SOURCE_DIR"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/omp-agent-loader-smoke.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT
TMP_HOME="$TMP_ROOT/home"
DISCOVER_CWD="$TMP_ROOT/project"
mkdir -p \
  "$TMP_HOME/.omp/agent/agents" \
  "$TMP_HOME/.omp/agent/skills" \
  "$DISCOVER_CWD"

install_out="$TMP_ROOT/install.out"
HOME="$TMP_HOME" "$REPO_ROOT/install.sh" >"$install_out" 2>&1 \
  || { cat "$install_out" >&2; fail "install.sh failed against temp OMP runtime"; }

agents_dir="$TMP_HOME/.omp/agent/agents"

# Installer-exposure proof: every expected OMP agent is a symlink in the temp
# runtime resolving back into agents/omp/.
for name in "${expected_names[@]}"; do
  link="$agents_dir/$name.md"
  [[ -L "$link" ]] || fail "missing installed OMP agent symlink: $link"
  resolved="$($REALPATH -m "$link")"
  expected="$($REALPATH -m "$OMP_SOURCE_DIR/$name.md")"
  [[ "$resolved" == "$expected" ]] || fail "$link resolves to $resolved, expected $expected"
done

pkg_dir="${OMP_CODING_AGENT_PKG:-}"
for cand in \
  "$pkg_dir" \
  "${PI_PACKAGE_DIR:-}" \
  "$HOME/.bun/install/global/node_modules/@oh-my-pi/pi-coding-agent" \
  "$HOME/.bun/install/global/node_modules/@oh-my-pi/coding-agent"; do
  [[ -n "$cand" && -f "$cand/src/task/discovery.ts" ]] || continue
  pkg_dir="$cand"
  break
done

if [[ -z "$pkg_dir" || ! -f "$pkg_dir/src/task/discovery.ts" ]]; then
  printf '%s: loader assertions N/A (OMP package not found); installer exposure checked\n' "$TEST_NAME"
  exit 0
fi

expected_names_nl="$(printf '%s\n' "${expected_names[@]}")"
assertions_js="$TMP_ROOT/omp-loader-assertions.mjs"
cat > "$assertions_js" <<'BUN'
import { pathToFileURL } from "node:url";
import path from "node:path";

const pkgDir = process.env.OMP_PACKAGE_DIR;
const { discoverAgents } = await import(pathToFileURL(path.join(pkgDir, "src/task/discovery.ts")).href);
const expectedNames = process.env.EXPECTED_NAMES.split("\n").filter(Boolean).sort();
const result = await discoverAgents(process.env.DISCOVER_CWD, process.env.HOME);
const loaded = new Map(result.agents.filter(agent => expectedNames.includes(agent.name)).map(agent => [agent.name, agent]));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

assert(loaded.size === expectedNames.length, `loaded ${loaded.size} expected OMP agents, wanted ${expectedNames.length}`);
const requiredTools = ["read", "search", "find", "bash", "edit", "write", "todo", "irc", "yield"];
const forbiddenTools = ["grep", "ls", "intercom", "mcp:gitlab-mcp", "mcp:wowtools"];
const requiredMcp = [
  "mcp__gitlab_mcp_get_issue",
  "mcp__gitlab_mcp_get_merge_request",
  "mcp__gitlab_mcp_create_merge_request_note",
  "mcp__gitlab_mcp_approve_merge_request",
  "mcp__gitlab_mcp_merge_merge_request",
  "mcp__wowtools_get_active_build",
];
const expectedPins = {
  "mr-builder-opus48-high": { model: "anthropic/claude-opus-4-8", thinking: "high" },
  "mr-builder-opus48": { model: "anthropic/claude-opus-4-8", thinking: "medium" },
  "mr-builder-sonnet-low": { model: "anthropic/claude-sonnet-4-6", thinking: "low" },
  "mr-reviewer-gpt55-xhigh": { model: "openai-codex/gpt-5.5", thinking: "xhigh" },
  "mr-review-scout-gpt54-low": { model: "openai-codex/gpt-5.4", thinking: "low" },
  "mr-reviewer-opus48-xhigh": { model: "anthropic/claude-opus-4-8", thinking: "xhigh" },
};

for (const name of expectedNames) {
  const agent = loaded.get(name);
  assert(agent, `missing agent ${name}`);
  assert(agent.source === "user", `${name} source ${agent.source} !== user`);
  assert(agent.filePath.includes("/.omp/agent/agents/"), `${name} filePath not under temp OMP agents: ${agent.filePath}`);
  for (const tool of requiredTools) assert(agent.tools.includes(tool), `${name} missing tool ${tool}`);
  for (const tool of forbiddenTools) assert(!agent.tools.includes(tool), `${name} retained forbidden tool ${tool}`);
  for (const tool of requiredMcp) assert(agent.tools.includes(tool), `${name} missing MCP tool ${tool}`);
  assert(Array.isArray(agent.autoloadSkills) && agent.autoloadSkills.includes("gitlab") && agent.autoloadSkills.includes("tdd"), `${name} missing autoload skills`);
  if (name.startsWith("mr-builder")) {
    assert(agent.autoloadSkills.includes("start-build"), `${name} missing start-build autoload`);
  } else {
    assert(agent.autoloadSkills.includes("start-review"), `${name} missing start-review autoload`);
  }
  const pin = expectedPins[name];
  if (pin) {
    assert(agent.model?.[0] === pin.model, `${name} model ${agent.model?.[0]} !== ${pin.model}`);
    assert(agent.thinkingLevel === pin.thinking, `${name} thinking ${agent.thinkingLevel} !== ${pin.thinking}`);
  }
}
BUN
HOME="$TMP_HOME" \
PI_CODING_AGENT_DIR="$TMP_HOME/.omp/agent" \
PI_PACKAGE_DIR="$pkg_dir" \
OMP_PACKAGE_DIR="$pkg_dir" \
DISCOVER_CWD="$DISCOVER_CWD" \
EXPECTED_NAMES="$expected_names_nl" \
bun "$assertions_js" || fail "OMP loader assertions failed"

printf '%s: PASS\n' "$TEST_NAME"
