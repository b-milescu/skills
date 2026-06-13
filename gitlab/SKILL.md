---
name: gitlab
description: >-
  MCP-first GitLab transport reference for local/self-hosted GitLab: use
  gitlab-mcp first, then guarded help-first glab fallback for documented gaps.
  Used by start-build and start-review.
---

# GitLab transport reference

Use from the GitLab-backed worktree. GitLab API actions use this transport order:

1. **MCP first.** Use the gitlab-mcp tool(s) named by the stable snippet metadata (`skill://gitlab/reference/snippet-metadata.json`) and its human-readable contract in [`skill://gitlab/reference/snippet-transports.md`](skill://gitlab/reference/snippet-transports.md).
2. **Guarded `glab` fallback second.** Use `glab` only when the snippet contract names an explicit fallback/helper/troubleshooting condition, after re-checking SHA, CI, authority, caller identity, and project binding as applicable.
3. **Local `git` remains local.** Worktree, branch, fetch, rev-parse, and ls-remote safety checks stay in `git`; do not replace local git worktree safety with GitLab API calls.

Known MCP gaps: `merge_merge_request` has an observed robustness/error-normalization gap for one `Branch cannot be merged` case where SHA-bound `glab` merge succeeded, and exposed `list_*` tools do not provide reliable pagination controls for exhaustive lists. Treat those as documented fallback conditions only; never weaken reviewed-SHA binding, exact-SHA CI, authority, caller-identity/token-stability, context-firewall, or content-byte safeguards to use a fallback.

## Slim guard-read for repeated SHA/state guards

The GitLab Mutation Guard re-reads the target MR before every mutation, and `sha-guard` re-checks head equality at every repeated guard. The MCP-first read for those checks is `get_merge_request`, which returns the small decision-grade fields a guard needs (`sha`, `draft`, `state`, `detailedMergeStatus`, plus `mergeStatus`, `sourceBranch`, `targetBranch`, `mergeCommitSha`) **alongside the entire `description`**. On MRs carrying a full Review Packet + Reviewer Lift the description is ~3-4k tokens, so re-fetching it for each repeated guard is a real context-pressure source on long multi-MR batches.

`get_merge_request` has no server-side projection/slim parameter today (it takes only project + MR IID and always returns the full body); a true slim response would require a gitlab-mcp server change tracked in [`agents/gitlab-mcp#87`](https://gitlab.example.com/agents/gitlab-mcp/-/issues/87). Until that lands, use this one sanctioned interim slim guard-read path:

- **First read per MR stays full.** The first `get_merge_request` for an MR — the one a parent/reviewer genuinely needs for Review Packet / Reviewer Lift spot-checks — is unchanged. Read the whole response.
- **Repeated guard re-reads are slim.** For every *subsequent* SHA/state guard on the same MR (the Mutation Guard current-target re-read and each repeated `sha-guard`), call MCP `get_merge_request` and consume **only** the small top-level fields (`sha` / `draft` / `state` / `detailedMergeStatus`); ignore the `description` body. This is a read-discipline rule, not a transport change: it never substitutes for the decision-grade full read where spot-check fields are required.
- **Bounded fallback.** When the repeated guard re-read returns the full body and that body is itself the context-pressure problem — the documented gap "repeated SHA/state guard re-reads where the MCP read returns full bodies" — the `safe-mr-json` snippet (wrapper `safe_mr_json`) is the bounded fallback that projects exactly the decision-grade fields. As always, fallback is second to MCP and re-checks SHA/CI/authority/identity/project binding per the transport order above; it never weakens any guard.
- **Elided-body fallback for first full reads.** When the first `get_merge_request` read returns an elided description body — a compressed or placeholder token such as `<<ccr:...>>` instead of the full text — the "first read stays full" rule is not satisfied; the description was not actually received. In that case, use the `safe-mr-json` bounded fallback (wrapper `safe_mr_json`) to retrieve the actual description content. This is the documented gap "elided MCP body on first full description read". The fallback re-checks project binding and SHA per the transport order; it does not alter transport order, slim guard-read semantics, or the safety-floor litany.

## Guarded glab fallback and help-first rule

Before any flagged fallback `glab` command, run exact command help and verify every flag:

```bash
glab issue list --help; glab issue view --help; glab issue create --help
glab mr list --help; glab mr view --help; glab mr diff --help
glab mr create --help; glab mr update --help; glab mr approve --help; glab mr merge --help
glab ci status --help; glab repo view --help; glab api --help
```

Do not invent flags from memory or other CLIs. If help conflicts with this skill, use help and note skill drift.

Project-profile hooks may specialize project policy, but they must not weaken reviewed-SHA binding, exact-SHA CI, explicit authority source, independent review, child-builder boundaries, verifier read-only boundaries, MCP-first transport correctness plus help-first `glab` fallback correctness, this fallback help-first rule, or live `glab --help` verification. They also must not rename GitLab records in shared delivery blocks: keep `issue`, `MR`, `pipeline`, `source branch`, `target branch`, and `SHA` terminology.

### Per-run help cache

Help-first remains mandatory for fallback `glab`. A run-dir help cache may reduce repeated output noise only after the exact help text has been captured for this run and context. Keep the cache in a temp/run artifact directory and never commit it.

The run-dir help cache records the exact `glab <command> --help` output with verification status. Refresh the cache whenever the command, `glab` version, or repo context changes.

Detailed cache contract, context invalidation rules, and the executable helper pattern live in [skill://gitlab/reference/help-first.md](skill://gitlab/reference/help-first.md#per-run-help-cache).

## Important fallback/local pitfalls

- `glab issue list`: open is default. No `--state`; use `--closed` or `--all` only if help shows them.
- `glab issue list`: JSON uses `-O json` / `--output json`; `-F` means `--output-format` (`details`, `ids`, `urls`).
- `glab repo view`, `issue view`, `mr view`, `mr list`: JSON uses `-F json`.
- Issue `labels` are strings: use `.labels`, not `.labels[].name`.
- Issue comments: `glab issue note <id> --message ...`; no `issue note create`.
- MR comments: `glab mr note create <id> --message ...`.
- `glab mr diff` has no `--stat`; use raw diff with `git apply --numstat`.
- `glab ci status --mr` is unreliable; prefer MCP `get_merge_request`/`list_pipelines` exact-SHA reads, or fallback branch CI / MR `.pipeline` only as contract allows.
- `glab mr list -F json` is candidate data; use MCP `get_merge_request` or fallback `glab mr view <id> -F json` for decision-grade SHA/pipeline/mergeability.
- Use `-R "$repo_url"` when fallback repo/host inference might be wrong.
- Use file-backed long descriptions/messages through documented wrappers; they validate text files for NUL/control-character corruption by delegating to `gitlab-content-guard.sh` before `glab`, never print bodies, and never receive secrets.

## Safe multiline GitLab text

Validate every MR/issue body before mutation, whether it will be sent as an MCP `body`/`description` string or through a fallback file-backed wrapper. Use temp/run-dir files plus quoted heredocs for MR/issue notes and MR descriptions when building text in shell. `skill://gitlab/scripts/gitlab-content-guard.sh` is the shared adapter for both MCP-body-style and file-backed fallback validation; `skill://gitlab/scripts/gitlab-wrappers.sh` delegates to it before `glab`. Diagnostics name the file/body role and offending offset without printing the packet body. Detailed patterns: [`skill://gitlab/reference/safe-text.md`](skill://gitlab/reference/safe-text.md) and [`skill://gitlab/reference/multiline-text.md`](skill://gitlab/reference/multiline-text.md#safe-multiline-gitlab-text).

## GitLab Mutation Guard

Every GitLab mutation uses the ordered **GitLab Mutation Guard** seam in [`skill://gitlab/reference/mutation-guard.md`](skill://gitlab/reference/mutation-guard.md) (`skill://gitlab/reference/mutation-guard.md`) and its machine schema at `skill://gitlab/reference/mutation-guard.schema.json`: project binding, current target re-read, reviewed SHA when relevant, exact-SHA CI when relevant, Authority Verification, caller identity/context, Safe GitLab Text when relevant, fallback eligibility, one mutation, and post-mutation MCP re-read with `via=mcp` / `via=glab-fallback` / `via=n/a` evidence. Fallback is never a bypass for stale head, red/missing/stale CI, missing authority, permission uncertainty, self-finish risk, or content-byte failure.

## Canonical snippets

Names below are stable API for workflow skills. The machine-actionable source of truth for snippet names, MCP primary tools, inputs, outputs, allowed mutations, guards, fallback conditions, post-mutation re-reads, and via evidence is `skill://gitlab/reference/snippet-metadata.json`; the human-readable table lives in [`skill://gitlab/reference/snippet-transports.md`](skill://gitlab/reference/snippet-transports.md) and is checked against that metadata. Inline shell blocks below are guarded `glab` fallback/helper examples, not the primary transport. Long helper bodies live in `scripts/` with tests; this skill keeps contracts, safety rules, and pointers authoritative.

Review-focused cards for `/start-review` live in [`skill://gitlab/reference/review-read.md`](skill://gitlab/reference/review-read.md), [`skill://gitlab/reference/review-actions.md`](skill://gitlab/reference/review-actions.md), and [`skill://gitlab/reference/ci.md`](skill://gitlab/reference/ci.md). The cards are pointer maps for snippet names, inputs/outputs, fail-closed rules, and fallback conditions; this `SKILL.md` remains the full owner for transport order, fallback help-first discipline, and flag drift.

The shared mutation sequence lives in [`skill://gitlab/reference/mutation-guard.md`](skill://gitlab/reference/mutation-guard.md). CI/finish-specific mappings for `ci-watch-sha-pinned` and `finish-mr-authority-aware` live in [`skill://gitlab/reference/ci-finish-guards.md`](skill://gitlab/reference/ci-finish-guards.md); each snippet below links to that card and points verdict-classification/authority policy to the canonical owners in `skill://start-review/REVIEW-FLOW.md` and `skill://start-build/SAFETY.md`.

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
ready_label="<live label mapped to the AFK-ready Triage Role in project_profile.label_profile_ref>"
glab issue list --label "$ready_label" -O json --per-page 50 | jq '.[] | {iid,title,labels,assignees,web_url}'
glab issue view <id> --comments
glab issue view <id> -F json | jq '{iid,title,state,labels,assignees,web_url}'
```

Maintenance only when workflow calls for it. For issue comments, use `gitlab` **Snippet: issue-note-create** explicitly instead of combining issue and MR note commands.

```bash
glab issue close <id>
glab issue update <id> --label foo,bar --unlabel baz
```

### Snippet: draft-mr-create

Open the early Draft MR only after the source branch exists remotely. This snippet neither updates an existing MR nor marks ready; wrapper `draft_mr_create` validates the file-backed Review Packet before fallback `glab mr create`.

```bash
description_file="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-mr-create.XXXXXX")/review-packet.md"
# Write or fill "$description_file" before creating the MR.
gitlab_wrappers_script="skill://gitlab/scripts/gitlab-wrappers.sh"
"$gitlab_wrappers_script" draft_mr_create --repo "$repo_url" \
  --target-branch "$default_branch" --source-branch "$source_branch" \
  --title "$title" --description-file "$description_file"
```

### Snippet: mr-description-update

Refresh the MR description / Reviewer Lift without changing draft/ready state; wrapper `mr_description_update` validates the file-backed Review Packet before fallback `glab mr update`.

```bash
description_file="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-mr-description.XXXXXX")/review-packet.md"
# Write or fill "$description_file" before updating the MR description.
gitlab_wrappers_script="skill://gitlab/scripts/gitlab-wrappers.sh"
"$gitlab_wrappers_script" mr_description_update --repo "$repo_url" --mr-iid "$mr_iid" \
  --description-file "$description_file"
```

### Snippet: draft-mr-mark-ready

Use only after the local gate has passed (or N/A is documented), the MR description and Reviewer Lift name the current head SHA, and the workflow is ready for review. Do not paste this with Draft MR creation or description update commands as one executable sequence.

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

Role eligibility (who may call) lives in [`skill://gitlab/reference/ci-finish-guards.md`](skill://gitlab/reference/ci-finish-guards.md#ci-verdict-mechanics-ci-watch-sha-pinned).

Inputs:

- `mr_iid`: merge request IID.
- `source_branch`: MR source branch, used only as a fallback/progress view.
- `reviewed_sha`: SHA from the review report or Reviewer Lift.
- `timeout_seconds` and `poll_seconds`: caller-selected wait budget.
- Optional output mode: human summary or machine-readable YAML.

Polling/SHA mechanics feed the GitLab Mutation Guard exact-SHA CI phase; CI/finish-specific output shape and the pointer to the canonical CI verdict classification live in [`skill://gitlab/reference/ci-finish-guards.md`](skill://gitlab/reference/ci-finish-guards.md#ci-verdict-mechanics-ci-watch-sha-pinned).

Implementation body lives inside this skill:

- Source: [`skill://gitlab/scripts/gitlab-ci-watch.sh`](skill://gitlab/scripts/gitlab-ci-watch.sh)
- Helper docs: [`skill://gitlab/scripts/README.md`](skill://gitlab/scripts/README.md#gitlab-workflow-helpers)
- Regression tests: [`tests/gitlab-workflow-helpers.sh`](../tests/gitlab-workflow-helpers.sh)

Use the helper when the accepted fallback/helper behavior fits. In agent-run shell commands, use the full script URI — bare first-word, quoted direct, or variable-assigned forms all resolve in **foreground** Bash calls (see [skill:// URI invocation matrix](#skill-uri-invocation-matrix) below). Do **not** assign `skill://gitlab` (the bare skill root) to a variable — it resolves to `SKILL.md`, not the `scripts/` directory. `skill://` URIs are **not** resolved in `run_in_background` invocations — use the variable-assigned form first (the harness expands the URI at assignment, leaving the variable as an absolute path) before launching in the background.

```bash
gitlab_ci_watch_script="skill://gitlab/scripts/gitlab-ci-watch.sh"
"$gitlab_ci_watch_script" \
  --mr-iid "$mr_iid" \
  --source-branch "$source_branch" \
  --reviewed-sha "$reviewed_sha" \
  --timeout-seconds "${timeout_seconds:-900}" \
  --poll-seconds "${poll_seconds:-15}" \
  --format human
```

For raw-command adaptation (keeping the per-poll SHA rules as read-only evidence for the Mutation Guard), see [`skill://gitlab/reference/ci-finish-guards.md`](skill://gitlab/reference/ci-finish-guards.md#ci-verdict-mechanics-ci-watch-sha-pinned) and [`skill://gitlab/reference/mutation-guard.md`](skill://gitlab/reference/mutation-guard.md).

Wrapper bodies for the next five snippets also live in [`skill://gitlab/scripts/gitlab-wrappers.sh`](skill://gitlab/scripts/gitlab-wrappers.sh); helper docs/tests: [`skill://gitlab/scripts/README.md`](skill://gitlab/scripts/README.md#gitlab-workflow-helpers) / [`tests/gitlab-workflow-helpers.sh`](../tests/gitlab-workflow-helpers.sh).

### Snippet: mr-note-create

Use wrapper `mr_note_create` for MR comments only. Require explicit `--repo` and `--mr-iid`; the message is file-backed and the wrapper output does not print it.

```bash
gitlab_wrappers_script="skill://gitlab/scripts/gitlab-wrappers.sh"
"$gitlab_wrappers_script" mr_note_create --repo "$repo_url" --mr-iid "$mr_iid" --message-file "$report_file"
```

### Snippet: issue-note-create

Use wrapper `issue_note_create` for issue comments only. Do not pair this with an MR-note command or use it for Review Reports.

```bash
gitlab_wrappers_script="skill://gitlab/scripts/gitlab-wrappers.sh"
"$gitlab_wrappers_script" issue_note_create --repo "$repo_url" --issue-iid "$issue_iid" --message-file "$comment_file"
```

### Snippet: label-reconcile

Use wrapper `label_reconcile`; it computes add/remove sets and rejects add/remove overlap plus final state/category label conflicts before fallback `glab issue update`.

```bash
gitlab_wrappers_script="skill://gitlab/scripts/gitlab-wrappers.sh"
"$gitlab_wrappers_script" label_reconcile --repo "$repo_url" --issue-iid "$issue_iid" \
  --add-labels "$add_labels" --remove-labels "$remove_labels" \
  --state-labels "$state_labels" --category-labels "$category_labels"
```

### Snippet: safe-mr-json

Use wrapper `safe_mr_json` for decision-grade MR metadata; it fails closed on project binding, SHA, pipeline, merge-status, branch, JSON, or control-char drift.

```bash
gitlab_wrappers_script="skill://gitlab/scripts/gitlab-wrappers.sh"
"$gitlab_wrappers_script" safe_mr_json --repo "$repo_url" --mr-iid "$mr_iid" --project-path "$project_path"
```

### Snippet: auto-merge-api-fallback

Authorized non-builders may use wrapper `auto_merge_api_fallback` only for `queue auto-merge`; it preserves SHA/CI guards and falls back to the GitLab API only for the known `glab mr merge --auto-merge` 405 path. It requests source-branch removal on merge (`--remove-source-branch` on the `glab` path, `should_remove_source_branch=true` on the API path), matching the primary finish path so the remote source branch is gone once the queued merge completes.

```bash
gitlab_wrappers_script="skill://gitlab/scripts/gitlab-wrappers.sh"
"$gitlab_wrappers_script" auto_merge_api_fallback --repo "$repo_url" --project-path "$project_path" \
  --mr-iid "$mr_iid" --reviewed-sha "$reviewed_sha" --source-branch "$source_branch" \
  --target-branch "$target_branch" --merge-authority "queue auto-merge" \
  --authority-source "$merge_authority_source" --authority-verified true --caller-role "$caller_role"
```

### Snippet: sha-guard

MCP primary is `get_merge_request`; read only its top-level `sha`. The fallback below is shown for the MCP-unavailable case. For *repeated* SHA/state guards on the same MR, follow the [slim guard-read path](#slim-guard-read-for-repeated-shastate-guards): keep the first per-MR read full, then consume only `sha` / `draft` / `state` / `detailedMergeStatus` on each subsequent re-read instead of re-fetching the full description.

```bash
reviewed_sha="<sha-you-reviewed>"
current_sha="$(glab mr view <id> -F json | jq -r '.sha')"
[ "$current_sha" = "$reviewed_sha" ] || { echo "MR head changed: current=$current_sha reviewed=$reviewed_sha" >&2; exit 1; }
```

Approval, direct merge, auto-merge queueing, and approval confirmation are separate actions. Choose exactly one action snippet for the authority you have. Never run a combined approval/merge block or paste multiple action snippets as one executable sequence. Before any approval/merge action or fallback, run the GitLab Mutation Guard in [`skill://gitlab/reference/mutation-guard.md`](skill://gitlab/reference/mutation-guard.md): fresh target re-read, reviewed SHA, exact-SHA CI when relevant, canonical Authority Verification from [`skill://gitlab/reference/authority-verification.md`](skill://gitlab/reference/authority-verification.md), caller identity/token stability, context-firewall eligibility, Safe GitLab Text when relevant, fallback eligibility, one mutation, then post-mutation MCP re-read with `via=mcp` / `via=glab-fallback` evidence. Stop on stale head, red/missing/stale CI, missing authority, permission uncertainty, identity drift, same-session/self-finish risk, or fallback-ineligible states.

### Snippet: sha-bound-approval

Use only when the reviewed SHA is current, approval authority permits reviewer approval, and no explicit approval restriction applies. For `approval-only` merge authority, this is the only approval/finish action.

```bash
mr_iid="<id>"
reviewed_sha="<sha-you-reviewed>"
glab mr approve "$mr_iid" --sha "$reviewed_sha"
```

### Snippet: sha-bound-merge

Use only when the reviewed SHA is current, CI/merge guards pass, and explicit authority permits direct merge.

```bash
mr_iid="<id>"
reviewed_sha="<sha-you-reviewed>"
glab mr merge "$mr_iid" --yes --sha "$reviewed_sha" --auto-merge=false
```

### Snippet: sha-bound-auto-merge-queue

Use only when the reviewed SHA is current, project policy permits protected auto-merge, and explicit authority permits queueing auto-merge. Request source-branch removal on merge with `--remove-source-branch` (MCP primary: `should_remove_source_branch=true`), matching the primary finish path so the remote source branch is gone once the queued merge completes.

```bash
mr_iid="<id>"
reviewed_sha="<sha-you-reviewed>"
glab mr merge "$mr_iid" --auto-merge --yes --sha "$reviewed_sha" --remove-source-branch
```

### Snippet: approval-confirmation

Use after `sha-bound-approval` when approval status must be verified through the approvals endpoint. `approved_by` in MR JSON can lag.

```bash
mr_iid="<id>"
project_path="<group%2Fproject>"
glab api "projects/${project_path}/merge_requests/${mr_iid}/approvals"
```

### Snippet: finish-mr-authority-aware

Role eligibility (who may call) lives in [`skill://gitlab/reference/ci-finish-guards.md`](skill://gitlab/reference/ci-finish-guards.md#finish-specialization-finish-mr-authority-aware), authority claim/source semantics live in [`skill://gitlab/reference/authority-verification.md`](skill://gitlab/reference/authority-verification.md), and the shared mutation sequence lives in [`skill://gitlab/reference/mutation-guard.md`](skill://gitlab/reference/mutation-guard.md).

Inputs:

- `mr_iid`: merge request IID.
- `reviewed_sha`: SHA approved by the reviewer and guarded with `--sha`.
- `merge_authority`: `approval-only`, `reviewer may merge`, `queue auto-merge`, or `human release`. Resolve project-default policy text to one of those accepted helper authorities before invoking the helper.
- `caller_role`: `builder`, `reviewer`, `authorized-parent`, or `human`.
- `source_branch`, `default_branch`, and optional `worktree_path`.
- Optional `issue_iid` when it is not obvious from `Closes #...`.

Finish is a SHA-bound Mutation Guard specialization: the guard order lives in [`skill://gitlab/reference/mutation-guard.md`](skill://gitlab/reference/mutation-guard.md), authority claim/source precedence and no-self routing live in [`skill://gitlab/reference/authority-verification.md`](skill://gitlab/reference/authority-verification.md), while finish-specific field mapping, exact-SHA CI handling, `via=mcp` / `via=glab-fallback` result evidence, post-action fetch/cleanup sequencing, `closure_pending` issue reporting, and the canonical merge/authority matrix pointer live in [`skill://gitlab/reference/ci-finish-guards.md`](skill://gitlab/reference/ci-finish-guards.md#finish-specialization-finish-mr-authority-aware).

Implementation body lives inside this skill:

- Source: [`skill://gitlab/scripts/gitlab-finish-mr.sh`](skill://gitlab/scripts/gitlab-finish-mr.sh)
- Helper docs: [`skill://gitlab/scripts/README.md`](skill://gitlab/scripts/README.md#gitlab-workflow-helpers)
- Regression tests: [`tests/gitlab-workflow-helpers.sh`](../tests/gitlab-workflow-helpers.sh)

Use the helper only when the exact accepted fallback/helper authority model fits. In agent-run shell commands, use the full script URI — bare first-word, quoted direct, or variable-assigned forms all resolve in **foreground** Bash calls (see [skill:// URI invocation matrix](#skill-uri-invocation-matrix) below). Do **not** assign `skill://gitlab` (the bare skill root) to a variable — it resolves to `SKILL.md`. `skill://` URIs are **not** resolved in `run_in_background` invocations — resolve the helper to its absolute path (use the variable-assigned form) before launching in the background.

```bash
gitlab_finish_mr_script="skill://gitlab/scripts/gitlab-finish-mr.sh"
"$gitlab_finish_mr_script" \
  --mr-iid "$mr_iid" \
  --reviewed-sha "$reviewed_sha" \
  --merge-authority "$merge_authority" \
  --caller-role "$caller_role" \
  --source-branch "$source_branch" \
  --default-branch "$default_branch" \
  --format human
```

Add `--issue-iid`, `--worktree-path`, `--approve-as-reviewer`, or source-branch cleanup flags only when the workflow and authority explicitly allow them.

For raw-command adaptation, keep the Mutation Guard order from [`skill://gitlab/reference/mutation-guard.md`](skill://gitlab/reference/mutation-guard.md) plus the finish field mapping in [`skill://gitlab/reference/ci-finish-guards.md`](skill://gitlab/reference/ci-finish-guards.md#finish-specialization-finish-mr-authority-aware).

## Optional helper scripts

This skill also ships optional fallback/helper wrappers in `scripts/` for accepted helper behaviors. Use them when the exact behavior fits and repeatable guardrails help; prefer MCP primary tools for normal GitLab API actions, and use raw fallback snippets only for documented gaps, project-specific policy or human waiver, step-by-step troubleshooting, or changes to accepted workflow behavior.

## skill:// URI invocation matrix

The OMP harness pre-processes `skill://` URIs in Bash command text **before** the shell receives it, but only in **foreground** Bash tool calls. Verified foreground behavior on OMP/darwin (2026-06-12, using real full script URIs):

| Form | Example | Foreground result | Notes |
|---|---|---|---|
| Bare first-word | `skill://gitlab/scripts/gitlab-wrappers.sh cmd` | **Works** — URI resolved to absolute path | Full script URI must be used; a bare skill root (`skill://gitlab`) or placeholder resolves differently |
| Quoted direct | `"skill://gitlab/scripts/gitlab-wrappers.sh" cmd` | **Works** — URI resolved to absolute path | Equivalent to bare first-word; quotes have no effect on harness expansion |
| Variable-assigned | `s="skill://gitlab/scripts/gitlab-wrappers.sh"; "$s" cmd` | **Works** — URI resolved to absolute path at assignment | Variable holds the expanded absolute path; **recommended** for multi-line invocations and background-safe handoff |
| In `run_in_background` | any form | **Not resolved** — harness URI pre-processor is not active | Resolve to absolute path in foreground first (variable-assigned form), then pass the variable |

**Recommended practice:**
- Use the **variable-assigned** form for multi-line helper invocations: the variable holds the resolved absolute path and is safe to pass to background launchers without re-resolution.
- All three foreground forms are equivalent for single-line calls; variable-assigned is preferred for clarity and background safety.
- **Never** assign `skill://gitlab` (the bare skill root without a file path) to a variable — it resolves to `SKILL.md`, not the `scripts/` directory.
- To launch a helper in the background: resolve first in foreground (variable-assigned form), then pass the variable.

Example — resolve then background:

```bash
# Resolve in foreground (harness expands the URI at assignment)
gitlab_ci_watch_script="skill://gitlab/scripts/gitlab-ci-watch.sh"
# $gitlab_ci_watch_script is now an absolute path; safe to pass to a background launcher
run_in_background "$gitlab_ci_watch_script" --mr-iid "$mr_iid" ...
```

## Troubleshooting

Repo wrong: inspect branch remote, `git remote -v`, and fallback `glab repo view "$repo_url"`; decision-grade project identity still comes from MCP `get_project` when available. JSON shape wrong: inspect keys and adapt projection only. Flag fails: rerun exact `glab <area> <verb> --help` and remove unsupported flag.
