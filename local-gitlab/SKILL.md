---
name: local-gitlab
description: >-
  Works with local/self-hosted GitLab projects using the glab CLI directly:
  repository/auth preflight, default-branch lookup, issue/MR pickup, metadata, CI,
  diffs, file-backed comments/descriptions, approvals, and merges. Use when a task
  needs GitLab issue or Merge Request operations through glab, especially
  local/private GitLab, or when start-build/start-review needs issue-tracker
  command guidance.
---

# Local GitLab via glab

## Quick start

Run from the GitLab-backed git worktree:

```bash
command -v glab >/dev/null || { echo "glab missing"; exit 1; }
git rev-parse --show-toplevel >/dev/null || { echo "not a git repo"; exit 1; }
branch="$(git branch --show-current 2>/dev/null || true)"
remote="$(git config --get "branch.${branch}.remote" 2>/dev/null || true)"
[ -n "$remote" ] && [ "$remote" != "." ] || remote=origin
repo_url="$(git remote get-url "$remote" 2>/dev/null || git remote get-url origin)"
glab repo view "$repo_url" >/dev/null || { echo "glab cannot access repo"; exit 1; }
default_branch="$(glab repo view "$repo_url" -F json | jq -er '.default_branch')"
```

Use `"$repo_url"` (or `-R "$repo_url"`) when `glab` might infer the wrong repo/host. `glab auth status` is useful, but successful `glab repo view "$repo_url"` is the real local-project auth check.

## Rules

- Use direct `glab`, `git`, and `jq` commands.
- Verify uncertain syntax with `glab <subcommand> --help`; `glab` flags vary by command/version.
- Prefer `-F json` for `glab repo view`, `glab issue view`, `glab mr view`, and `glab mr list`; use `-O json` for `glab issue list`.
- Never paste secrets/tokens into issues, MRs, comments, CI logs, screenshots, or command output summaries.
- Treat GitLab issue/MR mutations as allowed workflow actions; do not perform unrelated product/runtime/operator mutations.

## Common commands

### Issues

```bash
glab issue list --per-page 50
glab issue list -O json --per-page 50 | jq '.[] | {iid,title,labels,assignees,web_url}'
glab issue view <id> --comments
glab issue view <id> -F json | jq '{iid,title,state,labels,assignees,web_url}'
```

### Merge Request creation and updates

```bash
# Create/update with a file-backed description.
glab mr create --draft \
  --target-branch "$default_branch" \
  --source-branch "$source_branch" \
  --title "$title" \
  --description "$(cat /tmp/review-packet.md)" \
  --yes

glab mr update <id> --description "$(cat /tmp/review-packet.md)"
glab mr update <id> --ready
```

### MR metadata, CI, and diffs

```bash
glab mr view <id> --comments
glab mr view <id> -F json | jq '{iid,title,state,source_branch,target_branch,sha,author:.author.username,pipeline:.pipeline,detailed_merge_status,web_url}'
glab mr view <id> -F json | jq '{mr_sha:.sha,pipeline:.pipeline,merge:.detailed_merge_status}'
glab ci status --branch "$source_branch" -F json

glab mr diff <id> --raw --color=never | git apply --stat
glab mr diff <id> --raw --color=never | git apply --numstat
glab mr diff <id> --color=never
```

### Comments, approval, and merge

```bash
glab mr note create <id> --message "$(cat /tmp/report.md)"
glab issue note create <id> --message "$(cat /tmp/comment.md)"

glab mr approve <id> --sha "$reviewed_sha"
glab mr merge <id> --yes --sha "$reviewed_sha"
glab mr merge <id> --auto-merge --yes --sha "$reviewed_sha"
```

## Troubleshooting

- If repo lookup fails, confirm the branch remote (`git config --get branch.$(git branch --show-current).remote`), `git remote -v`, and `glab repo view "$repo_url"`.
- If local GitLab has multiple hosts/accounts, pass the explicit repo URL or `-R "$repo_url"` instead of relying on `glab` inference.
- If JSON fields differ, inspect raw `glab ... -F json | jq 'keys'` and adapt only the projection, not the workflow.
