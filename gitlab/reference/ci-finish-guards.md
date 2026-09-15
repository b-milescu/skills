# CI observation and finish transport card

This card owns the GitLab specializations for `ci-watch-sha-pinned` and
`finish-mr-authority-aware`. The shared ordered mutation seam is the
**GitLab Mutation Guard** (`skill://gitlab/reference/mutation-guard.md`); review
eligibility is
[`start-review/REVIEW-FLOW.md#ci-decision-table`](../../start-review/REVIEW-FLOW.md#ci-decision-table),
the exact-candidate local Gate Receipt and builder/self-finish floors are in
[`SAFETY.md`](../../start-build/SAFETY.md), and authority claims are in
[`authority-verification.md`](authority-verification.md).

## Advisory CI observation (`ci-watch-sha-pinned`)

`ci-watch-sha-pinned` is read-only progress tooling: it does not mutate GitLab
and its result never determines review or finish eligibility.

- Re-read the MR head on every poll; stop attributing to `reviewed_sha` if it
  changes.
- Query `list_pipelines(sha=reviewed_sha)` or `get_pipeline`; MR `.pipeline` is
  supporting evidence only when its SHA matches. Never use `glab ci status --mr`
  or any query that cannot bind an exact SHA.
- Output keeps `expected_sha`, `observed_sha`, pipeline locator/ID, status, and
  binding classification; every status, missing state, and timeout is advisory.
- A merge observed mid-watch counts only when the head still equals
  `reviewed_sha`; queue stays non-terminal until provider state reports merged.

## Finish specialization (`finish-mr-authority-aware`)

`finish_merge_request` accepts no CI-exception input. Its `ci` output is
optional and nullable advisory evidence: a normalized pipeline when the bounded
reviewed-SHA query returns one, `null` when none exists, absent only on the
already-merged short circuit. Successful finish results carry no CI
eligibility field; any returned CI status is non-blocking for approval-only,
direct merge, and queue-auto-merge.

Approval, direct merge, and auto-merge queueing are separate Mutation Guard
actions. The caller invokes native finish only after the [ordered guard
sequence](mutation-guard.md#ordered-guard-sequence) passes for the requested
action, ending in exactly one mutation and provider-native readback.

The caller assembles the workflow finish result from native action/result, SHA,
nullable advisory `ci`, post-merge issue/branch and cleanup state,
authority/caller evidence, and transport. Native success does not prove the Gate
Receipt, independent review, authority provenance, or caller identity/context
eligibility. Native branch protection or merge policy may refuse the mutation;
report the refusal as the provider result and never bypass it. Builder callers stop at handoff.

Local default-branch fast-forward and source/worktree cleanup happen only after
the finish action completes or is reported no-action; worktree removal requires a
clean `status --porcelain`. Issue closure checks report `closure_pending` instead
of force-closing.
