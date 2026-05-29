---
name: post-merge-verifier
description: Read-only post-merge verification skill for merged or protected auto-merge completion. Use when asked to verify default-branch state, linked issue closure or pending closure, CI evidence, source-branch cleanup, and blockers. Do not use it to approve, merge, queue auto-merge, force-close issues, delete branches, release, deploy, or perform operator mutations.
---

# Post-Merge Verifier

Use after merge or protected auto-merge completes. This skill is read-only by default.

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
- CI evidence for reviewed/head SHA where available (non-mutating only)
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
