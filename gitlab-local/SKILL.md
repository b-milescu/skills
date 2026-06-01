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

Project-profile hooks may specialize project policy, but they must not weaken reviewed-SHA binding, exact-SHA CI, explicit authority source, independent review, child-builder boundaries, verifier read-only boundaries, help-first `glab` correctness, this help-first rule, or live `glab --help` verification. They also must not rename GitLab records in shared delivery blocks: keep `issue`, `MR`, `pipeline`, `source branch`, `target branch`, and `SHA` terminology.

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

The relocated polling/SHA mechanics for `ci-watch-sha-pinned` and the finish
guard/authority mechanics for `finish-mr-authority-aware` live in
[`reference/ci-finish-guards.md`](reference/ci-finish-guards.md); each snippet
below links to that card and points verdict-classification/authority policy to
the canonical owners in `start-review/REVIEW-FLOW.md` and `start-build/SAFETY.md`.

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

### Snippet: draft-mr-create

Use only to open the early Draft MR after the source branch exists remotely.
This snippet intentionally does not update an existing MR or mark it ready.

```bash
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-mr-create.XXXXXX")"
description_file="$run_dir/review-packet.md"
# Write or fill "$description_file" before creating the MR.

glab mr create --draft --push --target-branch "$default_branch" --source-branch "$source_branch" \
  --title "$title" --description "$(cat "$description_file")" --yes
```

### Snippet: mr-description-update

Use to refresh the MR description / Reviewer Lift. This snippet intentionally
keeps draft/ready state unchanged.

```bash
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-mr-description.XXXXXX")"
description_file="$run_dir/review-packet.md"
# Write or fill "$description_file" before updating the MR description.

glab mr update <id> --description "$(cat "$description_file")"
```

### Snippet: draft-mr-mark-ready

Use only after the local gate has passed (or N/A is documented), the MR
description and Reviewer Lift name the current head SHA, and the workflow is
ready for review. Do not paste this with Draft MR creation or description update
commands as one executable sequence.

```bash
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

Role eligibility (who may call) lives in
[`reference/ci-finish-guards.md`](reference/ci-finish-guards.md#ci-verdict-mechanics-ci-watch-sha-pinned).

Inputs:

- `mr_iid`: merge request IID.
- `source_branch`: MR source branch, used only as a fallback/progress view.
- `reviewed_sha`: SHA from the review report or Reviewer Lift.
- `timeout_seconds` and `poll_seconds`: caller-selected wait budget.
- Optional output mode: human summary or machine-readable YAML.

Polling/SHA mechanics, fail-closed output shape, and the pointer to the canonical
CI verdict classification live in
[`reference/ci-finish-guards.md`](reference/ci-finish-guards.md#ci-verdict-mechanics-ci-watch-sha-pinned).

Implementation body lives inside this skill:

- Source: [`scripts/gitlab-ci-watch.sh`](scripts/gitlab-ci-watch.sh)
- Helper docs: [`scripts/README.md`](scripts/README.md#gitlab-workflow-helpers)
- Regression tests: [`tests/gitlab-workflow-helpers.sh`](../tests/gitlab-workflow-helpers.sh)

Use the helper when the accepted behavior fits. In agent-run shell commands, use
the full script URI; do **not** assign `skill://gitlab-local` to a directory
variable because bare skill URIs resolve to `SKILL.md` in shell runners.

```bash
gitlab_ci_watch_script="skill://gitlab-local/scripts/gitlab-ci-watch.sh"
"$gitlab_ci_watch_script" \
  --mr-iid "$mr_iid" \
  --source-branch "$source_branch" \
  --reviewed-sha "$reviewed_sha" \
  --timeout-seconds "${timeout_seconds:-900}" \
  --poll-seconds "${poll_seconds:-15}" \
  --format human
```

For raw-command adaptation (keeping every polling/SHA rule, fail-closed output,
and machine fields), see
[`reference/ci-finish-guards.md`](reference/ci-finish-guards.md#ci-verdict-mechanics-ci-watch-sha-pinned).

Wrapper bodies for the next five snippets live in
[`scripts/gitlab-wrappers.sh`](scripts/gitlab-wrappers.sh); helper docs:
[`scripts/README.md`](scripts/README.md#gitlab-workflow-helpers); tests:
[`tests/gitlab-workflow-helpers.sh`](../tests/gitlab-workflow-helpers.sh).

### Snippet: mr-note-create

Use wrapper `mr_note_create` for MR comments only. Require explicit `--repo` and
`--mr-iid`; the message is file-backed and the wrapper output does not print it.

```bash
gitlab_wrappers_script="skill://gitlab-local/scripts/gitlab-wrappers.sh"
"$gitlab_wrappers_script" mr_note_create --repo "$repo_url" --mr-iid "$mr_iid" --message-file "$report_file"
```

### Snippet: issue-note-create

Use wrapper `issue_note_create` for issue comments only. Do not pair this with an
MR-note command or use it for Review Reports.

```bash
gitlab_wrappers_script="skill://gitlab-local/scripts/gitlab-wrappers.sh"
"$gitlab_wrappers_script" issue_note_create --repo "$repo_url" --issue-iid "$issue_iid" --message-file "$comment_file"
```

### Snippet: label-reconcile

Use wrapper `label_reconcile`; it computes add/remove sets and rejects
add/remove overlap plus final state/category label conflicts before calling
`glab issue update`.

```bash
gitlab_wrappers_script="skill://gitlab-local/scripts/gitlab-wrappers.sh"
"$gitlab_wrappers_script" label_reconcile --repo "$repo_url" --issue-iid "$issue_iid" \
  --add-labels "$add_labels" --remove-labels "$remove_labels" \
  --state-labels "$state_labels" --category-labels "$category_labels"
```

### Snippet: safe-mr-json

Use wrapper `safe_mr_json` for decision-grade MR metadata; it fails closed on
project binding, SHA, pipeline, merge-status, branch, JSON, or control-char drift.

```bash
gitlab_wrappers_script="skill://gitlab-local/scripts/gitlab-wrappers.sh"
"$gitlab_wrappers_script" safe_mr_json --repo "$repo_url" --mr-iid "$mr_iid" --project-path "$project_path"
```

### Snippet: auto-merge-api-fallback

Authorized non-builders may use wrapper `auto_merge_api_fallback` only for
`queue auto-merge`; it preserves SHA/CI guards and falls back to API only for
the known `glab mr merge --auto-merge` 405 path.

```bash
gitlab_wrappers_script="skill://gitlab-local/scripts/gitlab-wrappers.sh"
"$gitlab_wrappers_script" auto_merge_api_fallback --repo "$repo_url" --project-path "$project_path" \
  --mr-iid "$mr_iid" --reviewed-sha "$reviewed_sha" --source-branch "$source_branch" \
  --target-branch "$target_branch" --merge-authority "queue auto-merge" \
  --authority-source "$merge_authority_source" --authority-verified true --caller-role "$caller_role"
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
glab mr merge "$mr_iid" --yes --sha "$reviewed_sha" --auto-merge=false
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

Role eligibility (who may call) lives in
[`reference/ci-finish-guards.md`](reference/ci-finish-guards.md#finish-guardauthority-mechanics-finish-mr-authority-aware).

Inputs:

- `mr_iid`: merge request IID.
- `reviewed_sha`: SHA approved by the reviewer and guarded with `--sha`.
- `merge_authority`: `approval-only`, `reviewer may merge`,
  `queue auto-merge`, or `human release`. Resolve project-default policy text
  to one of those accepted helper authorities before invoking the helper.
- `caller_role`: `builder`, `reviewer`, `authorized-parent`, or `human`.
- `source_branch`, `default_branch`, and optional `worktree_path`.
- Optional `issue_iid` when it is not obvious from `Closes #...`.

The full guard order (SHA-bound finish, exactly one finish action,
fetch/fast-forward only after the action, `closure_pending` issue reporting,
worktree-removal preconditions) and the pointer to the canonical merge/authority
matrix live in
[`reference/ci-finish-guards.md`](reference/ci-finish-guards.md#finish-guardauthority-mechanics-finish-mr-authority-aware).

Implementation body lives inside this skill:

- Source: [`scripts/gitlab-finish-mr.sh`](scripts/gitlab-finish-mr.sh)
- Helper docs: [`scripts/README.md`](scripts/README.md#gitlab-workflow-helpers)
- Regression tests: [`tests/gitlab-workflow-helpers.sh`](../tests/gitlab-workflow-helpers.sh)

Use the helper only when the exact accepted authority model fits. In agent-run
shell commands, use the full script URI; do **not** assign
`skill://gitlab-local` to a directory variable because bare skill URIs resolve
to `SKILL.md` in shell runners.

```bash
gitlab_finish_mr_script="skill://gitlab-local/scripts/gitlab-finish-mr.sh"
"$gitlab_finish_mr_script" \
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

For raw-command adaptation (keeping the guard order, exactly one finish action,
SHA-bound approval/merge, builder handoff semantics, and machine output fields),
see
[`reference/ci-finish-guards.md`](reference/ci-finish-guards.md#finish-guardauthority-mechanics-finish-mr-authority-aware).

## Optional helper scripts

This skill also ships optional wrappers in `scripts/` for the accepted
`ci-watch-sha-pinned` and `finish-mr-authority-aware` behaviors. Use them when
that exact behavior fits and you want repeatable guardrails. Prefer the raw
snippets in this skill when `glab` flag/JSON drift appears, a project-specific
policy or human waiver is involved, you need a step-by-step troubleshooting
transcript, or you are changing the accepted workflow behavior itself.

## Troubleshooting

Repo wrong: inspect branch remote, `git remote -v`, and `glab repo view "$repo_url"`. JSON shape wrong: inspect keys and adapt projection only. Flag fails: rerun exact `glab <area> <verb> --help` and remove unsupported flag.
