# Azure DevOps Transport

Use only after `preflight` binds organization, project ID, repository ID, and
default branch. Use mounted Azure DevOps Boards/Repos/Pipelines tools first and
native REST only for a required guarded operation they do not expose. Add no SDK.

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

Verify reviewed-source binding, `lastMergeCommit` result identity,
repository refs/cleanup, and every linked work item's observed state category.
Any CI observation remains advisory and cannot change the post-merge result.
Only the provider-observed Completed state category counts as closed.
