# GitLab snippets: mutate and finish

Approval, merge, auto-merge queue, and finish snippets. Choose exactly one action for the authority you have, and run the GitLab Mutation Guard first.

Entry procedure, transport order, help-first rule, snippet index, and the Mutation Guard pointer stay in [`SKILL.md`](skill://gitlab/SKILL.md). Machine source of truth for snippet names and contracts: `skill://gitlab/reference/snippet-metadata.json`, mirrored by [`snippet-transports.md`](snippet-transports.md). Grouping rationale: [ADR-0002](../../docs/adr/0002-phase-grouped-gitlab-snippet-disclosure.md).

## Snippet: sha-bound-approval

Use only when the reviewed SHA is current, approval authority permits reviewer approval, and no explicit approval restriction applies. For `approval-only` merge authority, this is the only approval/finish action.

```bash

mr_iid="<id>"
reviewed_sha="<sha-you-reviewed>"
glab mr approve "$mr_iid" --sha "$reviewed_sha"

```

## Snippet: sha-bound-merge

Use only when the [GitLab Mutation Guard](skill://gitlab/SKILL.md#gitlab-mutation-guard) passes and explicit authority permits direct merge.

```bash

mr_iid="<id>"
reviewed_sha="<sha-you-reviewed>"
glab mr merge "$mr_iid" --yes --sha "$reviewed_sha" --auto-merge=false

```

## Snippet: sha-bound-auto-merge-queue

Use only when the [GitLab Mutation Guard](skill://gitlab/SKILL.md#gitlab-mutation-guard) passes, project policy permits protected auto-merge, and explicit authority permits queueing auto-merge. Request source-branch removal on merge with `--remove-source-branch` (MCP primary: `should_remove_source_branch=true`), matching the primary finish path so the remote source branch is gone once the queued merge completes.

```bash

mr_iid="<id>"
reviewed_sha="<sha-you-reviewed>"
glab mr merge "$mr_iid" --auto-merge --yes --sha "$reviewed_sha" --remove-source-branch

```

## Snippet: auto-merge-api-fallback

Stable snippet name for the known auto-merge queue fallback boundary. Authorized non-builders should prefer the native finish call below, or lower-level `merge_merge_request(auto_merge=true, sha=reviewed_sha, should_remove_source_branch=true, confirm=true)`. Use guarded `glab mr merge --auto-merge --sha --remove-source-branch` fallback only for the documented MCP/CLI 405 gap after the [GitLab Mutation Guard](skill://gitlab/SKILL.md#gitlab-mutation-guard) passes.

```text

finish_merge_request(project=project_path, merge_request_iid=mr_iid, reviewed_sha=reviewed_sha, action="queue-auto-merge", source_branch=source_branch, target_branch=target_branch, caller_role=caller_role, authority="queue auto-merge", authority_source=authority_source, should_remove_source_branch=true)
get_merge_request(project_path, mr_iid) -> verify queue state and record via=mcp or via=glab-fallback

```

## Snippet: finish-mr-authority-aware

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
