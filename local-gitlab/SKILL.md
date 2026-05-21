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
branch="$(git branch --show-current)"
remote="$(git config --get "branch.${branch}.remote" 2>/dev/null)"
repo_url="$(git remote get-url "${remote:-origin}" 2>/dev/null || git remote get-url origin)"
glab repo view "$repo_url" >/dev/null || { echo "glab cannot access repo"; exit 1; }
default_branch="$(glab repo view "$repo_url" -F json | jq -er '.default_branch')" \
  || { echo "no default_branch"; exit 1; }
```

Use `"$repo_url"` (or `-R "$repo_url"`) when `glab` might infer the wrong repo/host. `glab auth status` is useful, but successful `glab repo view "$repo_url"` is the real local-project auth check.

## Rules

- Use direct `glab`, `git`, and `jq` commands.
- Verify uncertain syntax with `glab <subcommand> --help`; `glab` flags vary by command/version.
- Prefer `-F json` for `glab repo view`, `glab issue view`, `glab mr view`, and `glab mr list`; use `-O json` for `glab issue list`.
- Treat `glab mr list` output as candidate-discovery data only; use `glab mr view <id> -F json` for decision-grade MR SHA, pipeline, and merge status.
- Create temp/artifact directories in the same shell command before redirecting into them. Do not rely on another parallel tool call to create shared temp paths.
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
# Create with a file-backed description. Add --push when the source branch
# is not yet on the remote (first-commit MR open); omit if already pushed.
glab mr create --draft --push \
  --target-branch "$default_branch" \
  --source-branch "$source_branch" \
  --title "$title" \
  --description "$(cat /tmp/review-packet.md)" \
  --yes

glab mr update <id> --description "$(cat /tmp/review-packet.md)"
glab mr update <id> --ready
```

### MR pickup, metadata, CI, and diffs

```bash
# Pickup
glab mr view                                                 # MR for the current branch (no id)
glab mr list --not-draft -F json --per-page 50               # candidate list only (filter with -a/-l/-t, --reviewer)

# Store review artifacts safely (create the directory in this command)
mr_id="<id>"
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/glab-mr-${mr_id}.XXXXXX")"
glab mr view "$mr_id" --comments > "$run_dir/mr-comments.txt"
glab mr view "$mr_id" -F json > "$run_dir/mr.json"
glab mr diff "$mr_id" --color=never > "$run_dir/diff.patch"

# Metadata: descriptive projection
glab mr view <id> --comments
glab mr view <id> -F json | jq '{iid,title,state,source_branch,target_branch,author:.author.username,web_url}'

# Branch CI snapshot (decision-time SHA/pipeline/merge lives below under "Decision-time CI check")
glab ci status --branch "$source_branch" -F json

# Diffs
glab mr diff <id> --raw --color=never | git apply --numstat
glab mr diff <id> --color=never
```

### Comments, review decisions, approval, and merge

Use file-backed messages for long reports/comments — avoids shell escaping problems.

```bash
glab mr note create <id> --message "$(cat /tmp/report.md)"
glab issue note create <id> --message "$(cat /tmp/comment.md)"
```

Guard the reviewed SHA immediately before any review decision that depends on the MR head. Never approve or merge a SHA you have not read. Posting the report comment doesn't depend on SHA — re-run the SHA guard below immediately before approve/merge.

```bash
reviewed_sha="<sha-you-reviewed>"
current_sha="$(glab mr view <id> -F json | jq -r '.sha')"
[ "$current_sha" = "$reviewed_sha" ] || {
  echo "MR head changed: current=$current_sha reviewed=$reviewed_sha" >&2
  exit 1
}
```

Decision-time CI check:

```bash
glab mr view <id> -F json | jq '{mr_sha:.sha,pipeline:.pipeline,merge:.detailed_merge_status}'
```

If `pipeline.sha` is exposed, it must equal `reviewed_sha` before green CI counts. If the builder-reported pipeline was superseded by a newer pipeline on the same SHA, use the current MR pipeline in the Review Report and note the supersession.

Request changes: post the Review Report, then apply the repo's revision label (example: `needs-revision`; use the project's actual label vocabulary).

```bash
glab mr note create <id> --message "$(cat /tmp/report.md)"
glab mr update <id> --label needs-revision --yes
```

After a revision is verified, remove the revision label if the project uses one.

```bash
glab mr update <id> --unlabel needs-revision --yes
```

Approve the exact reviewed SHA. Merge or queue auto-merge only when project policy / MR `Merge authority` allows it, and always bind to the reviewed SHA.

```bash
glab mr approve <id> --sha "$reviewed_sha"

# If not merging immediately after approval, re-run the SHA guard first.
glab mr merge <id> --yes --sha "$reviewed_sha"
glab mr merge <id> --auto-merge --yes --sha "$reviewed_sha"

# Verify merge result:
glab mr view <id> -F json | jq '{iid,title,state,sha,merged_at,merge_commit_sha,detailed_merge_status,web_url}'
```

## Known glab pitfalls

- `glab repo view` uses `-F json`, **not** `--json`. `glab issue view` and `glab mr view` also use `-F json`; `glab issue list` uses `-O json`.
- `glab mr diff` has **no** `--stat` flag. Use `glab mr diff <id> --raw --color=never | git apply --numstat` for a path-level changeset.
- `glab ci status --mr` is unreliable. Prefer `glab ci status --branch <source-branch> -F json`, or read the MR's `pipeline` field via `glab mr view <id> -F json | jq '{sha,pipeline,merge:.detailed_merge_status}'`.
- `glab mr list -F json` can return sparse or stale fields (for example `pipeline: null`) even when `glab mr view <id> -F json` has the current pipeline. Use list output for pickup triage only.
- Before treating green CI as evidence: the current MR pipeline's commit SHA (when GitLab exposes it) must equal the MR head SHA — stale green CI is a real risk after a post-ready push. Builder-reported pipeline IDs can be superseded; verify the current MR pipeline immediately before approval/merge.

## Troubleshooting

- If repo lookup fails, confirm the branch remote (`git config --get branch.$(git branch --show-current).remote`), `git remote -v`, and `glab repo view "$repo_url"`.
- If local GitLab has multiple hosts/accounts, pass the explicit repo URL or `-R "$repo_url"` instead of relying on `glab` inference.
- If JSON fields differ, inspect raw `glab ... -F json | jq 'keys'` and adapt only the projection, not the workflow.
