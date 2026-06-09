#!/usr/bin/env bash
# Regression: install.sh exposes agents/pi/*.md to the real pi-subagents loader.
#
# Proves a clean temp-HOME install surfaces every Pi agent to the runtime's
# user-scope discovery, and that the loaded runtime metadata matches the intended
# Pi routing config (shared tool allowlist, direct MCP selections, prompt/skill
# inheritance, and per-agent model/thinking pins).
#
# The loader-specific assertions need the installed `pi-subagents` package (plus
# its bundled jiti TypeScript loader). When that package is not provisioned in the
# environment (e.g. CI without a Pi runtime), the loader portion reports a clear
# N/A and the test still verifies the installer exposed every Pi agent file. The
# loader is pointed at the temp runtime through PI_CODING_AGENT_DIR/HOME so it
# never reads the operator's live ~/.pi or ~/.agents user agents.

set -euo pipefail
shopt -s nullglob

TEST_NAME="pi-agent-loader-smoke"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=tests/lib/assertions.sh
source "$REPO_ROOT/tests/lib/assertions.sh"

command -v node >/dev/null 2>&1 || fail "node required to run this test"

# GNU realpath for symlink resolution (matches install.sh and sibling tests).
if realpath --relative-to=/ / >/dev/null 2>&1; then
  REALPATH=realpath
elif command -v grealpath >/dev/null 2>&1; then
  REALPATH=grealpath
else
  fail "GNU realpath required"
fi

PI_SOURCE_DIR="$REPO_ROOT/agents/pi"
[[ -d "$PI_SOURCE_DIR" ]] || fail "missing Pi agent source dir: $PI_SOURCE_DIR"

# Expected Pi agent names derive from agents/pi/*.md — the single source of truth
# for the agent set; the loader discovery and golden pin table are checked
# against it below.
expected_names=()
for f in "$PI_SOURCE_DIR"/*.md; do
  expected_names+=("$(basename "$f" .md)")
done
[[ ${#expected_names[@]} -gt 0 ]] || fail "no Pi agent files found in $PI_SOURCE_DIR"

# --- Temporary Pi runtime + clean install ------------------------------------
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/pi-agent-loader-smoke.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT
TMP_HOME="$TMP_ROOT/home"
DISCOVER_CWD="$TMP_ROOT/project" # empty: keeps project-scope discovery silent
# install.sh skips any target whose parent dir is absent, so pre-create the Pi
# runtime roots it links into.
mkdir -p \
  "$TMP_HOME/.pi/agent/agents" \
  "$TMP_HOME/.pi/agent/skills" \
  "$DISCOVER_CWD"

install_out="$TMP_ROOT/install.out"
HOME="$TMP_HOME" "$REPO_ROOT/install.sh" >"$install_out" 2>&1 \
  || { cat "$install_out" >&2; fail "install.sh failed against temp runtime"; }

agents_dir="$TMP_HOME/.pi/agent/agents"

# Installer-exposure proof (no loader required): every expected Pi agent is a
# symlink in the temp runtime resolving back into agents/pi/.
for name in "${expected_names[@]}"; do
  link="$agents_dir/$name.md"
  [[ -L "$link" ]] || fail "install did not expose Pi agent symlink: $link"
  target="$(readlink "$link")"
  if [[ "$target" == /* ]]; then
    target_abs="$("$REALPATH" -m "$target")"
  else
    target_abs="$("$REALPATH" -m "$agents_dir/$target")"
  fi
  expected_abs="$("$REALPATH" -m "$PI_SOURCE_DIR/$name.md")"
  assert_equals "$expected_abs" "$target_abs" "Pi agent symlink target for $name"
done

# --- Locate the installed pi-subagents loader (no host-bound literal paths) ---
# The real Pi agent dir is where the loader package is provisioned; resolve it
# from PI_CODING_AGENT_DIR / HOME before discovery is pointed at the temp runtime.
real_agent_dir="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
pkg_dir=""
for cand in \
  "${PI_SUBAGENTS_DIR:-}" \
  "$real_agent_dir/npm/node_modules/pi-subagents" \
  "$HOME/.pi/agent/npm/node_modules/pi-subagents"; do
  [[ -n "$cand" && -f "$cand/src/agents/agents.ts" ]] || continue
  pkg_dir="$cand"
  break
done

jiti_path=""
if [[ -n "$pkg_dir" ]]; then
  for cand in \
    "${PI_SUBAGENTS_JITI:-}" \
    "$pkg_dir/node_modules/jiti/lib/jiti.mjs" \
    "$real_agent_dir/npm/node_modules/jiti/lib/jiti.mjs" \
    "$HOME/.pi/agent/npm/node_modules/jiti/lib/jiti.mjs"; do
    [[ -n "$cand" && -f "$cand" ]] || continue
    jiti_path="$cand"
    break
  done
fi

if [[ -z "$pkg_dir" || -z "$jiti_path" ]]; then
  printf '%s: N/A loader assertions — pi-subagents loader not provisioned (set PI_SUBAGENTS_DIR to enable); installer exposure verified for %d Pi agents\n' \
    "$TEST_NAME" "${#expected_names[@]}"
  printf '%s: PASS\n' "$TEST_NAME"
  exit 0
fi

# --- Real loader discovery against the temp runtime --------------------------
# PI_CODING_AGENT_DIR aims the loader's user-scope discovery at the temp runtime;
# HOME isolates os.homedir()/.agents so the operator's live user agents cannot
# leak into the result.
expected_names_nl="$(printf '%s\n' "${expected_names[@]}")"
HOME="$TMP_HOME" \
PI_CODING_AGENT_DIR="$TMP_HOME/.pi/agent" \
PI_SUBAGENTS_PKG="$pkg_dir" \
PI_SUBAGENTS_JITI="$jiti_path" \
DISCOVER_CWD="$DISCOVER_CWD" \
EXPECTED_NAMES="$expected_names_nl" \
node --input-type=module - <<'NODE' || fail "pi-subagents loader assertions failed"
import { pathToFileURL } from "node:url";

const jitiPath = process.env.PI_SUBAGENTS_JITI;
const pkgDir = process.env.PI_SUBAGENTS_PKG;
const cwd = process.env.DISCOVER_CWD;
const expectedNames = (process.env.EXPECTED_NAMES || "")
  .split("\n").map((s) => s.trim()).filter(Boolean).sort();

// Shared metadata every Pi MR agent must expose (stable invariant, not defaults).
const COMMON_TOOLS = ["read", "grep", "find", "ls", "bash", "edit", "write", "intercom"];
const COMMON_MCP = ["gitlab-mcp", "wowtools-mcp"];
// Golden routing config per agent; `model: null` marks a base agent with no pin.
// Cross-checked against the filesystem-derived name set so a new/removed/renamed
// Pi agent fails until this table is updated.
const EXPECTED_PINS = {
  "mr-builder": { model: null, thinking: "high" },
  "mr-builder-opus48": { model: "anthropic/claude-opus-4-8", thinking: "medium" },
  "mr-builder-opus48-high": { model: "anthropic/claude-opus-4-8", thinking: "high" },
  "mr-builder-sonnet-low": { model: "anthropic/claude-sonnet-4-6", thinking: "low" },
  "mr-review-scout-gpt54-low": { model: "openai-codex/gpt-5.4", thinking: "low" },
  "mr-reviewer": { model: null, thinking: "high" },
  "mr-reviewer-gpt55-xhigh": { model: "openai-codex/gpt-5.5", thinking: "xhigh" },
  "mr-reviewer-opus48-xhigh": { model: "anthropic/claude-opus-4-8", thinking: "xhigh" },
};

const eqArr = (a, b) =>
  Array.isArray(a) && Array.isArray(b) && a.length === b.length && a.every((v, i) => v === b[i]);

const failures = [];

// Load the real loader through jiti (the package's bundled TS loader); native
// type stripping is unsupported under node_modules.
const { createJiti } = await import(pathToFileURL(jitiPath).href);
const jiti = createJiti(pathToFileURL(`${pkgDir}/src/agents/`).href);
const mod = await jiti.import(`${pkgDir}/src/agents/agents.ts`);
if (typeof mod.discoverAgents !== "function") {
  console.error(`${process.env.TEST_NAME || "pi-agent-loader-smoke"}: loader missing discoverAgents export`);
  process.exit(2);
}

// User-scope discovery is exactly what the Pi runtime runs to find installed agents.
const { agents } = mod.discoverAgents(cwd, "user");
const user = agents.filter((a) => a.source === "user");
const byName = new Map(user.map((a) => [a.localName ?? a.name, a]));

// Triangulate the agent set: filesystem glob <-> loader discovery <-> golden table.
const discovered = [...byName.keys()].sort();
if (!eqArr(discovered, expectedNames)) {
  failures.push(`user-scope discovery ${JSON.stringify(discovered)} != agents/pi/*.md ${JSON.stringify(expectedNames)}`);
}
const pinKeys = Object.keys(EXPECTED_PINS).sort();
if (!eqArr(pinKeys, expectedNames)) {
  failures.push(`EXPECTED_PINS keys ${JSON.stringify(pinKeys)} != agents/pi/*.md ${JSON.stringify(expectedNames)} (update the golden pin table)`);
}

for (const name of expectedNames) {
  const a = byName.get(name);
  if (!a) {
    failures.push(`${name}: not discovered by user-scope loader`);
    continue;
  }
  if (!eqArr(a.tools, COMMON_TOOLS)) failures.push(`${name}: tools ${JSON.stringify(a.tools)} != ${JSON.stringify(COMMON_TOOLS)}`);
  if (!eqArr(a.mcpDirectTools, COMMON_MCP)) failures.push(`${name}: mcpDirectTools ${JSON.stringify(a.mcpDirectTools)} != ${JSON.stringify(COMMON_MCP)}`);
  if (a.systemPromptMode !== "replace") failures.push(`${name}: systemPromptMode ${JSON.stringify(a.systemPromptMode)} != "replace"`);
  if (a.inheritProjectContext !== true) failures.push(`${name}: inheritProjectContext ${JSON.stringify(a.inheritProjectContext)} != true`);
  if (a.inheritSkills !== true) failures.push(`${name}: inheritSkills ${JSON.stringify(a.inheritSkills)} != true`);
  if (a.defaultContext !== "fresh") failures.push(`${name}: defaultContext ${JSON.stringify(a.defaultContext)} != "fresh"`);
  if (!(typeof a.systemPrompt === "string" && a.systemPrompt.trim().length > 0)) failures.push(`${name}: empty system prompt`);

  const pin = EXPECTED_PINS[name];
  if (pin) {
    const actualModel = a.model ?? null;
    if (actualModel !== pin.model) failures.push(`${name}: model ${JSON.stringify(actualModel)} != ${JSON.stringify(pin.model)}`);
    if ((a.thinking ?? null) !== pin.thinking) failures.push(`${name}: thinking ${JSON.stringify(a.thinking ?? null)} != ${JSON.stringify(pin.thinking)}`);
  }
}

// Base agents must not carry a model pin (independent of the golden table).
for (const base of ["mr-builder", "mr-reviewer"]) {
  const a = byName.get(base);
  if (a && (a.model ?? null) !== null) {
    failures.push(`${base}: unexpected model pin ${JSON.stringify(a.model)} on base agent`);
  }
}

if (failures.length) {
  for (const f of failures) console.error(`pi-agent-loader-smoke: ${f}`);
  process.exit(1);
}
console.error(`pi-agent-loader-smoke: loader verified ${user.length} user-scope Pi agents`);
NODE

printf '%s: PASS\n' "$TEST_NAME"
