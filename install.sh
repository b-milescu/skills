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
# non-symlink targets or user-managed symlinks pointing outside this repo — fix
# those by hand. Stale repo-owned symlinks are pruned so renames propagate
# cleanly.
#
# Runtime skill roots must contain only actual skill directories. Shared repo
# docs/templates stay reachable through each installed skill symlink via paths
# like ~/.claude/skills/start-build/../docs/...; linking those resource dirs as
# siblings makes some runtimes present them as bogus skills.

set -euo pipefail
shopt -s nullglob

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

usage() {
  cat <<'USAGE'
Usage: install.sh [--check]

  --check  Run read-only agent/install consistency checks and exit.
USAGE
}

case "${1:-}" in
  --check)
    exec bash "$REPO_ROOT/agents/check.sh"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

SKILL_DESTS=(
  "$HOME/.claude/skills"
  "$HOME/.pi/agent/skills"
)

# External skills referenced by this repo but not vendored here. They should be
# installed into each runtime skill directory by their owning skill pack.
REQUIRED_EXTERNAL_SKILLS=(
  tdd
)
OPTIONAL_EXTERNAL_SKILLS=(
  grill-with-docs
  to-issues
  improve-codebase-architecture
  triage
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

# Agents are organised per target dialect under agents/<target>/.
# AGENT_NAMES enumerates shared agent names from agents/claude/; agents/check.sh
# enforces strict Claude Code ↔ pi dialect parity before review.
AGENT_NAMES=()
if [[ -d "$REPO_ROOT/agents/claude" ]]; then
  for f in "$REPO_ROOT/agents/claude"/*.md; do
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

external_skill_note() {
  case "$1" in
    tdd)
      printf 'start-build/start-review behavior-touching work depends on it'
      ;;
    grill-with-docs)
      printf 'domain-doc guidance can use it if installed; otherwise edit CONTEXT.md/docs/adr manually'
      ;;
    to-issues)
      printf 'generic non-GitLab issue breakdowns can use it if installed; otherwise follow tracker docs manually'
      ;;
    improve-codebase-architecture)
      printf 'boundary-moving cleanup handoffs can use it if installed; otherwise file follow-up issues manually'
      ;;
    triage)
      printf 'tracker/backlog hygiene handoffs can use it if installed; otherwise follow tracker docs manually'
      ;;
    *)
      printf 'declared external skill dependency'
      ;;
  esac
}

external_skill_present() {
  local skill_dir="$1" name="$2"
  [[ -f "$skill_dir/$name/SKILL.md" ]]
}

warn_missing_external_skills() {
  local skill_dir="$1" name note

  for name in "${REQUIRED_EXTERNAL_SKILLS[@]}"; do
    external_skill_present "$skill_dir" "$name" && continue
    note=$(external_skill_note "$name")
    printf 'warn: missing required external skill %s in %s (%s)\n' "$name" "$skill_dir" "$note" >&2
  done

  for name in "${OPTIONAL_EXTERNAL_SKILLS[@]}"; do
    external_skill_present "$skill_dir" "$name" && continue
    note=$(external_skill_note "$name")
    printf 'warn: missing optional external skill %s in %s (%s)\n' "$name" "$skill_dir" "$note" >&2
  done
}

resolve_symlink_target() {
  local link_path="$1" target

  target=$(readlink "$link_path") || return 1
  if [[ "$target" == /* ]]; then
    "$REALPATH" -m "$target"
  else
    "$REALPATH" -m "$(dirname "$link_path")/$target"
  fi
}

is_repo_owned_path() {
  local path="$1"
  case "$path" in
    "$REPO_ROOT"|"$REPO_ROOT"/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

link() {
  local src="$1" dest="$2" existing_abs src_abs

  if [[ -L "$dest" ]]; then
    existing_abs=$(resolve_symlink_target "$dest") || {
      printf '  skip:    %s (cannot read symlink target — resolve by hand)\n' "$dest" >&2
      return
    }
    src_abs=$("$REALPATH" -m "$src")
    if [[ "$existing_abs" != "$src_abs" ]] && ! is_repo_owned_path "$existing_abs"; then
      printf '  skip:    %s (existing symlink points outside repo: %s)\n' "$dest" "$existing_abs" >&2
      return
    fi
  elif [[ -e "$dest" ]]; then
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

    name=$(basename "$link_path" .md)
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
  warn_missing_external_skills "$skill_dir"
done

# --- Agents (per-target dialect) ---
# Each agent has a per-target source under agents/<dialect>/<name>.md so the
# frontmatter can match the target runtime's schema (Claude Code uses
# PascalCase tools and its own field set; pi uses lowercase tools and its own
# intercom-bridge fields). Symlink the right variant to each destination.
AGENT_TARGETS=(
  "$HOME/.claude/agents|claude"
  "$HOME/.pi/agent/agents|pi"
)

for entry in "${AGENT_TARGETS[@]}"; do
  agent_dir="${entry%|*}"
  source_subdir="${entry#*|}"
  source_root="$REPO_ROOT/agents/$source_subdir"
  parent=$(dirname "$agent_dir")
  if [[ ! -d "$parent" ]]; then
    printf 'skip: %s (parent %s not present — agent not installed)\n' "$agent_dir" "$parent"
    continue
  fi
  if [[ ! -d "$source_root" ]]; then
    printf 'skip: %s (no %s/ source dir)\n' "$agent_dir" "$source_root"
    continue
  fi
  mkdir -p "$agent_dir"
  echo "Agents (${source_subdir} dialect) → $agent_dir"
  prune_stale_repo_links "$agent_dir" is_agent_name
  for name in "${AGENT_NAMES[@]}"; do
    if [[ ! -f "$source_root/$name.md" ]]; then
      # Defensive only: agents/check.sh enforces dialect parity before ready.
      printf '  skip:    %s (no source in %s/)\n' "$agent_dir/$name.md" "$source_root"
      continue
    fi
    link "$source_root/$name.md" "$agent_dir/$name.md"
  done
done

echo "done"
