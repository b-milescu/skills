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
glab ci status --help; glab repo view --help; glab api --help
```

Do not invent flags from memory or other CLIs. If help conflicts with this skill, use help and note skill drift.

### Per-run help cache

Help-first remains mandatory. A run-dir help cache may reduce repeated output
noise only after the exact help text has been captured for this run and context.
Keep the cache in a temp/run artifact directory and never commit it.

The run-dir help cache records the exact `glab <command> --help` output with
verification status. Refresh the cache whenever the command, `glab` version, or repo context changes.

Detailed cache contract, context invalidation rules, and the executable helper
pattern live in [reference/help-first.md](reference/help-first.md#per-run-help-cache).

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
and MR descriptions. Quoted heredocs keep Markdown backticks, variables, and
command substitutions literal while writing the local file.

Detailed file-backed note/description patterns and the inline-heredoc hazard live
in [reference/multiline-text.md](reference/multiline-text.md#safe-multiline-gitlab-text).
Keep generated text files under temp/run directories, never commit review
artifacts, and redact secrets before writing text that may be pasted to GitLab.

## Canonical snippets

Names below are stable API for workflow skills. Verify flags with `--help` before use.
Long helper bodies live in `scripts/` with tests; this skill keeps contracts,
safety rules, and pointers authoritative.

Review-focused command cards for `/start-review` live in
[`reference/review-read.md`](reference/review-read.md),
[`reference/review-actions.md`](reference/review-actions.md), and
[`reference/ci.md`](reference/ci.md). The cards are pointer maps for snippet
names, inputs/outputs, fail-closed rules, and fallback conditions; this `SKILL.md`
remains the full help-first owner for command syntax and flag drift.

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

Maintenance only when workflow calls for it. For issue comments, use
`gitlab-local` **Snippet: issue-note-create** explicitly instead of combining
issue and MR note commands.

```bash
glab issue close <id>
glab issue update <id> --label foo,bar --unlabel baz
```

### Snippet: draft-mr-create-update

```bash
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-mr.XXXXXX")"
description_file="$run_dir/review-packet.md"
# Write or fill "$description_file" before creating or updating the MR.

glab mr create --draft --push --target-branch "$default_branch" --source-branch "$source_branch" \
  --title "$title" --description "$(cat "$description_file")" --yes
glab mr update <id> --description "$(cat "$description_file")"
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

Implementation body lives inside this skill:

- Source: [`scripts/gitlab-ci-watch.sh`](scripts/gitlab-ci-watch.sh)
- Helper docs: [`scripts/README.md`](scripts/README.md#gitlab-workflow-helpers)
- Regression tests: [`tests/gitlab-workflow-helpers.sh`](../tests/gitlab-workflow-helpers.sh)

Use the helper when the accepted behavior fits. Resolve the script path against
this `gitlab-local` skill directory before running it from a target repo:

```bash
"$gitlab_local_skill_dir/scripts/gitlab-ci-watch.sh" \
  --mr-iid "$mr_iid" \
  --source-branch "$source_branch" \
  --reviewed-sha "$reviewed_sha" \
  --timeout-seconds "${timeout_seconds:-900}" \
  --poll-seconds "${poll_seconds:-15}" \
  --format human
```

If adapting raw commands instead of the helper, keep every polling/SHA rule
above, run help-first for `glab mr view` and `glab ci status`, and fail closed
on missing, stale, red, or SHA-mismatched CI. Machine output fields should
include `mr`, `expected_sha`, `observed_sha`, `pipeline_id`, `status`, `url`,
failed/running job names when available, and
`result: pass | fail | head_changed | stale_ci | timeout`.

### Snippet: mr-note-create

Use for MR comments only: Review Reports, unblock responses, revision notes, and
action-result notes. Use a bound MR URL or explicit repo target when project
binding requires it; do not pair this with an issue-note command.

```bash
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-mr-note.XXXXXX")"
report_file="$run_dir/mr-report.md"
# Write or fill "$report_file" before posting it.

glab mr note create <id> --message "$(cat "$report_file")"
```

### Snippet: issue-note-create

Use for issue comments only when the issue workflow explicitly calls for an
issue note. Use a bound issue URL or explicit repo target when project binding
requires it; do not pair this with an MR-note command.

```bash
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-issue-note.XXXXXX")"
comment_file="$run_dir/issue-note.md"
# Write or fill "$comment_file" before posting it.

glab issue note <id> --message "$(cat "$comment_file")"
```

### Snippet: sha-guard

```bash
reviewed_sha="<sha-you-reviewed>"
current_sha="$(glab mr view <id> -F json | jq -r '.sha')"
[ "$current_sha" = "$reviewed_sha" ] || { echo "MR head changed: current=$current_sha reviewed=$reviewed_sha" >&2; exit 1; }
```

Approval, direct merge, auto-merge queueing, and approval confirmation are
separate actions. Choose exactly one action snippet for the authority you have.
Never run a combined approval/merge block or paste multiple action snippets as
one executable sequence. Stop or continue only when the workflow explicitly
grants the next action.

### Snippet: sha-bound-approval

Use only when the reviewed SHA is current and explicit authority permits reviewer
approval. For `approval-only` authority, this is the only approval/merge action.

```bash
mr_iid="<id>"
reviewed_sha="<sha-you-reviewed>"
glab mr approve "$mr_iid" --sha "$reviewed_sha"
```

### Snippet: sha-bound-merge

Use only when the reviewed SHA is current, CI/merge guards pass, and explicit
authority permits direct merge.

```bash
mr_iid="<id>"
reviewed_sha="<sha-you-reviewed>"
glab mr merge "$mr_iid" --yes --sha "$reviewed_sha"
```

### Snippet: sha-bound-auto-merge-queue

Use only when the reviewed SHA is current, project policy permits protected
auto-merge, and explicit authority permits queueing auto-merge.

```bash
mr_iid="<id>"
reviewed_sha="<sha-you-reviewed>"
glab mr merge "$mr_iid" --auto-merge --yes --sha "$reviewed_sha"
```

### Snippet: approval-confirmation

Use after `sha-bound-approval` when approval status must be verified through the
approvals endpoint. `approved_by` in MR JSON can lag.

```bash
mr_iid="<id>"
project_path="<group%2Fproject>"
glab api "projects/${project_path}/merge_requests/${mr_iid}/approvals"
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

Implementation body lives inside this skill:

- Source: [`scripts/gitlab-finish-mr.sh`](scripts/gitlab-finish-mr.sh)
- Helper docs: [`scripts/README.md`](scripts/README.md#gitlab-workflow-helpers)
- Regression tests: [`tests/gitlab-workflow-helpers.sh`](../tests/gitlab-workflow-helpers.sh)

Use the helper only when the exact accepted authority model fits. Resolve the
script path against this `gitlab-local` skill directory before running it from a
target repo:

```bash
"$gitlab_local_skill_dir/scripts/gitlab-finish-mr.sh" \
  --mr-iid "$mr_iid" \
  --reviewed-sha "$reviewed_sha" \
  --merge-authority "$merge_authority" \
  --caller-role "$caller_role" \
  --source-branch "$source_branch" \
  --default-branch "$default_branch" \
  --format human
```

Add `--issue-iid`, `--worktree-path`, `--approve-as-reviewer`, or source-branch
cleanup flags only when the workflow and authority explicitly allow them.

If adapting raw commands instead of the helper, keep the guard order above,
run help-first for every flagged `glab` command, perform exactly one finish
action, keep approval/merge SHA-bound, and preserve builder handoff semantics.
Machine output should use the same facts as the human line, for example
`result: merged | auto_merge_queued | handoff | blocked`, plus `blocker` when
non-success output requires parent/human action.

## Optional helper scripts

This skill also ships optional wrappers in `scripts/` for the accepted
`ci-watch-sha-pinned` and `finish-mr-authority-aware` behaviors. Use them when
that exact behavior fits and you want repeatable guardrails. Prefer the raw
snippets in this skill when `glab` flag/JSON drift appears, a project-specific
policy or human waiver is involved, you need a step-by-step troubleshooting
transcript, or you are changing the accepted workflow behavior itself.

## Troubleshooting

Repo wrong: inspect branch remote, `git remote -v`, and `glab repo view "$repo_url"`. JSON shape wrong: inspect keys and adapt projection only. Flag fails: rerun exact `glab <area> <verb> --help` and remove unsupported flag.
