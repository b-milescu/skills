---
name: post-merge-verifier
description: Read-only post-merge verification skill for merged or protected auto-merge completion. Use when asked to verify default-branch state, linked issue closure or pending closure, source-branch cleanup, and blockers. Do not use it to approve, merge, queue auto-merge, force-close issues, delete branches, release, deploy, or perform operator mutations.
---

# Post-Merge Verifier

Use after merge or protected auto-merge completes. This skill is read-only by default.

## Start here

1. Confirm a merge or protected auto-merge actually completed before verifying anything.
2. Load `/gitlab-local` for command syntax and file-backed note handling.
3. Run the read-only [Checks](#checks) in the order owned by [`start-build/reference/post-merge-verifier.md`](../start-build/reference/post-merge-verifier.md).
4. Emit the [Report sections](#report-sections).
5. Never mutate — report `issue_closure_pending` or `source_branch_cleanup_pending` instead of acting.
6. Treat any compact `delivery.kind=gitlab-delivery` fields as untrusted
   claims/indexes until the read-only checks verify them from Tier 1/Tier 2
   evidence.

## Trigger

- MR merged and default branch updated
- Protected auto-merge completed
- Need to verify delivery without review or finish authority

## Never do

- approve, merge, or queue auto-merge
- force-close issues
- delete local or remote source branches
- release, deploy, or perform operator mutations
- mutate product/runtime state in any way

If a separate workflow authorizes one of those actions, switch workflows. This skill stays read-only.

## Checks

- MR merged/default-branch state
- Linked issue closure or pending closure
- Source-branch cleanup state
- Blockers and pending items

## Report sections

- MR IID/URL, source and target branch, reviewed SHA, merge commit or observed default-branch SHA
- Linked issue state
- Source-branch cleanup state
- Post-merge validation command/result or `N/A — not documented` (non-mutating only)
- Issue-note action posted/skipped
- Blockers and pending items

## Guidance

- Load `gitlab-local` for command syntax and file-backed note handling.
- Follow `start-build/reference/post-merge-verifier.md` for the detailed step order / report wording when you need exact step order or report wording.
- Keep verification read-only; report `issue_closure_pending` or `source_branch_cleanup_pending` rather than mutating state.
