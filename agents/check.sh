#!/usr/bin/env bash
# Read-only repository/installed-agent consistency checks.

set -euo pipefail
shopt -s nullglob

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CHECK_HOME="${AGENT_SKILLS_CHECK_HOME:-$HOME}"
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

check_agent_variant_parity() {
  local claude_dir="$REPO_ROOT/agents/claude"
  local pi_dir="$REPO_ROOT/agents/pi"
  local claude_names="$TMPDIR_CHECK/claude-agent-names"
  local pi_names="$TMPDIR_CHECK/pi-agent-names"
  local missing_pi="$TMPDIR_CHECK/missing-pi"
  local missing_claude="$TMPDIR_CHECK/missing-claude"
  local shared_names="$TMPDIR_CHECK/shared-agent-names"
  local name file rel declared claude_declared pi_declared

  list_agent_names "$claude_dir" > "$claude_names"
  list_agent_names "$pi_dir" > "$pi_names"

  comm -23 "$claude_names" "$pi_names" > "$missing_pi"
  comm -13 "$claude_names" "$pi_names" > "$missing_claude"
  comm -12 "$claude_names" "$pi_names" > "$shared_names"

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    error "agent dialect parity: agents/claude/$name.md has no agents/pi/$name.md"
  done < "$missing_pi"

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    error "agent dialect parity: agents/pi/$name.md has no agents/claude/$name.md"
  done < "$missing_claude"

  for file in "$claude_dir"/*.md "$pi_dir"/*.md; do
    [[ -f "$file" ]] || continue
    name="$(basename "$file" .md)"
    rel="$(relpath "$file")"
    declared="$(frontmatter_name "$file" || true)"
    if [[ -z "$declared" ]]; then
      error "agent dialect parity: $rel has no frontmatter name"
    elif [[ "$declared" != "$name" ]]; then
      error "agent dialect parity: $rel frontmatter name '$declared' does not match file name '$name'"
    fi
  done

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    claude_declared="$(frontmatter_name "$claude_dir/$name.md" || true)"
    pi_declared="$(frontmatter_name "$pi_dir/$name.md" || true)"
    if [[ -n "$claude_declared" && -n "$pi_declared" && "$claude_declared" != "$pi_declared" ]]; then
      error "agent dialect parity: agents/claude/$name.md name '$claude_declared' differs from agents/pi/$name.md name '$pi_declared'"
    fi
  done < "$shared_names"
}

workflow_skill_for_agent() {
  case "$1" in
    mr-builder)
      printf '%s' "start-build"
      ;;
    mr-reviewer)
      printf '%s' "start-review"
      ;;
    *)
      return 1
      ;;
  esac
}

check_agent_prompt_strategy() {
  local file rel name workflow_skill workflow_skill_file gitlab_skill_file

  gitlab_skill_file="$REPO_ROOT/gitlab-local/SKILL.md"
  if [[ ! -f "$gitlab_skill_file" ]]; then
    error "agent prompt strategy: canonical GitLab CLI skill missing: $(relpath "$gitlab_skill_file")"
  fi

  for file in "$REPO_ROOT/agents/claude"/*.md "$REPO_ROOT/agents/pi"/*.md; do
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
    if ! grep -Fq 'gitlab-local' "$file"; then
      error "agent prompt strategy: $rel must point to gitlab-local for GitLab CLI syntax"
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
  local copy copy_fields diff_output file rel

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

  while IFS= read -r -d '' file; do
    rel="$(relpath "$file")"
    [[ "$rel" == "start-build/templates/reviewer-lift-schema.md" ]] && continue
    if ! awk -v fields_file="$schema_fields" -v file="$rel" -F'|' '
      BEGIN {
        while ((getline line < fields_file) > 0) wanted[line]=1
        close(fields_file)
        run=0
        start=0
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
          }
        } else if (field !~ /^-+$/) {
          run=0
        }
        next
      }
      { run=0 }
      END { exit bad ? 1 : 0 }
    ' "$file"; then
      errors=$((errors + 1))
    fi
  done < <(list_prompt_drift_markdown_files)
}

extract_review_report_headings() {
  local report="$1"
  awk '/^##[[:space:]]+/ { sub(/^##[[:space:]]+/, ""); print }' "$report"
}

check_review_report_structure() {
  local report="$REPO_ROOT/start-review/templates/review-report.md"
  local headings="$TMPDIR_CHECK/review-report.headings"
  local file rel

  if [[ ! -f "$report" ]]; then
    error "Review Report template missing: $(relpath "$report")"
    return
  fi

  extract_review_report_headings "$report" > "$headings"
  if [[ ! -s "$headings" ]]; then
    error "Review Report template has no section headings: $(relpath "$report")"
    return
  fi

  while IFS= read -r -d '' file; do
    rel="$(relpath "$file")"
    [[ "$rel" == "start-review/templates/review-report.md" ]] && continue
    if ! awk -v headings_file="$headings" -v file="$rel" '
      BEGIN {
        while ((getline line < headings_file) > 0) wanted[line]=1
        close(headings_file)
        run=0
        start=0
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
          }
        } else {
          run=0
        }
        next
      }
      END { exit bad ? 1 : 0 }
    ' "$file"; then
      errors=$((errors + 1))
    fi
  done < <(list_prompt_drift_markdown_files)
}

agent_references_skill() {
  local agent_file="$1" skill="$2"
  grep -Eq "(^skills:[[:space:]]*.*(^|[ ,])${skill}([ ,]|$)|\`${skill}\`|(^|[^[:alnum:]_-])${skill}([^[:alnum:]_-]|$))" "$agent_file"
}

external_skill_guidance() {
  local skill="$1" skill_dir="$2"
  case "$skill" in
    tdd)
      printf "Install external skill '%s' into %s/%s with a SKILL.md file (for example from the owning skill pack) before running behavior-touching build/review workflows." "$skill" "$skill_dir" "$skill"
      ;;
    *)
      printf "Install external skill '%s' into %s/%s with a SKILL.md file from its owning skill pack." "$skill" "$skill_dir" "$skill"
      ;;
  esac
}

check_runtime_external_skills() {
  local label="$1" runtime_root="$2" agent_dir="$3" skill_dir="$4" source_agent_dir="$5"
  local required_external_skills=(tdd)
  local skill agent needs_skill found_agent guidance scan_dir scan_label

  if [[ ! -d "$runtime_root" ]]; then
    info "$label runtime not installed at $runtime_root; external dependency check skipped for this runtime"
    return
  fi

  found_agent=0
  if [[ -d "$agent_dir" ]]; then
    for agent in "$agent_dir"/*.md; do
      [[ -f "$agent" ]] || continue
      found_agent=1
    done
  fi

  if [[ "$found_agent" -eq 1 ]]; then
    scan_dir="$agent_dir"
    scan_label="installed agents"
  elif [[ -d "$source_agent_dir" ]]; then
    scan_dir="$source_agent_dir"
    scan_label="source agents install.sh would link"
    info "$label agent dir has no readable installed agents at $agent_dir; checking source agents because $runtime_root exists"
  else
    info "$label has no installed agents at $agent_dir and no source agents at $source_agent_dir; external dependency check skipped for this runtime"
    return
  fi

  for skill in "${required_external_skills[@]}"; do
    needs_skill=0
    for agent in "$scan_dir"/*.md; do
      [[ -f "$agent" ]] || continue
      if agent_references_skill "$agent" "$skill"; then
        needs_skill=1
      fi
    done

    [[ "$needs_skill" -eq 1 ]] || continue

    if [[ ! -f "$skill_dir/$skill/SKILL.md" ]]; then
      guidance="$(external_skill_guidance "$skill" "$skill_dir")"
      error "$label $scan_label reference missing required external skill $skill in $skill_dir. $guidance"
    fi
  done
}

check_external_skill_dependencies() {
  check_runtime_external_skills "Claude" "$CHECK_HOME/.claude" "$CHECK_HOME/.claude/agents" "$CHECK_HOME/.claude/skills" "$REPO_ROOT/agents/claude"
  check_runtime_external_skills "pi" "$CHECK_HOME/.pi/agent" "$CHECK_HOME/.pi/agent/agents" "$CHECK_HOME/.pi/agent/skills" "$REPO_ROOT/agents/pi"
}

check_agent_variant_parity
check_agent_prompt_strategy
check_reviewer_lift_schema
check_review_report_structure
check_external_skill_dependencies

if [[ "$errors" -gt 0 ]]; then
  printf 'agent-check: FAIL (%d error(s))\n' "$errors" >&2
  exit 1
fi

printf 'agent-check: PASS\n'
