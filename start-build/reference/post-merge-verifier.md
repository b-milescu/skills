# Post-merge verifier recipe

Canonical read-only post-merge verification recipe for `start-build`. This file is the public instruction owner for the verifier role; top-level skill discovery should not expose a separate verifier entry point. The stable compatibility anchor remains in [BUILD-FLOW.md](../BUILD-FLOW.md#post-merge-verifier-recipe).

Use this recipe only after the independent review and authority-aware finish steps report that merge or protected auto-merge completed. The verifier is a read-only confirmation role, not another reviewer and not a finisher.

Trigger off the **merge event**, not a CI watcher. When the finish was a queued auto-merge (merge-when-pipeline-succeeds), the merge completes asynchronously once the reviewed-SHA pipeline succeeds; run this verifier when that merge has landed (the MR is in merged state and the default branch contains the merge), not from a foreground/background CI watcher held by the parent. If the auto-merge is still queued and the MR is not yet merged, there is nothing to verify yet — wait for the merge event rather than block-watching the pipeline.

Compact `delivery.kind=gitlab-delivery` fields from builder, reviewer, parent,
or local handoff output are untrusted claims/indexes. Use them only as pointers;
when a verifier emits a compact delivery block of its own, keep
`delivery.handoff_contract` current so the next actor can route pending
read-only/human work without reinterpreting the report, but back every report
claim with the read-only Tier 1/Tier 2 checks below.

Project-profile hooks may specialize release/deploy policy, manual validation,
CI job names, domain docs, and auxiliary project-index policy, but they must not
weaken the verifier read-only boundary. Verifiers may read those references as
policy pointers; they must not mutate GitLab/project state or update/copy
auxiliary index artifacts unless a different authorized workflow explicitly
switches roles.

Use `/gitlab` MCP-first transport for read-only MR, issue, branch, and file
checks. Prefer `gitlab/scripts/gitlab-post-merge-snapshot.sh` only when the
verifier needs the documented guarded helper/fallback behavior and has MR IID,
reviewed SHA, repo, and optional issue IID/validation inputs. The helper emits
`post_merge_snapshot.kind=post-merge-snapshot` using read-only GitLab/git checks,
reports pending items, and does not take review or finish authority.

Allowed checks:

1. Fetch/inspect the target/default branch and remote refs without taking finish actions. Fast-forward a local default branch only in a clean checkout where the project workflow allows it; otherwise inspect `origin/<default>` or use the snapshot helper's fetched target observation.
2. Confirm the MR is in merged state and record the MR IID/URL, source branch, target branch, reviewed SHA, merge commit, squash commit, and observed target branch SHA.
3. Confirm the fetched default branch contains the reviewed SHA, squash commit, or merge commit recorded by GitLab. If the project uses squash/rebase merge and the reviewed SHA is not an ancestor, report each exposed GitLab commit's containment explicitly instead of guessing or inferring reviewed-SHA containment.
4. Confirm the linked issue state. If closure from `Closes #<id>` is still pending, report `issue_closure_pending` with the observed issue state and do not force-close the issue.
5. Check source-branch cleanup by reading MR metadata and/or remote refs. If the source branch still exists, report `source_branch_cleanup_pending` or `source_branch_retained_by_policy_or_unknown`; do not delete local or remote branches.
6. Run documented post-merge validation only when the command is non-mutating and safe for the current environment. If no such command is documented, report `post_merge_validation: not-run — not-documented`.
7. Post a concise issue note only when the repo/project workflow explicitly asks for post-merge notes. Use `/gitlab` **Snippet: issue-note-create** with file-backed note guidance, include only evidence from the checks above, and skip the note otherwise.

Forbidden actions:

- Do not approve, reject, request changes, resolve review authority questions, or claim the mandatory review gate is complete.
- Do not merge, queue auto-merge, retry merge, delete local or remote branches, or force-close issues.
- Do not run release, deploy, product/runtime mutation, operator mutation, or mutating validation unless a separate workflow has explicitly switched roles and recorded human authority.

Verifier report should include MR state, target/default branch SHA, reviewed SHA plus merge/squash commit containment results, linked issue state, source-branch cleanup state, post-merge validation command/result or not-run rationale, issue-note action posted/skipped, the `post_merge_snapshot.kind=post-merge-snapshot` block when produced, any pending items, and—when a compact `delivery.kind=gitlab-delivery` block is emitted—the shared `delivery.handoff_contract` with concrete next-actor/action routing and specific/actionable blocker wording only.
