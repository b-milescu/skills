---
name: gitlab
description: >-
  MCP-first GitLab transport reference for local/self-hosted GitLab: gitlab-mcp
  first, guarded help-first glab fallback. Use when GitLab-backed workflows need
  issue/MR/CI reads, issue/MR mutations, Mutation Guard rules, safe multiline
  text handling, or glab fallback syntax.
---

# GitLab transport reference

Use from the GitLab-backed worktree, in this order:

1. **MCP first.** Use the tools in [`snippet-metadata.json`](skill://gitlab/reference/snippet-metadata.json) and [`snippet-transports.md`](skill://gitlab/reference/snippet-transports.md).
2. **Guarded `glab` fallback second.** Only for a named fallback/helper/troubleshooting condition, after applicable binding, SHA, CI, authority, and identity checks.
3. **Local `git` remains local.** Keep worktree, branch, fetch, and ref checks in `git`.

Known MCP gaps are owned by
[`snippet-transports.md` §Known MCP gaps fallback limits](skill://gitlab/reference/snippet-transports.md#known-mcp-gaps-fallback-limits).
Bounded metadata/body-read rules live in
[`bounded-reads.md`](skill://gitlab/reference/bounded-reads.md).

## Guarded glab fallback and help-first rule

Before any flagged fallback `glab` command, run exact command help and verify every flag with `glab <area> <verb> --help`.

Do not invent flags from memory or other CLIs. If help conflicts with this skill, use help and note skill drift.

Project hooks may specialize policy but not exact-candidate Gate Receipt, reviewed-SHA binding, explicit authority, independent review, role boundaries, MCP-first transport correctness plus help-first `glab` fallback correctness, or live help verification. CI is advisory evidence whose status is attributed only with exact-SHA binding. Shared delivery blocks retain GitLab terms: `issue`, `MR`, `pipeline`, `source branch`, `target branch`, and `SHA`.

### Per-run help cache

Help-first remains mandatory for fallback `glab`. The run-dir help cache — kept in a temp/run artifact directory and never committed — records the exact `glab <command> --help` output with verification status for this run and context. Refresh the cache whenever the command, `glab` version, or repo context changes.

Detailed cache contract, context invalidation rules, and the executable helper pattern live in [skill://gitlab/reference/help-first.md](skill://gitlab/reference/help-first.md#per-run-help-cache).

## Important fallback/local pitfalls

- Issue `labels` are strings: use `.labels`, not `.labels[].name`.
- `glab ci status --mr` is unreliable; prefer MCP `get_merge_request`/`list_pipelines` exact-SHA reads, or fallback branch CI / MR `.pipeline` only as contract allows.
- `glab mr list -F json` is candidate data; use MCP `get_merge_request` or fallback `glab mr view <id> -F json` for decision-grade SHA/pipeline/mergeability.
- Use `-R "$repo_url"` when fallback repo/host inference might be wrong.
- Use file-backed long descriptions/messages; [`safe-text.md`](skill://gitlab/reference/safe-text.md) owns the caller steps and the never-print-bodies rule.

## Safe multiline GitLab text

Validate every MR/issue body before mutation with `validate_gitlab_text` or a safe mutation tool that embeds it. [`safe-text.md`](skill://gitlab/reference/safe-text.md) owns the byte rule and the role/offset-only diagnostics.

Draft long text in temp/run-dir files with quoted heredocs; [`multiline-text.md`](skill://gitlab/reference/multiline-text.md#safe-multiline-gitlab-text) owns the file-backed pattern and its fallback conditions.

GitLab strips exactly one trailing newline from a published note or description body. Compute expected digests and byte counts over that stripped form. A one-byte difference of exactly that shape is GitLab's normalisation — never a failed write and never a reason to create a second note. This does not weaken authored-source readback equality in [`safe-text.md`](skill://gitlab/reference/safe-text.md).

## Issue publication

Use `create_issue` with required native arguments `project`,
`expected_project_id`, `expected_user_id`, and `title`, plus the intended
publication fields. The bound MCP connection owns the API destination.

Before publication, compare a fresh successful `get_project` response's
canonical project/clone metadata with the independently intended repository
from preflight. Bind `expected_project_id` to that verified project and
`expected_user_id` through a fresh authenticated `get_current_user` read.
Missing/conflicting repository evidence, a wrong repository, or identity drift
blocks publication. Instance-local project/user IDs alone are not cross-instance
identity proof. Use exact existing label names and preserve every submitted
field, including authored Markdown.

If the mounted `create_issue` schema still requires `expected_api_url`, stop
before POST with a server/client contract-version blocker; resume only with the
URL-free schema.

The native tool validates bindings/text, POSTs once, and compares submitted
intent against raw GET. Classify its body-free receipt before continuing:

| Outcome | Caller response |
|---|---|
| `verified_created` | Record the verified IID/locator and submitted-field evidence. |
| `not_created` | No creation established; report the failure and resolve its prerequisite before any separately authorized new attempt. |
| `creation_unknown` | Do not repeat POST. Reconcile with bounded native reads; ambiguous or absent matches require a human decision. |
| `created_unverified` | Preserve the known IID; recover with GET-only reads and compare every submitted field, recovering authored body losslessly. |

Never automatically repeat creation, including after timeout or failed
readback. A known IID always takes GET-only recovery; without one, use bounded
reconciliation, not a guessed IID. Later label reconciliation is a separately
authorized mutation, never silent repair of failed publication. Other actions
retain their own verified recovery contracts.

## Three issue-closure oracles

Keep three distinct oracles:

- `validate_closes_keyword` answers whether authored syntax closes the target; it cannot prove nothing else closes.
- `closes_issues` previews unintended closures but may include code-spanned pairs GitLab will not act on. Keyword/reference non-adjacency satisfies both checks.
- Post-merge issue state is authoritative. Verification is read-only: report `issue_closure_pending` rather than force-closing an open target.

## GitLab Mutation Guard

Every GitLab mutation uses the ordered **GitLab Mutation Guard** in [`mutation-guard.md`](skill://gitlab/reference/mutation-guard.md) and its machine schema at `skill://gitlab/reference/mutation-guard.schema.json`.

## Canonical snippets

Snippet names and contracts are stable API. [`snippet-metadata.json`](skill://gitlab/reference/snippet-metadata.json) is the machine source of truth; [`snippet-transports.md`](skill://gitlab/reference/snippet-transports.md) is its synchronized table. This skill owns transport order, help-first fallback, flag drift, and examples.

### Snippet: local-repo-preflight

Use the canonical `local-repo-preflight` entry in
[`snippet-metadata.json`](skill://gitlab/reference/snippet-metadata.json) and
its synchronized row in
[`snippet-transports.md`](skill://gitlab/reference/snippet-transports.md).
`get_project` is the MCP primary for project/default-branch binding; local `git`
owns cwd, remote URL, branch, and ref checks. A help-first
`glab repo view` is fallback/troubleshooting only. Stop on non-git cwd, project
mismatch, missing default branch, stale or missing local default ref, or
authentication failure.

### Snippet: issue-pickup

MCP primary: `list_issues` for candidates; `get_issue(include_description:false)`
for every state, label, or assignment check; `get_issue` or `get_merge_request`
with `description_grep` when only the Closes trailer or Reviewer Lift is needed.
Full-body `get_issue` stays when the flow consumes the whole description.

```text

get_issue(project_path, issue_iid, include_description:false) -> state, labels, assignees
get_issue(project_path, issue_iid, description_grep="Closes") or description_grep="Reviewer Lift"

```

Guarded `glab` fallback:

```bash

ready_label="<live label mapped to the AFK-ready Triage Role in project_profile.label_profile_ref>"
glab issue list --label "$ready_label" -O json --per-page 50 | jq '.[] | {iid,title,labels,assignees,web_url}'
glab issue view <id> --comments
glab issue view <id> -F json | jq '{iid,title,state,labels,assignees,web_url}'

```

For issue comments use **Snippet: issue-note-create**; for label maintenance use **Snippet: label-reconcile**.

### Snippet: draft-mr-create

Open the early Draft MR only after the source branch exists remotely. MCP primary: validate the Review Packet with `validate_gitlab_text`, then call `create_merge_request(draft=true, source_branch, target_branch, title, description)`. The description must include plain `Closes #<iid>`.

```text

validate_gitlab_text(role="review_packet", content=review_packet)
create_merge_request(project_path, source_branch, target_branch, title, description=review_packet, draft=true)
get_merge_request(project_path, mr_iid, include_description:false) -> verify draft=true, source/target/head
get_merge_request_description(project_path, mr_iid, description_max_bytes, description_offset_bytes) -> recover and verify review_packet byte-for-byte
```

### Snippet: mr-description-update

Refresh the MR description / Reviewer Lift without changing draft/ready state. MCP primary: `safe_update_merge_request_description` validates content bytes and updates the bound MR description. Do not combine with ready-marking.

```text

safe_update_merge_request_description(project_path, mr_iid, description=review_packet)
get_merge_request(project_path, mr_iid, include_description:false) -> verify draft state unchanged and head SHA still expected/reviewed SHA when one is in force
get_merge_request_description(project_path, mr_iid, description_max_bytes, description_offset_bytes) -> recover and verify review_packet byte-for-byte

```

### Snippet: draft-mr-mark-ready

Use only after the local gate has passed (or N/A is documented) and the MR description and Reviewer Lift name the current head SHA.

```text

mark_merge_request_ready(project_path, mr_iid, expected_sha)
get_merge_request(project_path, mr_iid, include_description:false) -> verify draft=false and head SHA still equals reviewed SHA
get_merge_request_description(project_path, mr_iid, description_max_bytes, description_offset_bytes) -> recover and verify the existing description byte-for-byte

```

### Snippet: mr-pickup

```bash

glab mr view
glab mr list --not-draft -F json --per-page 50
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

Role eligibility (who may call) lives in [`skill://gitlab/reference/ci-finish-guards.md`](skill://gitlab/reference/ci-finish-guards.md#advisory-ci-observation-ci-watch-sha-pinned); inputs and outputs live in the [snippet transport table](skill://gitlab/reference/snippet-transports.md).

MCP primary: poll `get_merge_request_workflow_snapshot` and exact-SHA
`list_pipelines(sha=reviewed_sha)` / `get_pipeline`. A changed MR head stops
attribution to `reviewed_sha`; every pipeline state is advisory progress
evidence. Record `via=mcp`; guarded `glab` fallback is only for unavailable
MCP reads.

```text

get_merge_request_workflow_snapshot(project_path, mr_iid)
list_pipelines(project_path, sha=reviewed_sha) or get_pipeline(project_path, pipeline_id)
observation -> bound-success / bound-pending / bound-failure / unavailable / unbound

```

### Snippet: mr-note-create

Post MR comments only. MCP primary: `safe_create_merge_request_note` validates body bytes, posts one top-level plain non-resolvable MR note on the bound MR, then MR notes/discussions are re-read. Use this for Review Reports and status comments; never use issue-note tools for Review Reports.

```text

safe_create_merge_request_note(project=project_path, merge_request_iid=mr_iid, body=report_body)
merge_request_notes_or_discussions(project_path, mr_iid) -> verify created note exists; for Review Reports, body matches source without printing body

```

Verify source equality from exact-note content or lossless bounded recovery: the
canonical-body digest and `verify_merge_request_note_digest` prove stored-body
equality, not equality to the authored report.

### Snippet: issue-note-create

Post issue comments only. MCP primary: `safe_create_issue_note` validates body bytes, posts one issue note on the bound issue, then issue notes are re-read. Do not use this for Review Reports or MR action reports.

```text

safe_create_issue_note(project_path, issue_iid, body=comment_body)
issue_notes(project_path, issue_iid) -> verify created note exists without printing body

```

### Snippet: label-reconcile

Use MCP `update_issue` label add/remove semantics, then `get_issue(include_description:false)`. Compute add/remove sets first; reject add/remove overlap and final state/category label conflicts before mutation.

```text

update_issue(project_path, issue_iid, add_labels, remove_labels)
get_issue(project_path, issue_iid, include_description:false) -> verify final labels match requested reconcile result

```

### Snippet: safe-mr-json

Stable snippet name for guard-grade MR workflow metadata. MCP primary is `get_merge_request_workflow_snapshot` plus project binding; consume only decision-grade fields needed for SHA/state/CI/merge guards, with no list-only data. Fail closed on project binding, SHA, pipeline, merge-status, branch, JSON/control-character drift. Guarded `glab mr view` projection fallback is only for MCP snapshot unavailability.

```text

get_merge_request_workflow_snapshot(project_path, mr_iid)
get_project(project_path) -> verify binding

```

### Snippet: auto-merge-api-fallback

Stable snippet name for the known auto-merge queue fallback boundary. Authorized non-builders should prefer the native finish call below, or lower-level `merge_merge_request(auto_merge=true, sha=reviewed_sha, should_remove_source_branch=true, confirm=true)`. Use guarded `glab mr merge --auto-merge --sha --remove-source-branch` fallback only for the documented MCP/CLI 405 gap after the [GitLab Mutation Guard](#gitlab-mutation-guard) passes.

```text

finish_merge_request(project=project_path, merge_request_iid=mr_iid, reviewed_sha=reviewed_sha, action="queue-auto-merge", source_branch=source_branch, target_branch=target_branch, caller_role=caller_role, authority="queue auto-merge", authority_source=authority_source, should_remove_source_branch=true)
get_merge_request(project_path, mr_iid) -> verify queue state and record via=mcp or via=glab-fallback

```

### Snippet: sha-guard

MCP primary is `get_merge_request_workflow_snapshot`; compare its top-level `sha` with `reviewed_sha`. The fallback below is only for MCP-unavailable metadata reads and still requires explicit project binding plus help-first verification.

```bash

reviewed_sha="<sha-you-reviewed>"
current_sha="$(glab mr view <id> -F json | jq -r '.sha')"
[ "$current_sha" = "$reviewed_sha" ] || { echo "MR head changed: current=$current_sha reviewed=$reviewed_sha" >&2; exit 1; }

```

Approval, direct merge, auto-merge queueing, and approval confirmation are separate actions. Choose exactly one action snippet for the authority you have. Never run a combined approval/merge block or paste multiple action snippets as one executable sequence. Before any approval/merge action or fallback, run the [GitLab Mutation Guard](#gitlab-mutation-guard) above (canonical owner: [`skill://gitlab/reference/mutation-guard.md`](skill://gitlab/reference/mutation-guard.md)); it stops on stale head, missing/stale Gate Receipt, missing authority, permission uncertainty, identity drift, same-session/self-finish risk, or fallback-ineligible states. CI status is advisory.

### Snippet: sha-bound-approval

Use only when the reviewed SHA is current, approval authority permits reviewer approval, and no explicit approval restriction applies. For `approval-only` merge authority, this is the only approval/finish action.

```bash

mr_iid="<id>"
reviewed_sha="<sha-you-reviewed>"
glab mr approve "$mr_iid" --sha "$reviewed_sha"

```

### Snippet: sha-bound-merge

Use only when the [GitLab Mutation Guard](#gitlab-mutation-guard) passes and explicit authority permits direct merge.

```bash

mr_iid="<id>"
reviewed_sha="<sha-you-reviewed>"
glab mr merge "$mr_iid" --yes --sha "$reviewed_sha" --auto-merge=false

```

### Snippet: sha-bound-auto-merge-queue

Use only when the [GitLab Mutation Guard](#gitlab-mutation-guard) passes, project policy permits protected auto-merge, and explicit authority permits queueing auto-merge. Request source-branch removal on merge with `--remove-source-branch` (MCP primary: `should_remove_source_branch=true`), matching the primary finish path so the remote source branch is gone once the queued merge completes.

```bash

mr_iid="<id>"
reviewed_sha="<sha-you-reviewed>"
glab mr merge "$mr_iid" --auto-merge --yes --sha "$reviewed_sha" --remove-source-branch

```

### Snippet: approval-confirmation

Use after `sha-bound-approval` when approval status must be verified through the approvals endpoint. `approved_by` in MR JSON can lag.

MCP primary: `get_merge_request_approvals(project=project_path, merge_request_iid=mr_iid)`,
plus a fresh MR head/caller binding. An approval record is not independent
exact-SHA review evidence. A tier-unavailable `not_available` response leaves
approval unverified and fails closed; use the help-first read below only for an
eligible unavailable MCP transport.

```bash

mr_iid="<id>"
project_path="<group%2Fproject>"
glab api "projects/${project_path}/merge_requests/${mr_iid}/approvals"

```

### Snippet: finish-mr-authority-aware

Role eligibility (who may call) lives in [`skill://gitlab/reference/ci-finish-guards.md`](skill://gitlab/reference/ci-finish-guards.md#finish-specialization-finish-mr-authority-aware), authority claim/source semantics live in [`skill://gitlab/reference/authority-verification.md`](skill://gitlab/reference/authority-verification.md), and the shared mutation sequence lives in [`skill://gitlab/reference/mutation-guard.md`](skill://gitlab/reference/mutation-guard.md).

Workflow inputs include the exact-candidate Gate Receipt, independent review,
authority provenance, caller identity/context, default branch, and optional
issue/worktree. These are caller evidence, not additional native arguments.
Use the actual MR `target_branch`, even when it differs from the default.
Native inputs are shown below; `should_remove_source_branch` is optional.
`action` is exactly `approval-only`, `direct-merge`, or `queue-auto-merge`.
`authority="human release"` is a no-mutation human handoff, not a fourth action.
Unlike lower-level approve/merge tools (which retain `sha` and `confirm=true`),
finish takes `reviewed_sha` and no `confirm`.

```text

finish_merge_request(project=project_path, merge_request_iid=mr_iid, reviewed_sha=reviewed_sha, action=action, source_branch=source_branch, target_branch=target_branch, caller_role=caller_role, authority=merge_authority, authority_source=authority_source) -> native action/readback and advisory ci
get_merge_request(project_path, mr_iid) -> verify post-action MR state and record via

```

The caller separately gathers post-merge issue/branch and local-cleanup
evidence for the workflow `finish_result`; follow the cleanup ordering in
[`ci-finish-guards.md`](skill://gitlab/reference/ci-finish-guards.md).

### Snippet: mr-handoff-evidence

Read-only handoff evidence for one MR. MCP primary is `get_merge_request_handoff_evidence` with optional `reviewed_sha`, `review_report_note_id`, and `gate_receipt_note_id`. Output splits `claims` from verified `bindings`. The Reviewer Lift, Review Report, and Gate Receipt remain the canonical artifacts.

Fallback is not a named MCP gap: reassemble the evidence from `safe-mr-json` and the bounded description/note reads in [`bounded-reads.md`](skill://gitlab/reference/bounded-reads.md).

```text

get_merge_request_handoff_evidence(project, merge_request_iid, reviewed_sha?, review_report_note_id?, gate_receipt_note_id?)
get_merge_request_note(project, merge_request_iid, note_id, body_grep) or body_max_bytes -> one Gate Receipt or Review Report field
get_issue_note(project, issue_iid, note_id, body_grep) or body_max_bytes -> one field

```

## Troubleshooting

JSON shape wrong: inspect keys and adapt projection only.
