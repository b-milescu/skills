# GitLab snippets: read and evidence

Read-only binding, pickup, capture, and evidence snippets. No snippet here mutates GitLab state.

Entry procedure, transport order, help-first rule, snippet index, and the Mutation Guard pointer stay in [`SKILL.md`](skill://gitlab/SKILL.md). Machine source of truth for snippet names and contracts: `skill://gitlab/reference/snippet-metadata.json`, mirrored by [`snippet-transports.md`](snippet-transports.md). Grouping rationale: [ADR-0002](../../docs/adr/0002-phase-grouped-gitlab-snippet-disclosure.md).

## Snippet: local-repo-preflight

Use the canonical `local-repo-preflight` entry in
[`snippet-metadata.json`](skill://gitlab/reference/snippet-metadata.json) and
its synchronized row in
[`snippet-transports.md`](skill://gitlab/reference/snippet-transports.md).
`get_project` is the MCP primary for project/default-branch binding; local `git`
owns cwd, remote URL, branch, and ref checks. A help-first
`glab repo view` is fallback/troubleshooting only. Stop on non-git cwd, project
mismatch, missing default branch, stale or missing local default ref, or
authentication failure.

## Snippet: issue-pickup

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

## Snippet: mr-pickup

```bash

glab mr view
glab mr list --not-draft -F json --per-page 50
glab mr view <id> --comments
glab mr view <id> -F json | jq '{iid,title,state,draft,source_branch,target_branch,author:.author.username,web_url,sha,pipeline,detailed_merge_status}'

```

## Snippet: artifact-capture

```bash

mr_id="<id>"; run_dir="$(mktemp -d "${TMPDIR:-/tmp}/glab-mr-${mr_id}.XXXXXX")"
glab mr view "$mr_id" --comments > "$run_dir/mr-comments.txt"
glab mr view "$mr_id" -F json > "$run_dir/mr.json"
glab mr diff "$mr_id" --color=never > "$run_dir/diff.patch"
glab mr diff "$mr_id" --raw --color=never | git apply --numstat

```

## Snippet: safe-mr-json

Stable snippet name for guard-grade MR workflow metadata. MCP primary is `get_merge_request_workflow_snapshot` plus project binding; consume only decision-grade fields needed for SHA/state/CI/merge guards, with no list-only data. Fail closed on project binding, SHA, pipeline, merge-status, branch, JSON/control-character drift. Guarded `glab mr view` projection fallback is only for MCP snapshot unavailability.

```text

get_merge_request_workflow_snapshot(project_path, mr_iid)
get_project(project_path) -> verify binding

```

## Snippet: sha-guard

MCP primary is `get_merge_request_workflow_snapshot`; compare its top-level `sha` with `reviewed_sha`. The fallback below is only for MCP-unavailable metadata reads and still requires explicit project binding plus help-first verification.

```bash

reviewed_sha="<sha-you-reviewed>"
current_sha="$(glab mr view <id> -F json | jq -r '.sha')"
[ "$current_sha" = "$reviewed_sha" ] || { echo "MR head changed: current=$current_sha reviewed=$reviewed_sha" >&2; exit 1; }

```

## Snippet: ci-decision-snapshot

```bash

glab mr view <id> -F json | jq '{mr_sha:.sha,pipeline:.pipeline,merge:.detailed_merge_status}'
glab ci status --branch "$source_branch" -F json

```

## Snippet: ci-watch-sha-pinned

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

## Snippet: approval-confirmation

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

## Snippet: mr-handoff-evidence

Read-only handoff evidence for one MR. MCP primary is `get_merge_request_handoff_evidence` with optional `reviewed_sha`, `review_report_note_id`, and `gate_receipt_note_id`. Output splits `claims` from verified `bindings`. The Reviewer Lift, Review Report, and Gate Receipt remain the canonical artifacts.

Fallback is not a named MCP gap: reassemble the evidence from `safe-mr-json` and the bounded description/note reads in [`bounded-reads.md`](skill://gitlab/reference/bounded-reads.md).

```text

get_merge_request_handoff_evidence(project, merge_request_iid, reviewed_sha?, review_report_note_id?, gate_receipt_note_id?)
get_merge_request_note(project, merge_request_iid, note_id, body_grep) or body_max_bytes -> one Gate Receipt or Review Report field
get_issue_note(project, issue_iid, note_id, body_grep) or body_max_bytes -> one field

```
