# CI observation and finish transport card

This card owns the GitLab specializations for `ci-watch-sha-pinned` and
`finish-mr-authority-aware`. The shared ordered mutation seam lives in the
**GitLab Mutation Guard**:

- Human contract: `skill://gitlab/reference/mutation-guard.md`
- Machine schema: `skill://gitlab/reference/mutation-guard.schema.json`

Review eligibility lives in
[`start-review/REVIEW-FLOW.md#ci-decision-table`](../../start-review/REVIEW-FLOW.md#ci-decision-table).
The exact-candidate local Gate Receipt and builder/self-finish floors live in
[`start-build/SAFETY.md`](../../start-build/SAFETY.md). Authority claim shape,
source precedence, and action routing live in
[`authority-verification.md`](authority-verification.md).

## Advisory CI observation (`ci-watch-sha-pinned`)

`ci-watch-sha-pinned` is read-only progress/evidence tooling. It does not mutate
GitLab and its result never determines review or finish eligibility.

- Re-read the MR head on every poll; stop attributing observations to
  `reviewed_sha` if the head changes.
- Query `list_pipelines(sha=reviewed_sha)` or `get_pipeline`; MR `.pipeline` is
  supporting evidence only when its SHA matches.
- Keep `expected_sha`, `observed_sha`, pipeline locator/ID, status, and binding
  classification in output. Missing, failed, canceled, skipped, pending, stale,
  and timeout observations are advisory.
- A bound MR that becomes merged mid-watch is a merge-event observation only
  when its head still equals `reviewed_sha`; queue remains non-terminal until
  provider state reports merged.
- Do not use `glab ci status --mr` or any MR-pipeline query that cannot bind an
  exact SHA.

This read-only watcher remains useful for progress displays and diagnosis. It is
not part of the `finish_merge_request` eligibility contract.

## Finish specialization (`finish-mr-authority-aware`)

The deployed shape from `agents/gitlab-mcp!157` accepts no CI-exception input.
Its `ci` output is optional and nullable advisory evidence:

- a normalized pipeline when the bounded reviewed-SHA query returns one;
- `null` when no reviewed-SHA pipeline exists;
- absent only on the already-merged, no-mutation short circuit.

Successful finish results carry no CI eligibility field. Any returned CI status is
non-blocking for approval-only, direct merge, and queue-auto-merge.

Approval, direct merge, and auto-merge queueing are separate Mutation Guard
actions. The caller owns the workflow proof and invokes native finish only
after these mandatory guards pass, including independent exact-SHA review:

1. project, MR, source, and target binding;
2. current head equals `reviewed_sha`;
3. passing exact-candidate local Gate Receipt;
4. verified action-specific authority and caller/context eligibility;
5. fallback eligibility when applicable;
6. exactly one mutation and provider-native readback.

The caller assembles the workflow finish result from native action/result, SHA,
nullable advisory `ci`, separately gathered post-merge issue/branch and local
cleanup state, authority/caller evidence, and transport. Native finish checks
fresh project/MR/SHA/branches and supplied role/authority, then returns action
readback; its success does not prove the exact-candidate Gate Receipt,
independent review, authority provenance, or caller identity/context eligibility.
Native GitLab branch protection or merge policy may refuse the mutation;
report the refusal as the provider result and never bypass it. Builder callers
always stop at handoff.

Local default-branch fetch/fast-forward and source/worktree cleanup happen only
after the finish action completes or is reported as no-action. Worktree removal
still requires a clean `status --porcelain` precondition. Issue closure checks
report `closure_pending` instead of force-closing.
