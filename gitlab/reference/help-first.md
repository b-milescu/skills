# GitLab help-first reference

This reference owns the run-dir help-cache pattern for guarded `/gitlab` `glab` fallbacks. [`SKILL.md`](../SKILL.md#guarded-glab-fallback-and-help-first-rule) owns transport order, fallback eligibility, compatibility headings, pitfalls, and workflow snippets.

## Help-first rule detail

Before a flagged fallback command, run help for its exact `glab` command words and verify every flag. Help overrides memory, other-CLI examples, or stale skill text; record any `SKILL.md` drift in the MR/review artifact. Failed help capture stops that command.

A cache is optional and valid only within the current run and repository context. Key it by exact command words, `glab` version, worktree root, remote/repository selector, and branch assumptions. Refresh when any key changes, keep it in a temp/run directory, and never commit it.

## Per-run help cache

```bash
run_dir="${run_dir:-}"
if [ -z "$run_dir" ]; then
  run_dir="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-run.XXXXXX")"
fi
help_dir="$run_dir/glab-help"
mkdir -p "$help_dir"

context_file="$help_dir/context.txt"
new_context="$(
  printf 'glab=%s\n' "$(glab --version | head -n 1)"
  printf 'repo_root=%s\n' "$(git rev-parse --show-toplevel)"
  printf 'repo_url=%s\n' "$(git remote get-url origin)"
)"
if [ ! -f "$context_file" ] || [ "$(cat "$context_file")" != "$new_context" ]; then
  rm -f "$help_dir"/glab-*--help.txt "$help_dir"/verified.tsv
  printf '%s\n' "$new_context" > "$context_file"
fi

cache_glab_help() {
  local file status
  file="$help_dir/glab-$*--help.txt"
  file="${file// /-}"
  if [ ! -s "$file" ]; then
    if glab "$@" --help >"$file" 2>&1; then
      printf '%s\tOK\tglab %s --help\t%s\n' \
        "$(date -u +%FT%TZ)" "$*" "$file" >> "$help_dir/verified.tsv"
    else
      status=$?
      printf '%s\tFAIL:%s\tglab %s --help\t%s\n' \
        "$(date -u +%FT%TZ)" "$status" "$*" "$file" >> "$help_dir/verified.tsv"
      return "$status"
    fi
  fi
  printf 'HELP_CACHE glab %s --help -> %s\n' "$*" "$file"
}

cache_glab_help mr view
glab mr view "$mr_iid" -F json
```

The cache is evidence only for the exact command that produced the file; it never relaxes help-first or any Mutation Guard condition.
