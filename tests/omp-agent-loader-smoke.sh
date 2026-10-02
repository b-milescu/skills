#!/usr/bin/env bash
# Focus: Actual OMP discovery in fresh processes, not current-session caches or a child
# execution-CWD switch. Proves selected file/pins and canonical skill access;
# does not launch models, execute native operations or prove MCP confinement.
set -euo pipefail
shopt -s nullglob
TEST_NAME="omp-agent-loader-smoke"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$REPO_ROOT/tests/lib/assertions.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/omp-agent-loader-smoke.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT
TMP_HOME="$TMP_ROOT/home"
mkdir -p "$TMP_HOME/.omp/agent" "$TMP_ROOT/foreign"
HOME="$TMP_HOME" "$REPO_ROOT/install.sh" >"$TMP_ROOT/install.out" 2>&1 || {
  cat "$TMP_ROOT/install.out" >&2; fail 'disposable-HOME install failed';
}
for file in "$REPO_ROOT/agents/omp"/*.md; do
  link="$TMP_HOME/.omp/agent/agents/$(basename "$file")"
  [[ -L "$link" && "$link" -ef "$file" ]] || fail "missing installed route: $link"
done
pkg_dir="${OMP_CODING_AGENT_PKG:-}"
for candidate in "$pkg_dir" "${PI_PACKAGE_DIR:-}" \
  "$HOME/.bun/install/global/node_modules/@oh-my-pi/pi-coding-agent" \
  "$HOME/.bun/install/global/node_modules/@oh-my-pi/coding-agent"; do
  [[ -n "$candidate" && -f "$candidate/src/task/discovery.ts" ]] || continue
  pkg_dir="$candidate"; break
done
if [[ -z "$pkg_dir" || ! -f "$pkg_dir/src/task/discovery.ts" ]] || ! command -v bun >/dev/null 2>&1; then
  [[ "${OMP_REQUIRE_LOADER:-0}" != 1 ]] || fail 'required actual OMP loader unavailable'
  printf '%s: loader proof N/A (OMP source/bun unavailable); installer exposure only\n' "$TEST_NAME"
  exit 0
fi

spawn_cwd="${OMP_SPAWN_CWD:-$REPO_ROOT}"
allocated_cwd="${OMP_ALLOCATED_CWD:-}"
revision_cwd="${OMP_REVISION_CWD:-}"
proof_scope='independently supplied checkouts'
if [[ -z "$allocated_cwd" || -z "$revision_cwd" ]]; then
  [[ -z "$allocated_cwd" && -z "$revision_cwd" ]] || fail 'supply both allocated and revision checkout paths'
  proof_scope='disposable filesystem checkout copies (not live allocated/revision sessions)'
  allocated_cwd="$TMP_ROOT/allocated"
  revision_cwd="$TMP_ROOT/revision"
  for checkout in "$allocated_cwd" "$revision_cwd"; do
    mkdir -p "$checkout/.omp/agents"
    cp "$REPO_ROOT/.omp/agents/"*.md "$checkout/.omp/agents/"
  done
else
  for checkout in "$allocated_cwd" "$revision_cwd"; do
    root="$(git -C "$checkout" rev-parse --show-toplevel)" || fail "not a Git checkout: $checkout"
    [[ "$root" == "$(cd "$checkout" && pwd -P)" ]] || fail "expected checkout root, not a nested directory: $checkout"
    printf 'OMP checkout binding: %s head=%s\n' "$root" "$(git -C "$checkout" rev-parse HEAD)"
  done
fi
for checkout in "$spawn_cwd" "$allocated_cwd" "$revision_cwd"; do
  [[ "$checkout" == /* && -d "$checkout/.omp/agents" ]] || fail "native project declarations missing: $checkout"
done
assertions_js="$TMP_ROOT/discovery.mjs"
cat > "$assertions_js" <<'BUN'
import { pathToFileURL } from 'node:url';
import fs from 'node:fs';
import path from 'node:path';
const pkg = process.env.OMP_PACKAGE_DIR;
const { discoverAgents } = await import(pathToFileURL(path.join(pkg, 'src/task/discovery.ts')).href);
const { loadSkills } = await import(pathToFileURL(path.join(pkg, 'src/extensibility/skills.ts')).href);
const { SkillProtocolHandler } = await import(pathToFileURL(path.join(pkg, 'src/internal-urls/skill-protocol.ts')).href);
function assert(value, message) { if (!value) throw new Error(message); }
const cwd = process.env.DISCOVER_CWD;
const project = process.env.EXPECT_PROJECT === '1';
const result = await discoverAgents(cwd, process.env.HOME);
const expectedDir = project ? path.join(cwd, '.omp/agents') : path.join(process.env.HOME, '.omp/agent/agents');
const routes = [
  { name: 'mr-builder', thinking: 'medium', entry: 'start-build' },
  { name: 'mr-reviewer-final', thinking: 'xhigh', entry: 'start-review' },
];
for (const { name, thinking, entry } of routes) {
  const agent = result.agents.find(agent => agent.name === name);
  assert(agent, `missing ${name}`);
  const expected = path.join(expectedDir, `${name}.md`);
  assert(agent.filePath === expected, `${name}: selected ${agent.filePath}, expected ${expected}`);
  assert(agent.source === (project ? 'project' : 'user'), `${name}: wrong selected scope`);
  assert(agent.model?.[0] === 'pi/task' && agent.thinkingLevel === thinking, `${name}: runtime pins changed`);
  assert(agent.autoloadSkills.includes(entry) && agent.autoloadSkills.includes('forge'), `${name}: canonical entry preload absent`);
  assert(!agent.autoloadSkills.includes('tdd'), `${name}: retired unconditional TDD preload`);
  if (project) {
    assert(agent.tools.includes('mcp__gitlab_mcp_*') && agent.tools.includes('mcp__codebase_memory_mcp_*'), `${name}: project-native selection missing`);
  } else {
    assert(!agent.tools.some(tool => tool.startsWith('mcp')), `${name}: shared route leaks native selection`);
  }
  console.log(JSON.stringify({ proof: 'selected-metadata', phase: process.env.PROOF_PHASE, cwd, name, source: agent.source, filePath: agent.filePath, realPath: fs.realpathSync(agent.filePath), model: agent.model, thinking: agent.thinkingLevel, tools: agent.tools }));
}
// This is actual session skill discovery with isolated HOME, not a fabricated
// inventory. Canonical entry identity is independent of agent metadata intent.
const { skills } = await loadSkills({ cwd });
const handler = new SkillProtocolHandler();
for (const name of ['start-build', 'start-review', 'forge']) {
  const skill = skills.find(skill => skill.name === name);
  assert(skill && !skill.hide, `canonical ${name} absent from available inventory`);
  const source = path.join(process.env.CANONICAL_ROOT, name, 'SKILL.md');
  assert(fs.realpathSync(skill.filePath) === fs.realpathSync(source), `${name}: canonical entry source mismatch: ${skill.filePath}`);
  const resource = await handler.resolve(new URL(`skill://${name}`), { skills });
  assert(resource.content === fs.readFileSync(source, 'utf8'), `${name}: canonical entry bytes differ`);
  console.log(JSON.stringify({ proof: 'available-entry-access', phase: process.env.PROOF_PHASE, name, filePath: skill.filePath, realPath: fs.realpathSync(skill.filePath) }));
}
const builder = result.agents.find(agent => agent.name === 'mr-builder');
assert(!builder.autoloadSkills.includes('start-review'), 'cross-entry scenario should be unpreloaded');
let rejected = false;
try { await handler.resolve(new URL('skill://start-review'), { skills: [] }); }
catch (error) { rejected = /not found|unknown skill/i.test(error.message); }
assert(rejected, 'entry access must fail for absent inventory');
BUN
fresh_discovery() {
  local phase="$1" cwd="$2" project="$3"
  # A new Bun process means discovery is anchored to this spawning-session CWD.
  (cd "$cwd" && HOME="$TMP_HOME" PI_CODING_AGENT_DIR="$TMP_HOME/.omp/agent" \
    PI_PACKAGE_DIR="$pkg_dir" OMP_PACKAGE_DIR="$pkg_dir" \
    DISCOVER_CWD="$cwd" EXPECT_PROJECT="$project" PROOF_PHASE="$phase" \
    CANONICAL_ROOT="$REPO_ROOT" bun "$assertions_js") || fail "fresh $phase discovery failed"
}
fresh_discovery foreign "$TMP_ROOT/foreign" 0
fresh_discovery spawning "$spawn_cwd" 1
fresh_discovery allocated "$allocated_cwd" 1
fresh_discovery revision "$revision_cwd" 1
printf '%s: PASS (%s); no live model, native action, Claude or hard-confinement proof\n' "$TEST_NAME" "$proof_scope"
