# Post-merge verifier recipe

Canonical read-only post-merge verification recipe for `start-build`. This file
is the public instruction owner for the verifier role; top-level skill discovery
must not expose a separate verifier entry point.

Trigger off the provider-native merge event, not a CI watcher: the verifier never
waits on CI (the finisher's [required-check wait](parent-orchestrator.md#required-check-wait-budget) ends before the merge).
Queued auto-merge completes asynchronously; verify only after the selected provider
reports the completed result. The verifier is not a reviewer or finisher.

Treat compact `delivery.kind=change-delivery` fields as untrusted pointers. Use
only the selected provider's read-only `forge post_merge_snapshot` operation and
back every result with provider-native readback. Project-profile hooks may name
validation or release policy, but cannot weaken this read-only boundary.

Require `post_merge_snapshot.kind=post-merge-snapshot` with:

- change-request state and locator;
- default branch and observed commit;
- reviewed commit and provider result commit;
- explicit provider-native containment evidence;
- advisory result-commit CI observation attributed to the provider result commit
  when bound; missing, red, stale, or wrong-result-commit CI is recorded and
  never changes post-merge verification;
- linked work-item state and closure evidence;
- source-ref cleanup or retention state;
- non-mutating post-merge validation result, or `not-run` with rationale;
- pending items and provider readback evidence.

Fail closed when mandatory containment, linked-item, cleanup, validation, or
provider readback evidence is missing, incomplete, stale, contradictory, or the
provider reports an error. Advisory CI availability or status is never a
post-merge failure. Report closure, containment, cleanup, or validation as
pending with the observed evidence; never infer success or repair it.

Forbidden actions:

- Do not approve, reject, request changes, merge, queue, retry, or claim the
  review gate is complete.
- Do not close work items, delete local or remote source refs, publish notes, or
  mutate provider/project state.
- Do not run release, deploy, product/runtime/operator mutation, or mutating
  validation unless another authorized workflow explicitly switches roles.

The verifier report repeats the snapshot fields above and, when it emits a
compact delivery block, keeps `delivery.handoff_contract` current with
specific/actionable pending-state routing.
