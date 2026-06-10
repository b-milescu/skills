# Multiple issue worktree mode

Detailed reference for `start-build` multi-issue worktree handling. The stable entrypoint and compatibility anchor remain in [BUILD-FLOW.md](../BUILD-FLOW.md#multiple-issue-worktree-mode).

Use this mode when the user supplies multiple issues, asks for multiple tasks, or requests more than one issue at once.

1. Resolve candidates first. Build a set only if every item is one-MR-sized, unblocked, and satisfies the shared [Decoupling Contract](skill://start-build/docs/decoupling-contract.md).
2. Prove decoupling before parallelizing using the contract's builder producer guidance. If any contract item is false, unknown, or contradicted by evidence, treat the work as coupled.
3. If decoupling is unclear, stop and ask for a serial order or smaller set. Never parallelize coupled work to save time.
4. Use the original checkout as a coordinator only — do not code in it during a multi-issue run:
   - `git status --porcelain` empty;
   - detect default branch with `gitlab` **Snippet: local-repo-preflight** (`default_branch`, or project docs if the snippet cannot run);
   - for each issue, immediately before its `git worktree add`, run `git fetch origin`;
   - read and record `default_sha="$(git rev-parse "origin/$default_branch")"` for that issue;
   - create the sibling worktree from the verified remote default: `git worktree add -b <branch> <path> "origin/$default_branch"`;
   - verify the new worktree's `HEAD` equals the recorded `default_sha`; if the SHA cannot be read or does not match, remove the new worktree if it is clean and stop instead of launching a child builder.
5. In each worktree, run the normal implementation flow from context loading onward. One issue, one branch, one Draft MR, one check gate, one Review Packet per worktree.
6. **Write the decoupling proof once per MR, in `Reviewer Lift > Decoupling proof`.** Follow the [Decoupling Contract's builder producer guidance](skill://start-build/docs/decoupling-contract.md#builder-producer-guidance): list co-running MR IIDs/branches, state why the contract holds, and keep `Changed paths` and `Touched safety surfaces` current so the reviewer can spot contradictions quickly. The reviewer reads this proof before re-deriving it.
7. **Delegate isolated work from a coordinator only.** A parent/coordinator with agent-launch authority may start one builder per worktree using its runtime-specific mechanism and the [Parent-orchestrator recipe](parent-orchestrator.md). The compatibility anchor remains in [BUILD-FLOW.md](../BUILD-FLOW.md#parent-orchestrator-recipe). If you are already running inside a child builder worktree, this step is complete: do not launch builders or reviewers from the child session.
8. **Use durable parent-readable outputs.** For child handoffs that the parent must read after cleanup, follow the [durable child output guidance](parent-orchestrator.md#durable-child-outputs): inline output, or an absolute output path in a caller-created run directory outside any `omp-worktree-*` checkout. Treat GitLab MR descriptions/comments as canonical for delivery handoffs; the compatibility anchor remains in [BUILD-FLOW.md](../BUILD-FLOW.md#durable-child-outputs).
9. Keep per-issue artifacts/evidence scoped to that worktree/MR or the parent run dir named for that issue. Do not combine Review Packets, close multiple issues from one MR, or stack branches unless the user explicitly switches to a serial plan.
10. Before revision/merge follow-up, re-check target branch and merge status. If another worktree's MR creates a conflict or stale branch, pause and report the coupling.
11. Remove a worktree only after its branch is pushed, `git -C <path> status --porcelain` is empty, and the merge/cleanup state is known. After merge, fast-forward local default first (`git fetch origin`, `git checkout <default_branch>`, `git pull --ff-only origin <default_branch>`) or verify the MR `merge_commit_sha` / `squash_commit_sha` is an ancestor of the fast-forwarded local default before deleting local source branches. Use `git worktree prune` only after verifying stale paths.
