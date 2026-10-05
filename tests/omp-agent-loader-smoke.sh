#!/usr/bin/env bash
# Focus: The installed OMP client (`omp` on PATH) in a disposable HOME: native
# marketplace installation of the candidate, route selection observed in a fresh
# client process per phase, and canonical skill access through the client. No OMP
# source, prompt, model call or native operation; N/A without `omp`.
set -euo pipefail
shopt -s nullglob
TEST_NAME="omp-agent-loader-smoke"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$REPO_ROOT/tests/lib/assertions.sh"
omp_bin="$(command -v omp || true)"
if [[ -z "$omp_bin" ]]; then
  [[ "${OMP_REQUIRE_LOADER:-0}" != 1 ]] || fail 'required installed OMP client (omp) not on PATH'
  printf '%s: installed-client proof N/A (omp not on PATH)\n' "$TEST_NAME"
  exit 0
fi
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/omp-agent-loader-smoke.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT
TMP_ROOT="$(cd "$TMP_ROOT" && pwd -P)"
TMP_HOME="$TMP_ROOT/home"
mkdir -p "$TMP_HOME/.omp/agent" "$TMP_ROOT/tmp" "$TMP_ROOT/foreign"
# Only PATH crosses into the client: no inherited credentials, profile or
# configuration. RPC startup needs an available model, so the disposable HOME
# declares a placeholder at an unreachable local address; no prompt is ever sent.
client() {
  env -i PATH="$PATH" HOME="$TMP_HOME" TMPDIR="$TMP_ROOT/tmp" OMP_SKIP_SETUP=1 "$omp_bin" "$@"
}
cat > "$TMP_HOME/.omp/agent/models.yml" <<'YAML'
providers:
  loader-smoke:
    baseUrl: http://127.0.0.1:9/v1
    apiKey: placeholder
    api: openai-completions
    models:
      - id: placeholder
YAML
version="$(client --version)" || fail 'omp --version failed'
printf '%s: client %s at %s\n' "$TEST_NAME" "$version" "$omp_bin"

# The client's own marketplace commands install a candidate copy. Both plugin
# dialects share each route description, so the copy (only) marks the
# Claude-dialect files to make their selection observable.
candidate="$TMP_ROOT/candidate"
marker=' [claude-dialect]'
mkdir -p "$candidate"
(cd "$REPO_ROOT" && tar --exclude .git --exclude node_modules -cf - .) | (cd "$candidate" && tar -xf -)
for file in "$candidate"/agents/claude/*.md; do
  sed "s/^description: .*/&$marker/" "$file" > "$file.marked" && mv "$file.marked" "$file"
done
(cd "$TMP_ROOT/foreign" && client plugin marketplace add "$candidate" && client plugin install skills@skills) >/dev/null \
  || fail 'client marketplace installation failed'
native_root="$(cd "$TMP_ROOT/foreign" && client plugin list --json | bun -e '
const roots = JSON.parse(await Bun.stdin.text()).marketplace.filter((p) => p.id === "skills@skills").flatMap((p) => p.entries.map((e) => e.installPath));
if (roots.length !== 1) process.exit(1);
console.log(roots[0]);')" || fail 'client lists no single skills@skills installation'
native_root="$(cd "$native_root" && pwd -P)" || fail "installed root missing: $native_root"
[[ "$native_root" == "$TMP_HOME"/* ]] || fail "installed root outside the disposable HOME: $native_root"

spawn_cwd="${OMP_SPAWN_CWD:-$REPO_ROOT}"
allocated_cwd="${OMP_ALLOCATED_CWD:-}"
revision_cwd="${OMP_REVISION_CWD:-}"
proof_scope='independently supplied checkouts'
if [[ -z "$allocated_cwd" || -z "$revision_cwd" ]]; then
  [[ -z "$allocated_cwd" && -z "$revision_cwd" ]] || fail 'supply both allocated and revision checkout paths'
  proof_scope='disposable filesystem checkout copies (not live allocated/revision sessions)'
  allocated_cwd="$TMP_ROOT/allocated"
  revision_cwd="$TMP_ROOT/revision"
  # The copies also carry each route's project Claude-dialect file, marked like
  # the plugin's; the spawning and supplied checkouts are never edited.
  for checkout in "$allocated_cwd" "$revision_cwd"; do
    mkdir -p "$checkout/.omp/agents" "$checkout/.claude/agents"
    cp "$REPO_ROOT/.omp/agents/"*.md "$checkout/.omp/agents/"
    for file in "$REPO_ROOT/.claude/agents/"*.md; do
      sed "s/^description: .*/&$marker/" "$file" > "$checkout/.claude/agents/${file##*/}"
    done
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

# The client reports selection only as each route's description in the `task`
# tool inventory, so a description must identify exactly one candidate file.
selection_js="$TMP_ROOT/selection.mjs"
cat > "$selection_js" <<'BUN'
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
const [rpc, phase, cwd, project, root, marker, repo] = process.argv.slice(2);
const { default: yaml } = await import(pathToFileURL(path.join(repo, 'start-build/scripts/vendor/js-yaml.mjs')).href);
function fail(message) { console.error(`${phase}: ${message}`); process.exit(1); }
const state = fs.readFileSync(rpc, 'utf8').split('\n').filter(Boolean).map((line) => JSON.parse(line))
  .find((frame) => frame.type === 'response' && frame.command === 'get_state' && frame.success)?.data;
if (!state) fail('no get_state response');
if (state.messageCount !== 0 || state.model?.baseUrl !== 'http://127.0.0.1:9/v1') {
  fail(`session is not prompt-free on the placeholder model: ${state.model?.baseUrl}, ${state.messageCount} messages`);
}
const inventory = state.dumpTools?.find((tool) => tool.name === 'task')?.description ?? '';
const listed = new Map([...inventory.matchAll(/^- `([^`]+)`(?: \([^)]*\))?: (.*)$/gm)].map((match) => [match[1], match[2]]));
const frontmatter = (file) => yaml.load(fs.readFileSync(file, 'utf8').split(/^---$/m)[1]);
for (const [name, entry] of [['change-builder', 'start-build'], ['change-reviewer-final', 'start-review']]) {
  const files = { plugin: path.join(root, 'agents', `${name}.md`), 'Claude-dialect plugin': path.join(root, 'agents/claude', `${name}.md`) };
  if (project === '1') files.project = path.join(cwd, '.omp/agents', `${name}.md`);
  const want = project === '1' ? 'project' : 'plugin';
  const seen = listed.get(name);
  if (seen === undefined) fail(`${name} is missing from the client's task inventory`);
  // OMP must never select the checkout's project Claude-dialect file; only the smoke's own copies mark it.
  const claude = path.join(cwd, '.claude/agents', `${name}.md`);
  const claudeShares = fs.existsSync(claude) && frontmatter(claude).description === seen;
  if (seen.endsWith(marker) && claudeShares) fail(`${name}: client selected the project Claude-dialect file ${claude}`);
  if (seen.endsWith(marker)) fail(`${name}: client selected the Claude-dialect plugin file`);
  // An installer rewrites a symlink into an absolute link outside the install, so the entrypoint must be a regular file.
  if (!fs.lstatSync(files[want], { throwIfNoEntry: false })?.isFile()) fail(`${name}: ${files[want]} is not a regular file; client listed "${seen}"`);
  const meta = frontmatter(files[want]);
  if (seen !== meta.description) fail(`${name}: client listed "${seen}", not ${files[want]}`);
  for (const [kind, file] of Object.entries(files)) {
    if (kind !== want && fs.existsSync(file) && frontmatter(file).description === seen) fail(`${name}: ${kind} file ${file} shares the description; selection unprovable`);
  }
  const preload = String(meta['autoload-skills'] ?? '').split(',').map((skill) => skill.trim()).sort().join();
  if (preload !== [entry, 'forge'].sort().join()) fail(`${name}: preload must be exactly ${entry} and forge`);
  // An omitted `tools` list inherits the parent's tools; any declared list would be a restriction.
  if (meta.tools !== undefined) fail(`${name}: route must not declare tools`);
  const limit = claudeShares ? { limit: `${claude} shares the description, so this phase cannot distinguish the two project dialects` } : {};
  console.log(JSON.stringify({ proof: 'selected-route', phase, cwd, name, selected: want, filePath: files[want], description: seen, ...limit }));
}
BUN
observe() {
  local phase="$1" cwd="$2" project="$3" name line file out="$TMP_ROOT/read.out"
  # A fresh client process anchored at this phase's CWD answers one state request.
  printf '%s\n' '{"type":"get_state"}' | (cd "$cwd" && client --mode rpc --no-session --no-title) > "$TMP_ROOT/$phase.rpc" \
    || fail "$phase: client RPC session failed"
  bun "$selection_js" "$TMP_ROOT/$phase.rpc" "$phase" "$cwd" "$project" "$native_root" "$marker" "$REPO_ROOT" \
    | tee "$TMP_ROOT/$phase.routes" || fail "$phase: route selection not proven"
  if grep -q '"limit":' "$TMP_ROOT/$phase.routes"; then
    proof_scope+="; $phase phase cannot distinguish the project .omp and .claude dialects"
  fi
  for name in start-build start-review forge; do
    (cd "$cwd" && client read "skill://$name") > "$out" || fail "$phase: skill://$name unreadable"
    IFS= read -r line < "$out" || true
    file="${line#\[Skill file: }"
    file="${file%]}"
    [[ "$file" -ef "$native_root/$name/SKILL.md" ]] || fail "$phase: skill://$name resolved outside the installed root: $line"
    (cd "$cwd" && client read "skill://$name:raw") > "$out" || fail "$phase: skill://$name:raw unreadable"
    cmp -s "$out" "$native_root/$name/SKILL.md" || fail "$phase: skill://$name bytes differ from the installed entry"
    printf '{"proof":"skill-entry","phase":"%s","name":"%s","filePath":"%s"}\n' "$phase" "$name" "$file"
  done
}
observe foreign "$TMP_ROOT/foreign" 0
observe spawning "$spawn_cwd" 1
observe allocated "$allocated_cwd" 1
observe revision "$revision_cwd" 1

for resource in start-build/SAFETY.md start-build/reference/issue-pickup.md \
  start-review/templates/filling-guide.md plan-to-issues/templates/issue-body.md; do
  (cd "$TMP_ROOT/foreign" && client read "skill://$resource:raw") > "$TMP_ROOT/read.out" || fail "skill://$resource unreadable"
  cmp -s "$TMP_ROOT/read.out" "$native_root/$resource" || fail "skill://$resource bytes differ from the installed resource"
done
if (cd "$TMP_ROOT/foreign" && client read skill://definitely-absent-skill) > "$TMP_ROOT/read.out" 2>&1; then
  fail 'client accepted an absent skill'
fi
assert_file_contains "$TMP_ROOT/read.out" 'Unknown skill' 'absent-skill rejection'
# Skills link shared docs by plain relative paths (no symlink: an installer
# rewrites it into an absolute link), so each must be a regular file there.
for doc in reference/decoupling-contract.md templates/filling-guide.md reference/agent-readiness-scorecard.md; do
  [[ -f "$native_root/$doc" && ! -L "$native_root/$doc" ]] || fail "shared doc is not a regular file in the installed tree: $doc"
done
printf '%s: PASS (%s; %s at %s); no prompt, model call, native action or Claude proof\n' \
  "$TEST_NAME" "$proof_scope" "$version" "$omp_bin"
