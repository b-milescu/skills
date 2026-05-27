# Post-merge verifier recipe

Detailed read-only verifier contract for `start-build`. The stable entrypoint and compatibility anchor remain in [BUILD-FLOW.md](../BUILD-FLOW.md#post-merge-verifier-recipe).

Use this recipe only after the independent review and authority-aware finish steps report that merge or protected auto-merge completed. The verifier is a read-only confirmation role, not another reviewer and not a finisher.

Allowed checks:

1. Fetch the target/default branch and inspect fetched refs. Fast-forward a local default branch only in a clean checkout where the project workflow allows it; otherwise inspect `origin/<default>`.
2. Confirm the MR is in merged state and record the MR IID/URL, source branch, target branch, reviewed SHA, merge commit when available, and observed target branch SHA.
3. Confirm the fetched default branch contains the reviewed SHA, squash commit, or merge commit recorded by GitLab. If the project uses squash/rebase merge and the reviewed SHA is not an ancestor, report the merge commit or equivalent commit that GitLab exposes instead of guessing.
4. Confirm the linked issue state. If closure from `Closes #<id>` is still pending, report `issue_closure_pending` with the observed issue state and do not force-close the issue unless the project workflow explicitly instructs the verifier to do so.
5. Check source-branch cleanup by reading MR metadata and/or remote refs. If the source branch still exists, report `source_branch_cleanup_pending` or `source_branch_retained_by_policy`; do not delete local or remote branches unless a separate authorized finish/cleanup step grants that authority.
6. Run documented post-merge validation only when the command is non-mutating and safe for the current environment. If no such command is documented, report `post_merge_validation: N/A — not documented`.
7. Post a concise issue note only when the repo/project workflow explicitly asks for post-merge notes. Use `/gitlab-local` file-backed note guidance, include only evidence from the checks above, and skip the note otherwise.

Forbidden actions:

- Do not approve, reject, request changes, resolve review authority questions, or claim the mandatory review gate is complete.
- Do not merge, queue auto-merge, retry merge, delete remote branches, or force close issues.
- Do not run mutating release/deploy/operator validation unless a human has explicitly authorized that operator action and the project workflow documents how to record it.

Verifier report should include MR state, target/default branch SHA, reviewed SHA or merge commit containment result, linked issue state, source-branch cleanup state, post-merge validation command/result or N/A rationale, issue-note action posted/skipped, and any pending items. Pending issue closure or branch deletion is a verification result to report, not an implicit verifier mutation request.
