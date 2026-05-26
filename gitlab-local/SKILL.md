---
name: gitlab-local
description: >-
  Help-first glab guidance for local/self-hosted GitLab: verify flags with
  --help, then use essential issue/MR/CI snippets and local pitfalls. Used by
  start-build and start-review.
---

# Local GitLab via glab

Use from the GitLab-backed worktree. `glab` flags vary by command/version; **help output wins**.

## Help-first rule

Before any flagged `glab` command, run exact command help and verify every flag:

```bash
glab issue list --help; glab issue view --help; glab issue create --help
glab mr list --help; glab mr view --help; glab mr diff --help
glab mr create --help; glab mr update --help; glab mr approve --help; glab mr merge --help
glab ci status --help; glab repo view --help
```

Do not invent flags from memory or other CLIs. If help conflicts with this skill, use help and note skill drift.

## Important local pitfalls

- `glab issue list`: open is default. No `--state`; use `--closed` or `--all` only if help shows them.
- `glab issue list`: JSON uses `-O json` / `--output json`; `-F` means `--output-format` (`details`, `ids`, `urls`).
- `glab repo view`, `issue view`, `mr view`, `mr list`: JSON uses `-F json`.
- Issue `labels` are strings: use `.labels`, not `.labels[].name`.
- Issue comments: `glab issue note <id> --message ...`; no `issue note create`.
- MR comments: `glab mr note create <id> --message ...`.
- `glab mr diff` has no `--stat`; use raw diff with `git apply --numstat`.
- `glab ci status --mr` is unreliable; prefer branch CI or MR `.pipeline`.
- `glab mr list -F json` is candidate data; use `glab mr view <id> -F json` for decision-grade SHA/pipeline/mergeability.
- Use `-R "$repo_url"` when repo/host inference might be wrong.
- Use file-backed long descriptions/messages. Never paste secrets into issues, MRs, comments, logs, or summaries.

## Safe multiline GitLab text

Use temp/run-dir files plus quoted heredocs for multiline MR notes, issue notes,
and MR descriptions. Quoted heredocs (`<<'EOF'`) keep Markdown backticks,
`$VARS`, and command substitutions literal while writing the local file.

MR note pattern:

```bash
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-note.XXXXXX")"
message_file="$run_dir/mr-note.md"
cat > "$message_file" <<'EOF'
## Review Gate Summary

- Reviewed SHA: `abc123`
- Result: approved
- Literal example: `echo "$EXAMPLE_VAR"` is not executed.
EOF

glab mr note create "$mr_iid" --message "$(cat "$message_file")"
```

Issue note pattern:

```bash
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-note.XXXXXX")"
message_file="$run_dir/issue-note.md"
cat > "$message_file" <<'EOF'
## Build Handoff

- MR: !123
- Status: ready for review
EOF

glab issue note "$issue_iid" --message "$(cat "$message_file")"
```

MR description pattern:

```bash
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-mr.XXXXXX")"
description_file="$run_dir/review-packet.md"
cat > "$description_file" <<'EOF'
# Review Packet

Generated from a local file so Markdown is not interpreted by the shell.
EOF

glab mr create --draft --target-branch "$default_branch" --source-branch "$source_branch" \
  --title "$title" --description "$(cat "$description_file")" --yes
glab mr update "$mr_iid" --description "$(cat "$description_file")"
```

Avoid inline heredoc command substitution such as:

```bash
# Do not use: backticks and $() in the body can execute before glab sees them.
glab mr note create "$mr_iid" --message "$(cat <<EOF
Danger: `date` and $(whoami) may run in the parent shell.
EOF
)"
```

Keep generated text files under temp/run directories, never commit review
artifacts, and redact secrets before writing text that may be pasted to GitLab.

## Canonical snippets

Names below are stable API for workflow skills. Verify flags with `--help` before use.

### Snippet: local-repo-preflight

```bash
command -v glab >/dev/null || { echo "glab missing"; exit 1; }
command -v jq >/dev/null || { echo "jq missing"; exit 1; }
git rev-parse --show-toplevel >/dev/null || { echo "not a git repo"; exit 1; }
branch="$(git branch --show-current)"
remote="$(git config --get "branch.${branch}.remote" 2>/dev/null || true)"
repo_url="$(git remote get-url "${remote:-origin}" 2>/dev/null || git remote get-url origin)"
glab repo view "$repo_url" >/dev/null || { echo "glab cannot access repo"; exit 1; }
default_branch="$(glab repo view "$repo_url" -F json | jq -er '.default_branch')" || exit 1
```

### Snippet: issue-pickup

```bash
glab issue list --label ready-for-agent -O json --per-page 50 | jq '.[] | {iid,title,labels,assignees,web_url}'
glab issue view <id> --comments
glab issue view <id> -F json | jq '{iid,title,state,labels,assignees,web_url}'
```

Maintenance only when workflow calls for it:

```bash
glab issue close <id>
glab issue update <id> --label foo,bar --unlabel baz
glab issue note <id> --message "$(cat /tmp/comment.md)"
```

### Snippet: draft-mr-create-update

```bash
glab mr create --draft --push --target-branch "$default_branch" --source-branch "$source_branch" \
  --title "$title" --description "$(cat /tmp/review-packet.md)" --yes
glab mr update <id> --description "$(cat /tmp/review-packet.md)"
glab mr update <id> --ready
```

### Snippet: mr-pickup

```bash
glab mr view
glab mr list --not-draft -F json --per-page 50
glab mr list --merged; glab mr list --closed; glab mr list --all
glab mr view <id> --comments
glab mr view <id> -F json | jq '{iid,title,state,draft,source_branch,target_branch,author:.author.username,web_url,sha,pipeline,detailed_merge_status}'
```

### Snippet: artifact-capture

```bash
mr_id="<id>"; run_dir="$(mktemp -d "${TMPDIR:-/tmp}/glab-mr-${mr_id}.XXXXXX")"
glab mr view "$mr_id" --comments > "$run_dir/mr-comments.txt"
glab mr view "$mr_id" -F json > "$run_dir/mr.json"
glab mr diff "$mr_id" --color=never > "$run_dir/diff.patch"
glab mr diff "$mr_id" --raw --color=never | git apply --numstat
```

### Snippet: ci-decision-snapshot

```bash
glab mr view <id> -F json | jq '{mr_sha:.sha,pipeline:.pipeline,merge:.detailed_merge_status}'
glab ci status --branch "$source_branch" -F json
```

### Snippet: note-comment-creation

```bash
glab mr note create <id> --message "$(cat /tmp/report.md)"
glab issue note <id> --message "$(cat /tmp/comment.md)"
```

### Snippet: sha-guard

```bash
reviewed_sha="<sha-you-reviewed>"
current_sha="$(glab mr view <id> -F json | jq -r '.sha')"
[ "$current_sha" = "$reviewed_sha" ] || { echo "MR head changed: current=$current_sha reviewed=$reviewed_sha" >&2; exit 1; }
```

### Snippet: approve-merge-sha-bound

```bash
glab mr approve <id> --sha "$reviewed_sha"
glab mr merge <id> --yes --sha "$reviewed_sha"
glab mr merge <id> --auto-merge --yes --sha "$reviewed_sha"
glab api "projects/<group%2Fproject>/merge_requests/<id>/approvals"
```

## Troubleshooting

Repo wrong: inspect branch remote, `git remote -v`, and `glab repo view "$repo_url"`. JSON shape wrong: inspect keys and adapt projection only. Flag fails: rerun exact `glab <area> <verb> --help` and remove unsupported flag.
