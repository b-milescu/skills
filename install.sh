#!/usr/bin/env bash
# install.sh — idempotently surface skills via symlinks.
#
#   Skills:  <repo>/<skill>/ → ~/.claude/skills/<skill>     (Claude Code)
#                           → ~/.pi/agent/skills/<skill>   (pi agent)
#
# Each skill destination is skipped if its parent directory (e.g. ~/.claude/,
# ~/.pi/agent/) doesn't exist — that agent simply isn't installed on this host.
# Safe to re-run after adding/removing skills. Refuses to overwrite non-symlink
# targets — fix those by hand.

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

for skill_dir in "${SKILL_DESTS[@]}"; do
  parent=$(dirname "$skill_dir")
  if [[ ! -d "$parent" ]]; then
    printf 'skip: %s (parent %s not present — agent not installed)\n' "$skill_dir" "$parent"
    continue
  fi
  mkdir -p "$skill_dir"
  echo "Skills → $skill_dir"
  for dir in "$REPO_ROOT"/*/; do
    [[ -f "$dir/SKILL.md" ]] || continue
    name=$(basename "$dir")
    link "$REPO_ROOT/$name" "$skill_dir/$name"
  done
done

echo "done"
