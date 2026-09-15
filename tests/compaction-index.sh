#!/usr/bin/env bash
# Focus: compaction-index regression: the skill-index extension keeps
# `session.compacting` re-injection deduped, within per-entry 2 KiB and total
# 16 KiB caps and free of full skill bodies, and `install.sh` links it into
# `~/.omp/agent/extensions/` while skipping and reporting when the OMP agent
# dir is absent. Pure local: fixture skill tree via COMPACT_INDEX_SKILL_ROOT
# and temp HOMEs for the installer.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
EXTENSION="$ROOT_DIR/compaction-index/extensions/compaction-skill-index.js"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# --- fixtures ---
SKILLS="$TMPDIR/skills"
BODY_MARKER="CI-BODY-MARKER-do-not-leak"
mkdir -p "$SKILLS/alpha" "$SKILLS/beta"
printf 'name: alpha\ndescription: Alpha scope note.\n---\n# Alpha\n%s full alpha body text that must never be re-injected\n' "$BODY_MARKER" \
  > "$SKILLS/alpha/SKILL.md"
printf 'name: beta\ndescription: Beta scope note.\n' > "$SKILLS/beta/SKILL.md"

# A skill whose description alone exceeds the per-entry cap.
LONG_NOTE="$(printf 'L%.0s' $(seq 1 5000))"
mkdir -p "$SKILLS/longone"
printf 'name: longone\ndescription: %s\n' "$LONG_NOTE" > "$SKILLS/longone/SKILL.md"

# Enough ~1.9 KiB-entry skills to blow the 16 KiB total cap.
for i in $(seq 1 12); do
  mkdir -p "$SKILLS/cap$i"
  printf 'name: cap%d\ndescription: %s\n' "$i" "$(printf 'c%.0s' $(seq 1 1900))" > "$SKILLS/cap$i/SKILL.md"
done

run_case() {
  COMPACT_INDEX_SKILL_ROOT="$SKILLS" node --input-type=module -e "$1" "$EXTENSION"
}

# --- dedupe, scope note, URI, and no full bodies ---
OUT="$(run_case '
const { default: ext } = await import(process.argv[1])
let handler; ext({ on: (t, h) => { if (t === "session.compacting") handler = h } })
const r = handler({ messages: [{ content: [{ text: "read skill://alpha/docs/deep.md and skill://alpha and skill://beta. '"$BODY_MARKER"'" }] }] })
console.log(r.context.join("\n"))
')"
[[ "$(printf '%s\n' "$OUT" | grep -c -- '- alpha ')" == "1" ]] || { echo "alpha not deduped to one entry" >&2; exit 1; }
grep -q -- '- alpha — skill://alpha — Alpha scope note.' <<<"$OUT" || { echo "alpha entry missing name/URI/scope note" >&2; exit 1; }
grep -q -- '- beta — skill://beta — Beta scope note.' <<<"$OUT" || { echo "beta entry missing" >&2; exit 1; }
if grep -q "$BODY_MARKER" <<<"$OUT"; then echo "full skill body leaked into index" >&2; exit 1; fi

# --- no context when no skill:// reads ---
EMPTY="$(run_case '
const { default: ext } = await import(process.argv[1])
let handler; ext({ on: (t, h) => { if (t === "session.compacting") handler = h } })
console.log(JSON.stringify(handler({ messages: [{ content: [{ text: "no skill reads here" }] }] })))
')"
[[ "$EMPTY" == "{}" ]] || { echo "expected empty result for skill-free session, got: $EMPTY" >&2; exit 1; }

# --- per-entry ~2 KiB cap ---
PER_ENTRY="$(run_case '
const { default: ext } = await import(process.argv[1])
let handler; ext({ on: (t, h) => { if (t === "session.compacting") handler = h } })
const r = handler({ messages: [{ content: [{ text: "skill://longone" }] }] })
console.log(r.context[1].length)
')"
(( PER_ENTRY <= 2048 )) || { echo "per-entry cap exceeded: $PER_ENTRY" >&2; exit 1; }

# --- total ~16 KiB cap with truncation notice ---
TOTAL_CASE="$(run_case '
const { default: ext } = await import(process.argv[1])
let handler; ext({ on: (t, h) => { if (t === "session.compacting") handler = h } })
const text = Array.from({ length: 12 }, (_, i) => "skill://cap" + (i + 1)).join(" ")
const r = handler({ messages: [{ content: [{ text }] }] })
console.log(r.context.map(l => l.length).reduce((a, b) => a + b + 1, 0))
console.log(r.context[r.context.length - 1])
')"
TOTAL_BYTES="$(sed -n 1p <<<"$TOTAL_CASE")"
LAST_LINE="$(sed -n 2p <<<"$TOTAL_CASE")"
(( TOTAL_BYTES <= 16384 + 200 )) || { echo "total cap exceeded: $TOTAL_BYTES" >&2; exit 1; }
grep -q "truncated at 16384" <<<"$LAST_LINE" || { echo "missing truncation notice, last line: $LAST_LINE" >&2; exit 1; }

# --- installer: link when OMP agent dir exists ---
LINK_HOME="$TMPDIR/home-link"
mkdir -p "$LINK_HOME/.omp/agent"
HOME="$LINK_HOME" bash "$ROOT_DIR/install.sh" > "$TMPDIR/install-link.log" 2>&1
[[ -L "$LINK_HOME/.omp/agent/extensions/compaction-skill-index.js" ]] || {
  echo "extension not symlinked into ~/.omp/agent/extensions" >&2
  cat "$TMPDIR/install-link.log" >&2
  exit 1
}
target="$(readlink -f "$LINK_HOME/.omp/agent/extensions/compaction-skill-index.js")"
[[ "$target" == "$EXTENSION" ]] || { echo "extension symlink points at $target" >&2; exit 1; }

# --- installer: skip + report when OMP agent dir absent ---
SKIP_HOME="$TMPDIR/home-skip"
mkdir -p "$SKIP_HOME/.claude"
HOME="$SKIP_HOME" bash "$ROOT_DIR/install.sh" > "$TMPDIR/install-skip.log" 2>&1
grep -q "skip: .*/.omp/agent/extensions (parent .* not present" "$TMPDIR/install-skip.log" || {
  echo "installer did not report extension skip when ~/.omp/agent is absent" >&2
  cat "$TMPDIR/install-skip.log" >&2
  exit 1
}
[[ ! -e "$SKIP_HOME/.omp" ]] || { echo "installer created ~/.omp despite skip" >&2; exit 1; }

echo "compaction-index: PASS"
