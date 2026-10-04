#!/usr/bin/env bash
# Read-only repository/installed-agent consistency checks.

set -euo pipefail
shopt -s nullglob

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# Explicit targets use the dialect-aware checker, including native project paths.
if [[ "$#" -gt 0 ]]; then
  exec bun "$REPO_ROOT/scripts/check-agent-schemas.mjs" "$@"
fi
TMPDIR_CHECK="$(mktemp -d "${TMPDIR:-/tmp}/agent-check.XXXXXX")"
trap 'rm -rf "$TMPDIR_CHECK"' EXIT

errors=0

relpath() {
  local path="$1"
  case "$path" in
    "$REPO_ROOT"/*)
      printf '%s' "${path#$REPO_ROOT/}"
      ;;
    *)
      printf '%s' "$path"
      ;;
  esac
}

error() {
  printf 'error: %s\n' "$*" >&2
  errors=$((errors + 1))
}


list_agent_names() {
  local dir="$1" file
  [[ -d "$dir" ]] || return 0
  for file in "$dir"/*.md; do
    [[ -f "$file" ]] || continue
    [[ "$(basename "$file")" != README.md ]] || continue
    basename "$file" .md
  done | sort
}

frontmatter_name() {
  local file="$1"
  awk '
    NR == 1 && $0 == "---" { in_frontmatter=1; next }
    in_frontmatter && $0 == "---" { exit }
    in_frontmatter && /^name:[[:space:]]*/ {
      sub(/^name:[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"']$/, "")
      print
      exit
    }
  ' "$file"
}

FORBIDDEN_ROUTE_NAME_TOKEN_RE='(^|[-_.])(claude|anthropic|openai|codex|gpt([-_.]?[0-9]+)*|opus([-_.]?[0-9]+)*|sonnet([-_.]?[0-9]+)*)([-_.]|$)'

forbidden_route_name_token() {
  local value="$1"
  if [[ "$value" =~ $FORBIDDEN_ROUTE_NAME_TOKEN_RE ]]; then
    printf '%s' "${BASH_REMATCH[2]}"
    return 0
  fi
  return 1
}


check_agent_variant_parity() {
  local claude_dir="$REPO_ROOT/agents/claude"
  local omp_dir="$REPO_ROOT/agents"
  local claude_names="$TMPDIR_CHECK/claude-agent-names"
  local omp_names="$TMPDIR_CHECK/omp-agent-names"
  local missing_omp="$TMPDIR_CHECK/missing-omp"
  local missing_claude="$TMPDIR_CHECK/missing-claude"
  local shared_names="$TMPDIR_CHECK/shared-agent-names"
  local name file rel declared claude_declared omp_declared token

  # Change-request builder/reviewer routes share model-free basenames across Claude and
  # OMP dialects. Runtime-owned model/effort selection does not make a
  # missing counterpart an allowed runtime-specific exception.

  list_agent_names "$claude_dir" > "$claude_names"
  list_agent_names "$omp_dir" > "$omp_names"
  if [[ ! -s "$claude_names" && ! -s "$omp_names" ]]; then
    error "agent dialect parity: validation collected no agent files"
    return
  fi

  comm -23 "$claude_names" "$omp_names" > "$missing_omp"
  comm -13 "$claude_names" "$omp_names" > "$missing_claude"
  comm -12 "$claude_names" "$omp_names" > "$shared_names"

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    error "agent dialect parity: agents/claude/$name.md has no agents/$name.md"
  done < "$missing_omp"

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    error "agent dialect parity: agents/$name.md has no agents/claude/$name.md"
  done < "$missing_claude"

  for file in "$claude_dir"/*.md "$omp_dir"/*.md; do
    [[ -f "$file" ]] || continue
    [[ "$(basename "$file")" != README.md ]] || continue
    name="$(basename "$file" .md)"
    rel="$(relpath "$file")"
    declared="$(frontmatter_name "$file" || true)"
    if token="$(forbidden_route_name_token "$name")"; then
      error "agent route naming: $rel file name '$name' must not include provider/model token '$token'"
    fi
    if [[ -z "$declared" ]]; then
      error "agent dialect parity: $rel has no frontmatter name"
    elif [[ "$declared" != "$name" ]]; then
      error "agent dialect parity: $rel frontmatter name '$declared' does not match file name '$name'"
    fi
    if [[ -n "$declared" ]] && token="$(forbidden_route_name_token "$declared")"; then
      error "agent route naming: $rel frontmatter name '$declared' must not include provider/model token '$token'"
    fi
  done

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    claude_declared="$(frontmatter_name "$claude_dir/$name.md" || true)"
    omp_declared="$(frontmatter_name "$omp_dir/$name.md" || true)"
    if [[ -n "$claude_declared" && -n "$omp_declared" && "$claude_declared" != "$omp_declared" ]]; then
      error "agent dialect parity: agents/claude/$name.md name '$claude_declared' differs from agents/$name.md name '$omp_declared'"
    fi
  done < "$shared_names"
}


check_agent_variant_parity

if [[ "$errors" -gt 0 ]]; then
  printf 'agent-check: FAIL (%d error(s))\n' "$errors" >&2
  exit 1
fi

printf 'agent-check: PASS\n'
