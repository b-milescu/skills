# Azure DevOps Transport

Native identifiers: organization, project ID, repository ID, default branch. Use
mounted Azure DevOps Boards/Repos/Pipelines tools first and native REST only for
a required guarded operation they do not expose. Add no SDK.

## Snapshot

- Bind the reviewed source commit to the current PR iteration and its
  `sourceRefCommit.commitId`; require it to equal `lastMergeSourceCommit`.
- Read the complete iteration diff, every thread/comment, linked work-item
  revisions, required policy evaluations, and build evidence.
- Azure Pipelines is advisory. Attribute an observation to the synthetic
  `lastMergeCommit` only when the iteration source binding above holds and the
  build `sourceVersion` equals that merge commit; every status and absence leave
  verdict and action eligibility unchanged.
- Reviewer votes are policy input, not standalone approval. Require the current
  blocking policy evaluations to be approved.

No dedicated Azure DevOps handoff-evidence tool exists. Satisfy the snapshot
shape from these reads, or record the field `unavailable`:

- change-request author id: pull request created-by identity;
- Lift `claims` and missing rows: parse Reviewer Lift markers in the PR
  description;
- note-bound Review Report and Gate Receipt `claims` with author identity:
  thread/comment by the explicit id the caller already holds; otherwise
  `unavailable`;
- four head/author `bindings`: compare those claims to the iteration
  `sourceRefCommit.commitId` and the PR author id.

## Publish and act

- Draft state is `isDraft`; drafts may not receive build validation.
- Direct completion binds `lastMergeSourceCommit`, keeps `bypassPolicy=false`,
  and succeeds only after readback reports completed plus a successful merge.
- `autoCompleteSetBy` has no documented expected-head binding. An exact-commit
  queue request returns `sha-bound-action-unsupported` instead of approximating
  success.
- Native branch or repository protection may refuse completion. Report the
  provider result and never bypass it.
- `transitionWorkItems` is best effort and never normalized to closure.

## Issue publish

Create one Boards work item through the mounted Boards write (native REST only
when that write is not exposed), apply the mapped fields, then re-read the work
item byte-for-byte. Identifiers stay opaque. Fail closed if this branch cannot
name a native create.

## Post-merge

Verify reviewed-source binding, `lastMergeCommit` result identity, repository
refs/cleanup, and every linked work item's observed state category. Any CI
observation stays advisory. Only the provider-observed Completed state category
counts as closed.
