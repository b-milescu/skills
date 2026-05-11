#!/usr/bin/env bash
# install.sh — idempotently surface skills and shared scripts via symlinks.
#
#   Skills:  <repo>/<skill>/         → ~/.claude/skills/<skill>     (Claude Code)
#                                    → ~/.pi/agent/skills/<skill>   (pi agent)
#   Scripts: <repo>/scripts/*/<name> → ~/.local/bin/<name>          (executable files only)
#
# Each skill destination is skipped if its parent directory (e.g. ~/.claude/,
# ~/.pi/agent/) doesn't exist — that agent simply isn't installed on this host.
# Safe to re-run after adding/removing skills or scripts. Refuses to overwrite
# non-symlink targets — fix those by hand.

set -euo pipefail
shopt -s nullglob

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BIN_DIR="$HOME/.local/bin"
SKILL_DESTS=(
  "$HOME/.claude/skills"
  "$HOME/.pi/agent/skills"
)

realpath --relative-to=/ / >/dev/null 2>&1 || {
  echo "install.sh: GNU realpath required (on macOS: brew install coreutils)" >&2
  exit 1
}

mkdir -p "$BIN_DIR"

link() {
  local src="$1" dest="$2"
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    printf '  skip:    %s (exists, not a symlink — resolve by hand)\n' "$dest" >&2
    return
  fi
  local rel
  rel=$(realpath --relative-to="$(dirname "$dest")" "$src")
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
    name=$(basename "$dir")
    [[ "$name" == "scripts" ]] && continue
    link "$REPO_ROOT/$name" "$skill_dir/$name"
  done
done

echo "Scripts → $BIN_DIR"
for group_dir in "$REPO_ROOT"/scripts/*/; do
  for script in "$group_dir"*; do
    [[ -f "$script" && -x "$script" ]] || continue
    link "$script" "$BIN_DIR/$(basename "$script")"
  done
done

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "warning: $BIN_DIR is not on PATH — add it to your shell rc" >&2 ;;
esac

echo "done"
