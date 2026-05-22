#!/usr/bin/env bash
# install.sh — idempotently surface skills and agents via symlinks.
#
#   Skills:  <repo>/<skill>/  → ~/.claude/skills/<skill>   (Claude Code)
#                            → ~/.pi/agent/skills/<skill> (pi agent)
#
#   Agents:  <repo>/agents/<name>.md → ~/.claude/agents/<name>.md   (Claude Code)
#                                  → ~/.pi/agent/agents/<name>.md (pi agent)
#
# Each destination is skipped if its parent directory (e.g. ~/.claude/,
# ~/.pi/agent/) doesn't exist — that agent simply isn't installed on this host.
# Safe to re-run after adding/removing skills or agents. Refuses to overwrite
# non-symlink targets — fix those by hand. Stale repo-owned symlinks are pruned
# so renames propagate cleanly.

set -euo pipefail
shopt -s nullglob

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SKILL_DESTS=(
  "$HOME/.claude/skills"
  "$HOME/.pi/agent/skills"
)

if realpath --relative-to=/ / >/dev/null 2>&1; then
  REALPATH=realpath
elif command -v grealpath >/dev/null 2>&1; then
  REALPATH=grealpath
else
  echo "install.sh: GNU realpath required (on macOS: brew install coreutils)" >&2
  exit 1
fi

SKILL_NAMES=()
for dir in "$REPO_ROOT"/*/; do
  [[ -f "$dir/SKILL.md" ]] || continue
  SKILL_NAMES+=("$(basename "$dir")")
done

AGENT_NAMES=()
if [[ -d "$REPO_ROOT/agents" ]]; then
  for f in "$REPO_ROOT/agents"/*.md; do
    [[ -f "$f" ]] || continue
    AGENT_NAMES+=("$(basename "$f" .md)")
  done
fi

is_skill_name() {
  local name="$1" known
  for known in "${SKILL_NAMES[@]}"; do
    [[ "$known" == "$name" ]] && return 0
  done
  return 1
}

is_agent_name() {
  local name="$1" known
  for known in "${AGENT_NAMES[@]}"; do
    [[ "$known" == "$name" ]] && return 0
  done
  return 1
}

link() {
  local src="$1" dest="$2"
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    printf '  skip:    %s (exists, not a symlink — resolve by hand)\n' "$dest" >&2
    return
  fi
  local rel
  rel=$("$REALPATH" --relative-to="$(dirname "$dest")" "$src")
  ln -sfn "$rel" "$dest"
  printf '  linked:  %s -> %s\n' "$dest" "$rel"
}

prune_stale_repo_links() {
  local dir="$1" validator="$2"
  local link_path name target target_abs

  for link_path in "$dir"/*; do
    [[ -L "$link_path" ]] || continue

    name=$(basename "$link_path")
    "$validator" "$name" && continue

    target=$(readlink "$link_path") || continue
    if [[ "$target" == /* ]]; then
      target_abs=$("$REALPATH" -m "$target")
    else
      target_abs=$("$REALPATH" -m "$(dirname "$link_path")/$target")
    fi

    case "$target_abs" in
      "$REPO_ROOT"/*)
        rm "$link_path"
        printf '  removed: %s (stale repo-owned symlink)\n' "$link_path"
        ;;
    esac
  done
}

# --- Skills ---
for skill_dir in "${SKILL_DESTS[@]}"; do
  parent=$(dirname "$skill_dir")
  if [[ ! -d "$parent" ]]; then
    printf 'skip: %s (parent %s not present — agent not installed)\n' "$skill_dir" "$parent"
    continue
  fi
  mkdir -p "$skill_dir"
  echo "Skills → $skill_dir"
  prune_stale_repo_links "$skill_dir" is_skill_name
  for name in "${SKILL_NAMES[@]}"; do
    link "$REPO_ROOT/$name" "$skill_dir/$name"
  done
done

# --- Agents ---
AGENT_DESTS=(
  "$HOME/.claude/agents"
  "$HOME/.pi/agent/agents"
)

for agent_dir in "${AGENT_DESTS[@]}"; do
  parent=$(dirname "$agent_dir")
  if [[ ! -d "$parent" ]]; then
    printf 'skip: %s (parent %s not present — agent not installed)\n' "$agent_dir" "$parent"
    continue
  fi
  mkdir -p "$agent_dir"
  echo "Agents → $agent_dir"
  prune_stale_repo_links "$agent_dir" is_agent_name
  for name in "${AGENT_NAMES[@]}"; do
    link "$REPO_ROOT/agents/$name.md" "$agent_dir/$name.md"
  done
done

echo "done"
