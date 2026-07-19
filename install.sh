#!/usr/bin/env bash
# install.sh — idempotently surface skills and agents via symlinks.
#
#   Skills:  <repo>/<skill>/  → ~/.claude/skills/<skill>   (Claude Code)
#                            → ~/.omp/agent/skills/<skill> (OMP agent)
#
#   Agents:  <repo>/agents/<name>.md → ~/.claude/agents/<name>.md   (Claude Code)
#                                  → ~/.omp/agent/agents/<name>.md (OMP agent)
#
# Each destination is skipped if its parent directory (e.g. ~/.claude/,
# ~/.omp/agent/) doesn't exist — that agent simply isn't installed on this host.
# Safe to re-run after adding/removing skills or agents. Refuses to overwrite
# non-symlink targets or user-managed symlinks pointing outside this repo — fix
# those by hand. Stale repo-owned symlinks are pruned so renames propagate
# cleanly.
#
# Runtime skill roots must contain only actual skill directories. On Windows,
# Linux, and macOS, shared docs/templates stay reachable through skill-local
# resource symlinks such as ~/.claude/skills/start-build/docs/... and
# ~/.claude/skills/start-build/shared-templates/.... When Git materializes
# tracked resource symlinks as regular relative-target files, the installer
# builds an equivalent runtime view without copying the canonical resources.
# Linking shared roots as skill-root siblings would expose bogus skills.

set -euo pipefail
shopt -s nullglob

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

INSTALLER_OWNED_ROOTS=("$REPO_ROOT")
PREPARED_SKILL_SOURCE=

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
  "$HOME/.omp/agent/skills"
)

# External skills referenced by this repo but not vendored here. They should be
# installed into each runtime skill directory by their owning skill pack.
REQUIRED_EXTERNAL_SKILLS=(
  tdd
)
OPTIONAL_EXTERNAL_SKILLS=(
  grill-with-docs
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
# AGENT_NAMES is populated per target from that target's own source directory so
# OMP-only routed agents remain installed while Claude Code omits unsupported
# agent definitions.
AGENT_NAMES=()

collect_agent_names() {
  local source_root="$1" f

  AGENT_NAMES=()
  for f in "$source_root"/*.md; do
    [[ -f "$f" ]] || continue
    AGENT_NAMES+=("$(basename "$f" .md)")
  done
}

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

is_installer_owned_path() {
  local path="$1" root
  for root in "${INSTALLER_OWNED_ROOTS[@]}"; do
    case "$path" in
      "$root"|"$root"/*)
        return 0
        ;;
    esac
  done
  return 1
}

link() {
  local src="$1" dest="$2" existing_abs src_abs

  if [[ -L "$dest" ]]; then
    existing_abs=$(resolve_symlink_target "$dest") || {
      printf '  skip:    %s (cannot read symlink target — resolve by hand)\n' "$dest" >&2
      return
    }
    src_abs=$("$REALPATH" -m "$src")
    if [[ "$existing_abs" != "$src_abs" ]] && ! is_installer_owned_path "$existing_abs"; then
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

skill_requires_runtime_view() {
  local source="$1" resource
  for resource in docs shared-templates; do
    [[ -f "$source/$resource" && ! -L "$source/$resource" ]] && return 0
  done
  return 1
}

prepare_skill_source() {
  local source="$1" view_root="$2" view entry name target expected marker_target

  PREPARED_SKILL_SOURCE="$source"
  skill_requires_runtime_view "$source" || return 0

  view="$view_root/$(basename "$source")"
  if [[ -e "$view" || -L "$view" ]]; then
    if [[ ! -d "$view" || -L "$view" || ! -L "$view/.source" ]]; then
      printf '  skip:    %s (existing runtime view is not installer-managed)\n' "$view" >&2
      return 1
    fi
    marker_target=$(resolve_symlink_target "$view/.source") || return 1
    if [[ "$marker_target" != "$source" ]]; then
      printf '  skip:    %s (runtime view belongs to %s)\n' "$view" "$marker_target" >&2
      return 1
    fi
    for entry in "$view"/* "$view"/.[!.]*; do
      if [[ ! -L "$entry" ]]; then
        printf '  skip:    %s (runtime view contains unmanaged entry %s)\n' "$view" "$entry" >&2
        return 1
      fi
    done
    for entry in "$view"/* "$view"/.[!.]*; do
      rm "$entry"
    done
    rmdir "$view"
  fi

  mkdir -p "$view"
  link "$source" "$view/.source"
  for entry in "$source"/*; do
    name=$(basename "$entry")
    target="$entry"
    if [[ -f "$entry" && ! -L "$entry" ]]; then
      case "$name" in
        docs)
          expected="$REPO_ROOT/docs"
          ;;
        shared-templates)
          expected="$REPO_ROOT/templates"
          ;;
        *)
          expected=
          ;;
      esac
      if [[ -n "$expected" ]]; then
        target=$("$REALPATH" -m "$(dirname "$entry")/$(<"$entry")")
        if [[ "$target" != "$expected" ]]; then
          printf '  skip:    %s (materialized resource target is %s, expected %s)\n' "$entry" "$target" "$expected" >&2
          return 1
        fi
      fi
    fi
    link "$target" "$view/$name"
  done

  PREPARED_SKILL_SOURCE="$view"
}

prune_stale_repo_links() {
  local dir="$1" validator="$2"
  local link_path name target_abs

  for link_path in "$dir"/*; do
    [[ -L "$link_path" ]] || continue

    name=$(basename "$link_path" .md)
    "$validator" "$name" && continue

    target_abs=$(resolve_symlink_target "$link_path") || continue

    if is_installer_owned_path "$target_abs"; then
      rm "$link_path"
      printf '  removed: %s (stale installer-owned symlink)\n' "$link_path"
    fi
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
  skill_view_root="$parent/.skill-resource-views"
  mkdir -p "$skill_view_root"
  INSTALLER_OWNED_ROOTS+=("$skill_view_root")
  echo "Skills → $skill_dir"
  prune_stale_repo_links "$skill_dir" is_skill_name
  for name in "${SKILL_NAMES[@]}"; do
    prepare_skill_source "$REPO_ROOT/$name" "$skill_view_root" || continue
    link "$PREPARED_SKILL_SOURCE" "$skill_dir/$name"
  done
  warn_missing_external_skills "$skill_dir"
done

# --- Agents (per-target dialect) ---
# Each agent has a per-target source under agents/<dialect>/<name>.md so the
# frontmatter can match the target runtime's schema (Claude Code uses
# PascalCase tools and its own field set; OMP uses lowercase tool names and its own
# task-agent fields). Symlink the right variant to each destination.
AGENT_TARGETS=(
  "$HOME/.claude/agents|claude"
  "$HOME/.omp/agent/agents|omp"
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
  collect_agent_names "$source_root"
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
