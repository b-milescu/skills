# Decoupling Contract

Shared contract for build and review workflows that handle more than one issue or MR at a time. Use this before parallelizing work, batching reviews, or assigning multiple isolated worktrees.

## Contract

A set of issues or MRs is **decoupled** only when every item below is true:

1. **No ordering relation** — no dependency, `depends on`, `after #...`, shared blocker, stacked branch, or release-order relation.
2. **No overlapping work surface** — no expected or observed overlap in changed files, modules, behavior-critical surfaces, or user/operator-visible behavior.
3. **No shared safety surface** — no shared migrations, schemas, locks, sequencing, deploy topology, generated artifacts, version bumps, dependency lockfiles, or other coordination primitive.
4. **Independent evidence** — local checks, tests, and review commands run independently without shared ports, databases, product/runtime/operator external systems, temp refs, artifact directories, or mutable global state.
5. **Independent delivery** — one item can be paused, rejected, rebased, or merged without making another item stale, conflicted, unsafe, or semantically incomplete.

A set is **coupled** when any item is false, unknown, or contradicted by evidence. Coupled work must run serially in the safest order, or wait for a human decision. Never parallelize coupled work to save time.

## Builder producer guidance

Builders prove decoupling before multi-issue work starts and keep the proof current as branches change.

- Write the proof once per MR in `Reviewer Lift > Decoupling proof`.
- List every co-running MR IID when known. If an IID is not known yet, use the branch/issue identifier and update after MR creation.
- State how the set satisfies the contract: no ordering relation, no file/module/safety-surface overlap, no shared migrations/locks/lockfiles/generated artifacts/version bumps/deploy topology, and independent checks/tests.
- Keep `Changed paths` and `Touched safety surfaces` current so reviewers can compare the proof against the diff.
- If a later push, rebase, CI result, or sibling MR creates overlap, conflict, stale state, or ordering pressure, stop treating the set as decoupled and report the blocker.

Role-specific branch creation, worktree creation, MR creation, and cleanup commands stay in the build flow.

## Reviewer consumer guidance

Reviewers read the builder's proof first, then decide whether to accept it or re-derive it.

Accept the proof as stated when all are true:

- every MR in the set has a `Reviewer Lift > Decoupling proof`;
- co-running MR IIDs/branches agree across the proofs;
- sampled changed paths and declared safety surfaces align with the proof;
- MR metadata shows no stacked branches, dependency/order relation, shared blocker, conflict, or stale target state.

Re-derive the proof when any are true:

- proof is missing, placeholder-filled, or does not name co-running MRs/branches;
- proofs disagree about the set;
- changed paths, touched safety surfaces, CI/check behavior, or MR metadata contradicts the proof;
- the proof relies on an unverified assumption about schemas, locks, deploy topology, generated artifacts, lockfiles, shared ports/databases, or mutable global state.

If coupling remains unclear after re-derivation, review serially in the safest order or ask the user to choose. Never parallelize or batch-approve coupled MRs to save time.

Role-specific fetch, temp-ref, worktree, approval, merge, and cleanup commands stay in the review flow.

## Worktree isolation baseline

When parallel work or review uses local checkout state:

- use one isolated worktree per issue or MR;
- use the original checkout as a coordinator only;
- do not share branches, `FETCH_HEAD`, temp refs, temp databases, ports, mutable artifact directories, or uncommitted files across worktrees;
- bind each worktree to its expected branch or reviewed SHA before running evidence commands;
- produce one Review Packet or Review Report and one decision per MR;
- remove a worktree only after the owning flow's clean-status and branch/ref-pushed requirements are satisfied.
