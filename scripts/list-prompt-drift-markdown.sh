#!/usr/bin/env bash
# List Markdown files that prompt-drift checks should scan.
#
# In normal Git worktrees, only tracked Markdown can reach an MR, so use the
# index to avoid ignored/generated/untracked local artifact noise. In fixture or
# temp-copied repos without Git metadata, fall back to a conservative find scan
# that prunes known local artifact directories/files, including leftover builder
# `git worktree` copies under `.claude/worktrees/`. Stale worktrees carry copies
# of tracked Markdown; scanning them produced false prompt-drift failures on main
# (issue #246), so the fallback prunes them too.

set -euo pipefail

if [[ "$#" -gt 1 ]]; then
  echo "usage: $0 [repo-root]" >&2
  exit 2
fi

repo_root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"
repo_root="$(cd "$repo_root" && pwd -P)"

if git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_top="$(git -C "$repo_root" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$git_top" ]]; then
    git_top="$(cd "$git_top" && pwd -P)"
  fi
  if [[ "$git_top" == "$repo_root" ]]; then
    git -C "$repo_root" ls-files -z '*.md' |
    while IFS= read -r -d '' path; do
      [[ -f "$repo_root/$path" ]] || continue
      printf '%s\0' "$repo_root/$path"
    done
    exit 0
  fi
fi

find "$repo_root" \
  \( \( -type d \( \
    -name .git -o \
    -name node_modules -o \
    -name .npm -o \
    -name cleanup-discovery -o \
    -name graphify-out -o \
    -name '.graphify*' \
  \) -o -path '*/.claude/worktrees' \) -prune \) \
  -o \( -type f -name '*.md' ! -path "$repo_root/progress.md" ! -path '*/.graphify*' -print0 \)
