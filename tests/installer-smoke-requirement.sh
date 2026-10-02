#!/usr/bin/env bash
# Focus: disposable-HOME install, real installed helpers from foreign CWD and
# read-only --check behavior.
# Native project declarations must not become global runtime defaults.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/installer-smoke.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT
home="$TMP_ROOT/home"
mkdir -p "$home/.claude" "$home/.omp/agent"
HOME="$home" "$REPO_ROOT/install.sh" >"$TMP_ROOT/install.out" 2>&1
for runtime in "$home/.claude/skills" "$home/.omp/agent/skills"; do
  for skill in forge start-build start-review issue-delivery-loop; do
    [[ -L "$runtime/$skill" && -f "$runtime/$skill/SKILL.md" ]] || {
      echo "missing installed skill entry: $runtime/$skill" >&2; exit 1;
    }
  done
  [[ ! -e "$runtime/gitlab" && ! -L "$runtime/gitlab" ]] || {
    echo 'retired skill remains installed' >&2; exit 1;
  }
done
for dialect in claude omp; do
  if [[ "$dialect" == claude ]]; then dir="$home/.claude/agents"; else dir="$home/.omp/agent/agents"; fi
  for name in mr-builder mr-reviewer-final; do
    [[ -L "$dir/$name.md" && "$dir/$name.md" -ef "$REPO_ROOT/agents/$dialect/$name.md" ]] || {
      echo "global route does not resolve to reusable preset: $dir/$name.md" >&2; exit 1;
    }
  done
done
# Use resolved filesystem paths from each installed skill, never target-CWD
# relative paths or node skill:// URLs. These are local validity/access proofs,
# not native receipt extraction, report scope or post-note verification.
node --input-type=module - "$TMP_ROOT" "$home" <<'NODE'
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
const [temp, home] = process.argv.slice(2);
const foreign = path.join(temp, 'foreign-target');
fs.mkdirSync(foreign);
for (const runtime of [path.join(home, '.claude/skills'), path.join(home, '.omp/agent/skills')]) {
  const resolve = (relative) => fs.realpathSync(path.join(runtime, relative));
  const schema = fs.readFileSync(resolve('start-build/templates/reviewer-lift-schema.md'), 'utf8');
  const fields = schema.split('\n').filter(line => line.startsWith('|'))
    .map(line => line.split('|')[1].trim())
    .filter(field => field !== 'Field' && !/^-+$/.test(field));
  const invoke = (helper, args) => {
    const file = resolve(helper);
    console.log(`installed helper: ${file}; execution cwd: ${foreign}`);
    execFileSync(process.execPath, [file, ...args], { cwd: foreign, stdio: 'inherit' });
  };
  for (const owner of ['parent', 'builder']) {
    // Every schema row is present before any receipt exists. Native identity and
    // stronger stage/value validation are deliberately not claimed by lift-only.
    const values = new Map([
      ['Gate owner', owner], ['Finding bindings', 'none'],
      ['Local gate', 'not-run — local presence-only installer scenario'],
      ['Finish authority', 'none — requires explicit human/parent instruction'],
    ]);
    const packet = path.join(foreign, `${owner}-review-packet.md`);
    fs.writeFileSync(packet, [
      '<!-- REVIEWER-LIFT-SCHEMA:BEGIN generated-copy from start-build/templates/reviewer-lift-schema.md -->',
      '| Field | Value |', '|---|---|',
      ...fields.map(field => `| ${field} | ${values.get(field) ?? 'local presence-only installer scenario'} |`),
      '<!-- REVIEWER-LIFT-SCHEMA:END -->', '',
    ].join('\n'));
    invoke('start-build/scripts/validate-gate-receipt.mjs', [
      '--mode', 'lift-only', '--owner', owner, '--review-packet', packet,
    ]);
  }
  const lift = path.join(foreign, 'no-findings-lift.md');
  fs.writeFileSync(lift, '| Finding bindings | none |\n');
  invoke('start-review/scripts/validate-finding-bindings.mjs', ['--lift', lift]);
  const text = path.join(foreign, 'authored-text.json');
  fs.writeFileSync(text, JSON.stringify({ role: 'description', content: 'Installer Unicode scenario: λ 🌍\n\twith allowed whitespace\r\n' }));
  invoke('forge/scripts/validate-text.mjs', ['--input', text]);
}
console.log('installed helper foreign-CWD proof: local validity/access only; no native binding or post-note verification');
NODE
snapshot() { (cd "$home" && find . -printf '%P %y %l %m %T@\n' | LC_ALL=C sort); }
snapshot >"$TMP_ROOT/before"
HOME="$home" "$REPO_ROOT/install.sh" --check >"$TMP_ROOT/check.out" 2>&1
snapshot >"$TMP_ROOT/after"
cmp -s "$TMP_ROOT/before" "$TMP_ROOT/after" || { echo 'read-only check changed HOME' >&2; exit 1; }
printf 'installer-smoke-requirement: PASS\n'
