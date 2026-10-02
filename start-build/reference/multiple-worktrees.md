# Multiple work-item worktree mode

Use this mode only for multiple work items that satisfy the shared
[Decoupling Contract](skill://start-build/docs/decoupling-contract.md). Unknown
or contradicted decoupling evidence means serial work.

1. Use the original checkout as coordinator only. Require clean status and run
   `forge preflight` for provider/repository/default-branch binding.
2. Immediately before each child worktree, fetch the confirmed named code remote, record the verified
   remote-default commit, create the branch/worktree from that commit, and verify
   its `HEAD`. Stop and remove only a clean newly-created worktree on mismatch.
3. Run one work item, branch, Draft change request, Check Gate, and Review Packet
   per worktree.
4. In each Reviewer Lift, list co-running change-request identifiers/locators and
   branches, summarize the Decoupling Contract proof, and keep changed paths and
   safety surfaces current.
5. Only the parent/coordinator launches builders or reviewers. Child builders do
   not launch either role.
6. Keep durable handoffs in provider-published change-request descriptions and
   discussions with provider-native readback. Local run artifacts stay in a
   caller-owned absolute directory outside temporary worktrees.
7. Keep evidence scoped to one worktree/change request. Do not combine packets,
   close multiple work items from one change request, or stack branches unless
   the user explicitly switches to a serial plan.
8. Before revision or finish, use `forge snapshot` to re-check target branch,
   current commit, and conflict state. Report newly discovered coupling.
9. Remove a worktree only after its branch is pushed, its status is clean, and
   `forge post_merge_snapshot` proves the provider result commit is contained by
   the fast-forwarded default branch. Preserve unknown or containment-unverified
   paths and report `cleanup_pending`.
