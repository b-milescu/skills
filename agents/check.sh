#!/usr/bin/env bash
# Read-only repository/installed-agent consistency checks.

set -euo pipefail
shopt -s nullglob

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
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

info() {
  printf 'info: %s\n' "$*"
}

list_prompt_drift_markdown_files() {
  bash "$REPO_ROOT/scripts/list-prompt-drift-markdown.sh" "$REPO_ROOT"
}

# Fill the global prompt_drift_files array with prompt-drift Markdown files,
# minus the canonical file $1 (repo-relative). Callers then scan every file in
# ONE awk process (per-file awk forks dominated this checker's runtime).
prompt_drift_files=()
load_prompt_drift_files() {
  local skip="$REPO_ROOT/$1" file
  prompt_drift_files=()
  while IFS= read -r -d '' file; do
    [[ "$file" == "$skip" ]] && continue
    prompt_drift_files+=("$file")
  done < <(list_prompt_drift_markdown_files)
}

# Add the bad-file count printed by a multi-file awk scan to errors; an awk
# failure itself also counts as an error.
add_scan_errors() {
  local count="$1" status="$2"
  errors=$((errors + ${count:-0}))
  [[ "$status" -eq 0 ]] || errors=$((errors + 1))
}

list_agent_names() {
  local dir="$1" file
  [[ -d "$dir" ]] || return 0
  for file in "$dir"/*.md; do
    [[ -f "$file" ]] || continue
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
  local omp_dir="$REPO_ROOT/agents/omp"
  local claude_names="$TMPDIR_CHECK/claude-agent-names"
  local omp_names="$TMPDIR_CHECK/omp-agent-names"
  local missing_omp="$TMPDIR_CHECK/missing-omp"
  local missing_claude="$TMPDIR_CHECK/missing-claude"
  local shared_names="$TMPDIR_CHECK/shared-agent-names"
  local name file rel declared claude_declared omp_declared token

  # MR builder/reviewer routes share model-free basenames across Claude and
  # OMP dialects. Model/provider pins stay in frontmatter/body prose, so any
  # missing counterpart is a hard parity error rather than an allowed
  # runtime-specific exception.

  list_agent_names "$claude_dir" > "$claude_names"
  list_agent_names "$omp_dir" > "$omp_names"

  comm -23 "$claude_names" "$omp_names" > "$missing_omp"
  comm -13 "$claude_names" "$omp_names" > "$missing_claude"
  comm -12 "$claude_names" "$omp_names" > "$shared_names"

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    error "agent dialect parity: agents/claude/$name.md has no agents/omp/$name.md"
  done < "$missing_omp"

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    error "agent dialect parity: agents/omp/$name.md has no agents/claude/$name.md"
  done < "$missing_claude"

  for file in "$claude_dir"/*.md "$omp_dir"/*.md; do
    [[ -f "$file" ]] || continue
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
      error "agent dialect parity: agents/claude/$name.md name '$claude_declared' differs from agents/omp/$name.md name '$omp_declared'"
    fi
  done < "$shared_names"
}

workflow_skill_for_agent() {
  case "$1" in
    mr-builder)
      printf '%s' "start-build"
      ;;
    mr-reviewer-*)
      printf '%s' "start-review"
      ;;
    *)
      return 1
      ;;
  esac
}

check_agent_prompt_strategy() {
  local file rel name workflow_skill workflow_skill_file forge_skill_file

  forge_skill_file="$REPO_ROOT/forge/SKILL.md"
  if [[ ! -f "$forge_skill_file" ]]; then
    error "agent prompt strategy: canonical forge transport skill missing: $(relpath "$forge_skill_file")"
  fi

  for file in "$REPO_ROOT/agents/claude"/*.md "$REPO_ROOT/agents/omp"/*.md; do
    [[ -f "$file" ]] || continue
    name="$(basename "$file" .md)"
    workflow_skill="$(workflow_skill_for_agent "$name" || true)"
    [[ -n "$workflow_skill" ]] || continue

    rel="$(relpath "$file")"
    workflow_skill_file="$REPO_ROOT/$workflow_skill/SKILL.md"
    if [[ ! -f "$workflow_skill_file" ]]; then
      error "agent prompt strategy: canonical workflow skill missing for $rel: $(relpath "$workflow_skill_file")"
    fi
    if ! grep -Fq 'Canonical development pattern source: `'"$workflow_skill"'`' "$file"; then
      error "agent prompt strategy: $rel must point to canonical workflow skill $workflow_skill"
    fi
    if ! grep -Fq 'forge' "$file" || ! grep -Fq 'bound provider' "$file"; then
      error "agent prompt strategy: $rel must select the bound provider through forge"
    fi
  done
}

extract_schema_fields() {
  local schema="$1"
  awk -F'|' '
    /^\|/ {
      field=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
      if (field != "Field" && field !~ /^-+$/ && field != "") print field
    }
  ' "$schema"
}

extract_generated_copy_fields() {
  local file="$1"
  awk -F'|' '
    /REVIEWER-LIFT-SCHEMA:BEGIN/ { in_block=1; next }
    /REVIEWER-LIFT-SCHEMA:END/ { in_block=0; next }
    in_block && /^\|/ {
      field=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
      if (field != "Field" && field !~ /^-+$/ && field != "") print field
    }
  ' "$file"
}

check_reviewer_lift_schema() {
  local schema="$REPO_ROOT/start-build/templates/reviewer-lift-schema.md"
  local schema_fields="$TMPDIR_CHECK/reviewer-lift-schema.fields"
  local copies=(
    "$REPO_ROOT/start-build/templates/review-packet.md"
    "$REPO_ROOT/start-build/templates/review-packet-compact.md"
    "$REPO_ROOT/start-review/templates/review-report.md"
  )
  local copy copy_fields diff_output rel bad_count status=0

  if [[ ! -f "$schema" ]]; then
    error "Reviewer Lift schema missing: $(relpath "$schema")"
    return
  fi

  extract_schema_fields "$schema" > "$schema_fields"
  if [[ ! -s "$schema_fields" ]]; then
    error "Reviewer Lift schema has no fields: $(relpath "$schema")"
    return
  fi

  for copy in "${copies[@]}"; do
    rel="$(relpath "$copy")"
    if [[ ! -f "$copy" ]]; then
      error "Reviewer Lift generated copy missing: $rel"
      continue
    fi
    copy_fields="$TMPDIR_CHECK/$(basename "$copy").fields"
    extract_generated_copy_fields "$copy" > "$copy_fields"
    if [[ ! -s "$copy_fields" ]]; then
      error "Reviewer Lift schema drift: $rel has no generated-copy block"
      continue
    fi
    if ! diff_output="$(diff -u "$schema_fields" "$copy_fields" 2>&1)"; then
      error "Reviewer Lift schema drift: $rel does not match start-build/templates/reviewer-lift-schema.md"
      printf '%s\n' "$diff_output" >&2
    fi
  done

  load_prompt_drift_files "start-build/templates/reviewer-lift-schema.md"
  [[ "${#prompt_drift_files[@]}" -gt 0 ]] || return 0
  bad_count="$(awk -v fields_file="$schema_fields" -v root="$REPO_ROOT/" -F'|' '
    BEGIN {
      while ((getline line < fields_file) > 0) wanted[line]=1
      close(fields_file)
    }
    FNR == 1 {
      file = index(FILENAME, root) == 1 ? substr(FILENAME, length(root) + 1) : FILENAME
      in_block=0; run=0; start=0; bad=0
    }
    /REVIEWER-LIFT-SCHEMA:BEGIN/ { in_block=1; run=0; next }
    /REVIEWER-LIFT-SCHEMA:END/ { in_block=0; run=0; next }
    in_block { next }
    /^\|/ {
      field=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
      gsub(/`|\*\*/, "", field)
      if (wanted[field]) {
        if (run == 0) start=FNR
        run++
        if (run >= 4 && !bad) {
          printf "Reviewer Lift stale duplicate table: %s:%d (canonical field run starts at line %d; use generated-copy block from start-build/templates/reviewer-lift-schema.md instead of inlining)\n", file, FNR, start > "/dev/stderr"
          bad=1
          bad_files++
        }
      } else if (field !~ /^-+$/) {
        run=0
      }
      next
    }
    { run=0 }
    END { print bad_files + 0 }
  ' "${prompt_drift_files[@]}")" || status=$?
  add_scan_errors "$bad_count" "$status"
}

extract_review_report_headings() {
  local report="$1"
  awk '/^##[[:space:]]+/ { sub(/^##[[:space:]]+/, ""); print }' "$report"
}

check_review_report_structure() {
  local report="$REPO_ROOT/start-review/templates/review-report.md"
  local headings="$TMPDIR_CHECK/review-report.headings"
  local bad_count status=0

  if [[ ! -f "$report" ]]; then
    error "Review Report template missing: $(relpath "$report")"
    return
  fi

  extract_review_report_headings "$report" > "$headings"
  if [[ ! -s "$headings" ]]; then
    error "Review Report template has no section headings: $(relpath "$report")"
    return
  fi

  load_prompt_drift_files "start-review/templates/review-report.md"
  [[ "${#prompt_drift_files[@]}" -gt 0 ]] || return 0
  bad_count="$(awk -v headings_file="$headings" -v root="$REPO_ROOT/" '
    BEGIN {
      while ((getline line < headings_file) > 0) wanted[line]=1
      close(headings_file)
    }
    FNR == 1 {
      file = index(FILENAME, root) == 1 ? substr(FILENAME, length(root) + 1) : FILENAME
      run=0; start=0; bad=0
    }
    /^##[[:space:]]+/ {
      heading=$0
      sub(/^##[[:space:]]+/, "", heading)
      gsub(/[[:space:]]+$/, "", heading)
      if (wanted[heading]) {
        if (run == 0) start=FNR
        run++
        if (run >= 4 && !bad) {
          printf "Review Report stale structure: %s:%d (canonical heading run starts at line %d; reference start-review/templates/review-report.md instead of inlining its structure)\n", file, FNR, start > "/dev/stderr"
          bad=1
          bad_files++
        }
      } else {
        run=0
      }
      next
    }
    END { print bad_files + 0 }
  ' "${prompt_drift_files[@]}")" || status=$?
  add_scan_errors "$bad_count" "$status"
}

check_agent_variant_parity
check_agent_prompt_strategy
check_reviewer_lift_schema
check_review_report_structure

if [[ "$errors" -gt 0 ]]; then
  printf 'agent-check: FAIL (%d error(s))\n' "$errors" >&2
  exit 1
fi

printf 'agent-check: PASS\n'
