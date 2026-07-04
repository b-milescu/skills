---
name: gitlab
description: >-
  MCP-first GitLab transport reference for local/self-hosted GitLab: gitlab-mcp
  first, guarded help-first glab fallback. Use when GitLab-backed workflows need
  issue/MR/CI reads, issue/MR mutations, Mutation Guard rules, safe multiline
  text handling, or glab fallback syntax.
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
- **Bounded fallback.** When repeated guard re-read returns a full body and the body itself is the context-pressure problem — documented gap "repeated SHA/state guard re-reads where the MCP read returns full bodies" — use the `safe-mr-json` snippet backed by `get_merge_request_workflow_snapshot` to project exactly decision-grade fields. As always, fallback stays second to MCP and re-checks SHA/CI/authority/identity/project binding per transport order above; never weaken any guard.
- **Elided-body fallback for first full reads — bounded MCP re-read first.** When the first `get_merge_request` read returns an elided description body — a compressed or placeholder token such as `<<ccr:...>>` instead of the full text — the "first read stays full" rule is not satisfied; the description was not actually received. Elision is context-pressure-driven (the same full read can come back un-elided early in a session and elided deep in a parallel batch), so reach first for a **bounded MCP re-read** of only the slice you need before any `glab` detour, using the server-side bounded params shipped in [`agents/gitlab-mcp#89`](https://gitlab.example.com/agents/gitlab-mcp/-/issues/89):
- When only `Closes #N` auto-close trailer is needed, re-read with `get_merge_request` `description_grep:"Closes"`. When Reviewer Lift rows are needed, re-read with `description_grep:"REVIEWER-LIFT-SCHEMA"` or cap the body with `description_max_bytes`.
- Only if a bounded MCP re-read still elides or fails — or the whole unbounded body is genuinely required and its first bounded slice also elides (do not page remaining slices; sequential whole-body paging elides at nearly the same rate) — use the `safe-mr-json` snippet as a last-resort guarded fallback to retrieve the actual description content. This is the documented gap "elided MCP body on first full description read"; fallback does not alter transport order, slim guard-read semantics, or the safety-floor litany.

## Elided-body fallback for issue notes and issue descriptions

`get_issue_note` (and `get_issue`) can return an elided `<<ccr:…>>` token instead of the actual note or description body when the content is large. This is the same class of MCP context-compression gap as the MR elided-body case above, tracked in [`agents/gitlab-mcp#87`](https://gitlab.example.com/agents/gitlab-mcp/-/issues/87). When elision is observed, the MCP-first read did not deliver the actual content. Because elision is context-pressure-driven, reach first for a **bounded MCP re-read** of only the slice you need: `get_issue` accepts the server-side bounded params shipped in [`agents/gitlab-mcp#89`](https://gitlab.example.com/agents/gitlab-mcp/-/issues/89), so re-read with `description_grep:"Closes"` for the auto-close trailer, or `description_grep` on a known section marker for other targeted fields (a `descriptionTruncated:true` flag signals the slice was bounded). For **whole-body recovery**, make one bounded attempt (`description_max_bytes`); if that attempt also elides, go directly to the guarded `glab api` last-resort — do not page remaining slices, as sequential whole-body paging elides at nearly the same rate as the full read. Only when a grep-targeted bounded re-read still elides or fails — or for a note body where MCP exposes no bounded param — use the raw `glab api` detour, documented below as a **last-resort** fallback. (A dedicated description-read tool is the optional follow-up tracked in [`agents/gitlab-mcp#92`](https://gitlab.example.com/agents/gitlab-mcp/-/issues/92).)

**Last-resort `glab api` fallback (issue note body)** — only after a bounded MCP re-read still elides or fails, or for a note body where MCP exposes no bounded param:

```bash

# Verify the --help flag before use: glab api --help

glab api "projects/:id/issues/:iid/notes/:note_id" | jq -r '.body'

```

**Last-resort `glab api` fallback (issue description body)** — only after a bounded MCP re-read with `description_grep` / `description_max_bytes` still elides or fails:

```bash

# Verify the --help flag before use: glab api --help

glab api "projects/:id/issues/:iid" | jq -r '.description'

```

Replace `:id` with the URL-encoded project path (e.g. `agents%2Fskills`) or numeric project ID, `:iid` with the project-scoped issue number, and `:note_id` with the global note ID. These fallbacks follow the standard guarded transport order (MCP first — including the bounded MCP re-read — then `glab api` fallback last-resort, help-first flag verification); the bounded MCP re-read is subject to the same guard re-checks, and neither path alters transport order, the safety-floor litany, or any mutation guard.

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
- Use file-backed long descriptions/messages through documented wrappers; they validate text files for NUL/control-character corruption by delegating to `validate_gitlab_text` before `glab`, never print bodies, and never receive secrets.

## Safe multiline GitLab text

Validate every MR/issue body before mutation. MCP-native flows use `validate_gitlab_text` directly or a safe mutation tool that embeds it (`safe_update_merge_request_description`, `safe_create_merge_request_note`, `safe_create_issue_note`). The byte rule is invariant: reject NUL, non-whitespace C0 controls, and DEL; allow tab, newline, and carriage return; diagnostics name the body role and offending byte offset only, never the body or secrets.

Use temp/run-dir files plus quoted heredocs when drafting long Review Packets or Review Reports locally; then pass the resulting string/body to the MCP safe tool. File-backed `glab` fallback is allowed only under snippet fallback conditions and must enforce the same byte rule before submission. Detailed patterns: [`skill://gitlab/reference/safe-text.md`](skill://gitlab/reference/safe-text.md) and [`skill://gitlab/reference/multiline-text.md`](skill://gitlab/reference/multiline-text.md#safe-multiline-gitlab-text).

## GitLab Mutation Guard

Every GitLab mutation uses the ordered **GitLab Mutation Guard** seam in [`skill://gitlab/reference/mutation-guard.md`](skill://gitlab/reference/mutation-guard.md) (`skill://gitlab/reference/mutation-guard.md`) and its machine schema at `skill://gitlab/reference/mutation-guard.schema.json`: project binding, current target re-read, reviewed SHA when relevant, exact-SHA CI when relevant, Authority Verification, caller identity/context, Safe GitLab Text when relevant, fallback eligibility, one mutation, and post-mutation MCP re-read with `via=mcp` / `via=glab-fallback` / `via=n/a` evidence. Fallback is never a bypass for stale head, red/missing/stale CI, missing authority, permission uncertainty, self-finish risk, or content-byte failure.

## Canonical snippets

Names below are stable API for workflow skills. The machine-actionable source of truth for snippet names, MCP primary tools, inputs, outputs, allowed mutations, guards, fallback conditions, post-mutation re-reads, and via evidence is `skill://gitlab/reference/snippet-metadata.json`; the human-readable table lives in [`skill://gitlab/reference/snippet-transports.md`](skill://gitlab/reference/snippet-transports.md) and is checked against that metadata. Inline shell blocks below are guarded `glab` fallback/helper examples, not the primary transport. Long helper bodies live in `scripts/` with tests; this skill keeps contracts, safety rules, and pointers authoritative.

Build-focused cards for `/start-build` live in [`skill://gitlab/reference/build-read.md`](skill://gitlab/reference/build-read.md) and [`skill://gitlab/reference/build-actions.md`](skill://gitlab/reference/build-actions.md). Review-focused cards for `/start-review` live in [`skill://gitlab/reference/review-read.md`](skill://gitlab/reference/review-read.md), [`skill://gitlab/reference/review-actions.md`](skill://gitlab/reference/review-actions.md), and [`skill://gitlab/reference/ci.md`](skill://gitlab/reference/ci.md). The cards are pointer maps for snippet names, inputs/outputs, fail-closed rules, and fallback conditions; this `SKILL.md` remains the full owner for transport order, fallback help-first discipline, and flag drift.

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

Open the early Draft MR only after the source branch exists remotely. MCP primary: validate the Review Packet with `validate_gitlab_text`, then call `create_merge_request(draft=true, source_branch, target_branch, title, description)` and re-read with `get_merge_request`. The description must include plain `Closes #<iid>`.

```text

validate_gitlab_text(role="merge request description", body=review_packet)
create_merge_request(project_path, source_branch, target_branch, title, description=review_packet, draft=true)
get_merge_request(project_path, mr_iid) -> verify draft=true, source/target/head/description

```

### Snippet: mr-description-update

Refresh the MR description / Reviewer Lift without changing draft/ready state. MCP primary: `safe_update_merge_request_description` validates content bytes, updates the bound MR description, and requires a post-update `get_merge_request` read. Do not combine with ready-marking.

```text

safe_update_merge_request_description(project_path, mr_iid, description=review_packet)
get_merge_request(project_path, mr_iid) -> verify description, draft state unchanged, head SHA still expected/reviewed SHA when one is in force

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
- `source_branch`: MR source branch, used only for fallback/progress context.
- `reviewed_sha`: SHA from the review report or Reviewer Lift.
- `timeout_seconds` and `poll_seconds`: caller-selected wait budget.
- Optional output mode: human summary or machine-readable YAML.

MCP primary: poll `get_merge_request_workflow_snapshot` and exact-SHA `list_pipelines(sha=reviewed_sha)` / `get_pipeline`. Every poll fails closed if MR head differs from `reviewed_sha`, if pipeline SHA is stale, or if reviewed-SHA pipeline is failed/canceled/skipped/missing past timeout. Record `via=mcp`; guarded `glab` fallback is only for unavailable MCP snapshot/pipeline reads and must preserve the same exact-SHA rules.

```text

get_merge_request_workflow_snapshot(project_path, mr_iid)
list_pipelines(project_path, sha=reviewed_sha) or get_pipeline(project_path, pipeline_id)
verdict -> success / pending / failed / canceled / stale-head / stale-ci / timeout

```

For raw-command fallback adaptation (keeping per-poll SHA rules as read-only evidence for the Mutation Guard), see [`skill://gitlab/reference/ci-finish-guards.md`](skill://gitlab/reference/ci-finish-guards.md#ci-verdict-mechanics-ci-watch-sha-pinned) and [`skill://gitlab/reference/mutation-guard.md`](skill://gitlab/reference/mutation-guard.md).

### Snippet: mr-note-create

Post MR comments only. MCP primary: `safe_create_merge_request_note` validates body bytes, posts one top-level plain non-resolvable MR note on the bound MR, then MR notes/discussions are re-read. Use this for Review Reports and status comments; never use issue-note tools for Review Reports.

```text

safe_create_merge_request_note(project_path, mr_iid, body=report_body, resolvable=false)
merge_request_notes_or_discussions(project_path, mr_iid) -> verify created note exists; for Review Reports, body matches source without printing body

```

### Snippet: issue-note-create

Post issue comments only. MCP primary: `safe_create_issue_note` validates body bytes, posts one issue note on the bound issue, then issue notes are re-read. Do not use this for Review Reports or MR action reports.

```text

safe_create_issue_note(project_path, issue_iid, body=comment_body)
issue_notes(project_path, issue_iid) -> verify created note exists without printing body

```

### Snippet: label-reconcile

Use MCP `update_issue` label add/remove semantics, then `get_issue`. Compute add/remove sets first; reject add/remove overlap and final state/category label conflicts before mutation.

```text

update_issue(project_path, issue_iid, add_labels, remove_labels)
get_issue(project_path, issue_iid) -> verify final labels match requested reconcile result

```

### Snippet: safe-mr-json

Stable snippet name for guard-grade MR workflow metadata. MCP primary is `get_merge_request_workflow_snapshot` plus project binding; consume only decision-grade fields needed for SHA/state/CI/merge guards, with no list-only data. Fail closed on project binding, SHA, pipeline, merge-status, branch, JSON/control-character drift. Guarded `glab mr view` projection fallback is only for MCP snapshot unavailability or bounded repeated SHA/state guard reads where MCP returns full bodies.

```text

get_merge_request_workflow_snapshot(project_path, mr_iid)
get_project(project_path) -> verify binding

```

### Snippet: auto-merge-api-fallback

Stable snippet name for the known auto-merge queue fallback boundary. Authorized non-builders should prefer `finish_merge_request(action="queue-auto-merge", sha=reviewed_sha)` or MCP `merge_merge_request(auto_merge=true, sha=reviewed_sha, should_remove_source_branch=true)`. Use guarded `glab mr merge --auto-merge --sha --remove-source-branch` fallback only for the documented MCP/CLI 405 gap after all SHA/CI/authority/caller/context guards pass.

```text

finish_merge_request(project_path, mr_iid, reviewed_sha, action="queue-auto-merge", source_branch, target_branch, authority_source, caller_role)
get_merge_request(project_path, mr_iid) -> verify queue state and record via=mcp or via=glab-fallback

```

### Snippet: sha-guard

MCP primary is `get_merge_request`; read only its top-level `sha`. The fallback below is shown for the MCP-unavailable case. For *repeated* SHA/state guards on the same MR, follow the [slim guard-read path](#slim-guard-read-for-repeated-shastate-guards): keep the first per-MR read full, then consume only `sha` / `draft` / `state` / `detailedMergeStatus` on each subsequent re-read instead of re-fetching the full description.

```bash

reviewed_sha="<sha-you-reviewed>"
current_sha="$(glab mr view <id> -F json | jq -r '.sha')"
[ "$current_sha" = "$reviewed_sha" ] || { echo "MR head changed: current=$current_sha reviewed=$reviewed_sha" >&2; exit 1; }

```

Approval, direct merge, auto-merge queueing, and approval confirmation are separate actions. Choose exactly one action snippet for the authority you have. Never run a combined approval/merge block or paste multiple action snippets as one executable sequence. Before any approval/merge action or fallback, run the [GitLab Mutation Guard](#gitlab-mutation-guard) above (canonical owner: [`skill://gitlab/reference/mutation-guard.md`](skill://gitlab/reference/mutation-guard.md)); it stops on stale head, red/missing/stale CI, missing authority, permission uncertainty, identity drift, same-session/self-finish risk, or fallback-ineligible states.

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
- `reviewed_sha`: SHA approved by the reviewer and guarded with exact-SHA reads.
- `merge_authority`: `approval-only`, `reviewer may merge`, `queue auto-merge`, or `human release`.
- `caller_role`: `builder`, `reviewer`, `authorized-parent`, or `human`.
- `source_branch`, `default_branch`, and optional `worktree_path`.
- Optional `issue_iid` when not obvious from `Closes #...`.

MCP primary: `finish_merge_request` performs the authority-aware finish contract after fresh `get_merge_request`, exact-SHA pipeline read, caller identity, and authority validation. It returns a `finish_result` / handoff with action, blocker, SHA, CI, issue, cleanup, identity, and `via`. Builder role always stops at handoff. Stop on stale head, stale/red/missing CI, missing authority/source, identity drift, same-session review/finish, unsupported action, or dirty worktree cleanup. Raw `glab` fallback is allowed only under snippet-specific documented MCP gaps after MCP re-read and all guards pass.

```text

finish_merge_request(project_path, mr_iid, reviewed_sha, merge_authority, authority_source, caller_role, source_branch, default_branch, issue_iid?)
get_merge_request(project_path, mr_iid) -> after any mutation, verify state/issue/branch cleanup and record via

```

## Optional helper scripts

The `gitlab/scripts/` files remain as historical/optional fallback artifacts and regression fixtures. Active workflow snippets above do not instruct agents to invoke script URIs; use MCP-native tools first and guarded help-first `glab` fallback only where the snippet transport contract allows it.

## Troubleshooting

Repo wrong: inspect branch remote, `git remote -v`, and fallback `glab repo view "$repo_url"`; decision-grade project identity still comes from MCP `get_project` when available. JSON shape wrong: inspect keys and adapt projection only. Flag fails: rerun exact `glab <area> <verb> --help` and remove unsupported flag.
