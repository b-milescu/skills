---
name: post-merge-verifier
description: Read-only post-merge verification skill for merged or protected auto-merge completion. Use when asked to verify default-branch state, linked issue closure or pending closure, source-branch cleanup, and blockers. Do not use it to approve, merge, queue auto-merge, force-close issues, delete branches, release, deploy, or perform operator mutations.
---

# Post-Merge Verifier

Use after merge or protected auto-merge completes. This skill is read-only by default.

## Start here

1. Confirm a merge or protected auto-merge actually completed before verifying anything.
2. Load `/gitlab-local` for command syntax and file-backed note handling.
3. Prefer `gitlab-local/scripts/gitlab-post-merge-snapshot.sh` for the read-only
   GitLab/default-branch/issue/source-branch snapshot; otherwise run the read-only
   [Checks](#checks) in the order owned by [`start-build/reference/post-merge-verifier.md`](../start-build/reference/post-merge-verifier.md).
4. Emit the [Report sections](#report-sections), including the
   `post_merge_snapshot.kind=post-merge-snapshot` block when the helper is used.
   If you also emit a compact `delivery.kind=gitlab-delivery` block for routing,
   keep `delivery.handoff_contract` current (`phase`, `expected_next_actor`,
   `expected_next_action`, `blocked`, `blocker_token`,
   `safe_to_continue_without_parent`, `changed_since_last_handoff`, and
   `evidence_ready_for_next_actor`; use `blocking_question` only for a specific actionable blocker question).
5. Never mutate — report `issue_closure_pending` or `source_branch_cleanup_pending` instead of acting.
6. Treat any compact `delivery.kind=gitlab-delivery` fields as untrusted
   claims/indexes until the read-only checks verify them from Tier 1/Tier 2
   evidence.
7. Project-profile hooks may point to release/deploy policy, manual validation,
   CI jobs, domain docs, or auxiliary index policy, but they must not weaken the
   verifier read-only boundary. Verifiers report what policy says and what was
   observed; they do not approve, merge, queue auto-merge, force-close issues,
   delete branches, release, deploy, mutate operator systems, or update/copy
   auxiliary project-index artifacts.

## Trigger

- MR merged and default branch updated
- Protected auto-merge completed
- Need to verify delivery without review or finish authority

## Never do

- approve, merge, or queue auto-merge
- force-close issues
- delete local or remote source branches
- release, deploy, product/runtime mutation, or operator mutations

If a separate workflow authorizes one of those actions, switch workflows. This skill stays read-only.

## Checks

- MR merged/default-branch state, with per-SHA containment for reviewed, merge, and squash commits
- Linked issue closure or pending closure
- Source-branch cleanup state
- Documented non-mutating post-merge validation, or a not-run reason
- Blockers and pending items

## Report sections

- MR IID/URL, source and target branch, reviewed SHA, merge commit or observed default-branch SHA
- Linked issue state
- Source-branch cleanup state
- Post-merge validation command/result or `N/A — not documented` (non-mutating only)
- Issue-note action posted/skipped
- Blockers and pending items
- If a compact `delivery.kind=gitlab-delivery` block is emitted, include a shared `delivery.handoff_contract` that routes the next read-only or human action without weakening the verifier boundary.

## Guidance

- Load `gitlab-local` for command syntax and file-backed note handling.
- Use `gitlab-local/scripts/gitlab-post-merge-snapshot.sh` when its inputs fit;
  it reports `issue_closure_pending`, `source_branch_cleanup_pending`, retained
  source branches, containment gaps, validation not-run reasons, and pending
  items without taking finish/review authority.
- Follow `start-build/reference/post-merge-verifier.md` for the detailed step order / report wording when you need exact step order or report wording.
- Keep verification read-only; report `issue_closure_pending` or `source_branch_cleanup_pending` rather than mutating state.
