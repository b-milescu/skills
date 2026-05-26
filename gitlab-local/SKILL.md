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

### Snippet: ci-watch-sha-pinned

Use when a parent orchestrator, reviewer, or authorized finisher needs a CI
verdict for the exact MR head that was reviewed. Builders may record this
output in a Review Packet, but CI success does not grant builder approval or
merge authority.

Inputs:

- `mr_iid`: merge request IID.
- `source_branch`: MR source branch, used only as a fallback/progress view.
- `reviewed_sha`: SHA from the review report or Reviewer Lift.
- `timeout_seconds` and `poll_seconds`: caller-selected wait budget.
- Optional output mode: human summary or machine-readable YAML.

Polling and SHA rules:

1. Re-read `glab mr view "$mr_iid" -F json` on every poll; do not rely on
   `glab mr list` for decision-grade data.
2. Fail immediately if MR `.sha` differs from `reviewed_sha`; the review is
   stale and a new review is needed.
3. Prefer MR `.pipeline`; use `glab ci status --branch "$source_branch" -F json`
   only when MR metadata has no attached pipeline yet or to print job progress.
   Do not use `glab ci status --mr`.
4. A green CI verdict is valid only when pipeline `.sha` equals
   `reviewed_sha` and `.status` is `success`.
5. `failed`, `canceled`, `skipped`, or required-job failure for
   `reviewed_sha` is a failing verdict.
6. Stale CI for any other SHA never passes. Continue polling until the expected
   SHA appears or the timeout expires; final output must say `stale_ci` or
   `timeout` and include the last observed SHA/status.
7. Timeout output is non-zero and includes last MR pipeline and branch/job
   summary so the caller can distinguish "no pipeline yet" from stale CI.

Shell shape:

```bash
mr_iid="<id>"
source_branch="<source-branch>"
reviewed_sha="<sha-you-reviewed>"
timeout_seconds="${timeout_seconds:-900}"
poll_seconds="${poll_seconds:-15}"
deadline=$((SECONDS + timeout_seconds))
last_summary="none"
pipeline_status="none"
pipeline_sha="none"

while [ "$SECONDS" -le "$deadline" ]; do
  mr_json="$(glab mr view "$mr_iid" -F json)"
  current_sha="$(jq -r '.sha // ""' <<<"$mr_json")"
  [ "$current_sha" = "$reviewed_sha" ] || {
    echo "CI_WATCH result=head_changed current=$current_sha reviewed=$reviewed_sha" >&2
    exit 2
  }

  pipeline_json="$(jq -c '.pipeline // {}' <<<"$mr_json")"
  pipeline_id="$(jq -r '.id // "none"' <<<"$pipeline_json")"
  pipeline_status="$(jq -r '.status // "none"' <<<"$pipeline_json")"
  pipeline_sha="$(jq -r '.sha // "none"' <<<"$pipeline_json")"
  pipeline_url="$(jq -r '.web_url // "none"' <<<"$pipeline_json")"

  branch_json="$(glab ci status --branch "$source_branch" -F json 2>/dev/null || true)"
  branch_id="$(jq -r '.pipeline.id // "none"' <<<"${branch_json:-{}}" 2>/dev/null || echo none)"
  branch_status="$(jq -r '.pipeline.status // "none"' <<<"${branch_json:-{}}" 2>/dev/null || echo none)"
  branch_sha="$(jq -r '.pipeline.sha // "none"' <<<"${branch_json:-{}}" 2>/dev/null || echo none)"
  failed_jobs="$(jq -r '.jobs[]? | select((.allow_failure != true) and (.status == "failed" or .status == "canceled" or .status == "skipped")) | .name' <<<"${branch_json:-{}}" 2>/dev/null | paste -sd, -)"
  last_summary="mr_pipeline=$pipeline_id:$pipeline_status:$pipeline_sha branch_pipeline=$branch_id:$branch_status:$branch_sha failed_jobs=${failed_jobs:-none}"
  echo "CI_WATCH elapsed=${SECONDS}s $last_summary"

  if [ "$pipeline_sha" = "$reviewed_sha" ]; then
    case "$pipeline_status" in
      success)
        echo "CI_WATCH result=pass pipeline=$pipeline_id sha=$pipeline_sha url=$pipeline_url"
        exit 0
        ;;
      failed|canceled|skipped)
        echo "CI_WATCH result=fail pipeline=$pipeline_id status=$pipeline_status sha=$pipeline_sha failed_jobs=${failed_jobs:-unknown}" >&2
        exit 1
        ;;
    esac
  fi

  sleep "$poll_seconds"
done

final_result="timeout"
if [ "$pipeline_sha" != "none" ] && [ "$pipeline_sha" != "$reviewed_sha" ]; then
  final_result="stale_ci"
fi
echo "CI_WATCH result=$final_result reviewed=$reviewed_sha last=$last_summary" >&2
exit 3
```

Machine output fields should include `mr`, `expected_sha`, `observed_sha`,
`pipeline_id`, `status`, `url`, failed/running job names when available, and
`result: pass | fail | head_changed | stale_ci | timeout`.

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

### Snippet: finish-mr-authority-aware

Use after an independent review decision, not from a child builder. A builder may
prepare or report the inputs, but must not approve, merge, queue auto-merge, or
pretend to complete the review gate. Only a reviewer performing the review flow
or an explicitly authorized parent/human may run the approve/merge steps.

Inputs:

- `mr_iid`: merge request IID.
- `reviewed_sha`: SHA approved by the reviewer and guarded with `--sha`.
- `merge_authority`: `approval-only`, `reviewer may merge`,
  `queue auto-merge`, `human release`, or project default text.
- `caller_role`: `builder`, `reviewer`, `authorized-parent`, or `human`.
- `source_branch`, `default_branch`, and optional `worktree_path`.
- Optional `issue_iid` when it is not obvious from `Closes #...`.

Guard and authority order:

1. Run the help-first checks for every flagged command in the chosen path.
2. Re-read `glab mr view "$mr_iid" -F json`; require current `.sha` to equal
   `reviewed_sha` before approval, merge, auto-merge, or cleanup.
3. Require CI evidence for `reviewed_sha`: `.pipeline.sha == reviewed_sha` and
   `.pipeline.status == success`. Pending/running CI may only proceed to
   protected auto-merge when project policy and `merge_authority` allow it.
   Red, canceled, skipped, missing, or stale CI blocks finish unless an
   authorized human waiver is recorded in the MR.
4. Apply authority:
   - `builder`: always stop with a handoff; no approval, merge, queue, or remote
     branch deletion.
   - `approval-only`: finish flow stops after reporting SHA/CI. Reviewer
     approval, if any, belongs to the separate review action; no merge.
   - `reviewer may merge`: reviewer or authorized parent may approve/merge with
     `--sha` after the guards pass.
   - `queue auto-merge`: authorized caller may queue auto-merge with `--sha`;
     GitLab protected checks must still require green CI before merge.
   - `human release`: stop with release handoff; no agent merge.
5. Fetch/pull default branch only after merge/queue action or when producing a
   final status. Use `git fetch origin`, then fast-forward local default only in
   a clean checkout where that branch can be checked out safely.
6. Verify linked issue state with `glab issue view "$issue_iid" -F json` when an
   issue IID is known. Report `closure_pending` rather than force-closing unless
   the workflow explicitly told you to close the issue.
7. Remove a worktree only when `git -C "$worktree_path" status --porcelain` is
   empty and branch push/merge state is known. Delete local/remote source
   branches only after merge or auto-merge policy permits it; prefer GitLab's
   remove-source-branch setting when available.
8. Emit final status: MR IID/URL, reviewed SHA, CI status/SHA, action taken,
   issue state, cleanup result, and blocker reason if any.

Authorized-caller shell shape:

```bash
mr_iid="<id>"
reviewed_sha="<sha-you-reviewed>"
merge_authority="<approval-only|reviewer may merge|queue auto-merge|human release>"
caller_role="<reviewer|authorized-parent|human|builder>"
source_branch="<source-branch>"
default_branch="<default-branch>"

mr_json="$(glab mr view "$mr_iid" -F json)"
current_sha="$(jq -r '.sha // ""' <<<"$mr_json")"
[ "$current_sha" = "$reviewed_sha" ] || {
  echo "FINISH_MR result=blocked reason=head_changed current=$current_sha reviewed=$reviewed_sha" >&2
  exit 2
}

pipeline_status="$(jq -r '.pipeline.status // "none"' <<<"$mr_json")"
pipeline_sha="$(jq -r '.pipeline.sha // "none"' <<<"$mr_json")"
pipeline_url="$(jq -r '.pipeline.web_url // "none"' <<<"$mr_json")"
ci_guard="blocked"
if [ "$pipeline_sha" = "$reviewed_sha" ] && [ "$pipeline_status" = "success" ]; then
  ci_guard="green"
elif [ "$pipeline_sha" = "$reviewed_sha" ] && [ "$merge_authority" = "queue auto-merge" ]; then
  case "$pipeline_status" in
    pending|running|created) ci_guard="pending_for_protected_auto_merge" ;;
  esac
fi
[ "$ci_guard" != "blocked" ] || {
  echo "FINISH_MR result=blocked reason=ci_not_green status=$pipeline_status pipeline_sha=$pipeline_sha reviewed=$reviewed_sha" >&2
  exit 3
}

case "$caller_role:$merge_authority" in
  builder:*)
    echo "FINISH_MR result=handoff reason=builder_no_approve_or_merge sha=$reviewed_sha ci=$ci_guard"
    exit 0
    ;;
  *:approval-only|*:human\ release)
    echo "FINISH_MR result=handoff authority=$merge_authority sha=$reviewed_sha ci=$ci_guard"
    exit 0
    ;;
  reviewer:reviewer\ may\ merge|authorized-parent:reviewer\ may\ merge|human:reviewer\ may\ merge)
    if [ "${approve_as_reviewer:-false}" = "true" ]; then
      glab mr approve "$mr_iid" --sha "$reviewed_sha"
    fi
    glab mr merge "$mr_iid" --yes --sha "$reviewed_sha"
    finish_action="merged"
    ;;
  reviewer:queue\ auto-merge|authorized-parent:queue\ auto-merge|human:queue\ auto-merge)
    glab mr merge "$mr_iid" --auto-merge --yes --sha "$reviewed_sha"
    finish_action="auto_merge_queued"
    ;;
  *)
    echo "FINISH_MR result=blocked reason=authority caller=$caller_role authority=$merge_authority" >&2
    exit 4
    ;;
esac

git fetch origin
if [ -z "$(git status --porcelain)" ] && git checkout "$default_branch"; then
  git pull --ff-only origin "$default_branch"
else
  echo "FINISH_MR default_update=skipped reason=dirty_or_unavailable_checkout" >&2
fi

issue_state="not_checked"
if [ -n "${issue_iid:-}" ]; then
  issue_state="$(glab issue view "$issue_iid" -F json | jq -r '.state // "unknown"')"
fi

worktree_cleanup="not_requested"
if [ -n "${worktree_path:-}" ]; then
  if [ -z "$(git -C "$worktree_path" status --porcelain)" ]; then
    git worktree remove "$worktree_path"
    worktree_cleanup="removed"
  else
    worktree_cleanup="blocked_dirty_worktree"
  fi
fi

branch_cleanup="not_requested"
if [ "$finish_action" = "merged" ] && [ "${delete_local_source_branch:-false}" = "true" ]; then
  if git branch -d "$source_branch"; then
    branch_cleanup="local_deleted"
  else
    branch_cleanup="local_delete_blocked"
  fi
fi
if [ "$finish_action" = "merged" ] && [ "${delete_remote_source_branch:-false}" = "true" ]; then
  git push origin --delete "$source_branch"
  branch_cleanup="$branch_cleanup,remote_deleted"
fi

echo "FINISH_MR result=$finish_action sha=$reviewed_sha ci=$ci_guard pipeline_sha=$pipeline_sha pipeline_url=$pipeline_url issue_state=$issue_state worktree=$worktree_cleanup branch=$branch_cleanup"
```

Machine output should use the same facts as the human line, for example
`result: merged | auto_merge_queued | handoff | blocked`, plus `blocker` when
non-success output requires parent/human action.

## Optional helper scripts

This repo also ships optional wrappers in `scripts/` for the accepted
`ci-watch-sha-pinned` and `finish-mr-authority-aware` behaviors. Use them when
that exact behavior fits and you want repeatable guardrails. Prefer the raw
snippets in this skill when `glab` flag/JSON drift appears, a project-specific
policy or human waiver is involved, you need a step-by-step troubleshooting
transcript, or you are changing the accepted workflow behavior itself.

## Troubleshooting

Repo wrong: inspect branch remote, `git remote -v`, and `glab repo view "$repo_url"`. JSON shape wrong: inspect keys and adapt projection only. Flag fails: rerun exact `glab <area> <verb> --help` and remove unsupported flag.
