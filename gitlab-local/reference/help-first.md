# GitLab help-first reference

This reference owns the detailed run-dir help-cache pattern for `/gitlab-local`. The main [`SKILL.md`](../SKILL.md#help-first-rule) keeps the high-value rule, compatibility headings, pitfalls, and canonical workflow snippets.

## Help-first rule detail

Before any flagged `glab` command, run exact command help and verify every flag. Help output wins over memory, examples from another CLI, or stale skill text. If help conflicts with `SKILL.md`, use help and note skill drift in the MR or review artifact.

A per-run cache may reduce repeated help-output noise, but it never removes the help-first requirement. Cache only help text captured during the current run and repo context.

## Per-run help cache

Help-first remains mandatory. A run-dir help cache may reduce repeated output noise only after the exact help text has been captured for this run and context. Keep the cache in a temp/run artifact directory and never commit it.

The run-dir help cache records the exact `glab <command> --help` output in a command-specific file, plus a `verified.tsv` line with verification status. A cache entry is valid only for the current run, exact command words, `glab` version, repo root, and repo URL/project selector. If help fails, record the failure status and stop before running the flagged command.

Refresh the cache whenever the command, `glab` version, or repo context changes. Repo context includes worktree root, remote/repo URL, `-R` project selector, default/target branch assumptions, and any host/project ambiguity. When in doubt, rerun help and overwrite the cache entry.

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

## Cache safety checklist

- Store the cache under a temp or run artifact directory, never under tracked repo paths.
- Treat failed help capture as a stop condition for the flagged command that needed that help.
- Refresh on any command-word, `glab` version, worktree, remote URL, project selector, or branch-context change.
- Use cached output only for the exact command words that produced the cached file.
