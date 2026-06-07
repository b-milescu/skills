# CI and finish guard transport card

This card owns the transport mechanics for `ci-watch-sha-pinned` and `finish-mr-authority-aware`. MCP is primary. Guarded `glab` fallback is allowed only when the snippet contract in [`snippet-transports.md`](snippet-transports.md) names a fallback condition and every SHA/CI/authority/caller guard below still passes.

Verdict classification policy lives in [`start-review/REVIEW-FLOW.md#ci-decision-table`](../../start-review/REVIEW-FLOW.md#ci-decision-table). Authority and builder-boundary policy live in [`start-build/SAFETY.md`](../../start-build/SAFETY.md) and [`authority-matrix.md`](authority-matrix.md).

## CI verdict mechanics (`ci-watch-sha-pinned`)

Use MCP `get_merge_request` for the MR head re-read on every poll. Use exact-SHA pipeline data from `list_pipelines(sha=reviewed_sha)` or `get_pipeline`; MR `.pipeline` may be supporting evidence only when it exposes the same SHA. `list_merge_requests` / fallback `glab mr list` is not decision-grade data for the watched MR. Do not use `glab ci status --mr` or any `list_pipelines_for_mr` / `pipelines_for_merge_request` form that lacks an exact SHA.

### Polling and SHA rules

1. Re-read `get_merge_request` every poll; fallback `glab mr view` is allowed only after help-first and only when MCP read is unavailable.
2. Fail immediately if observed MR head differs from `reviewed_sha`; report `stale_ci` or changed-head and require a new review for the new SHA.
3. Look up the pipeline for `reviewed_sha` with `list_pipelines` / `get_pipeline`; do not pass a green pipeline for another SHA.
4. Treat red, failed, canceled, skipped, missing, and stale pipeline states as non-pass verdicts under the CI decision table.
5. Treat a timeout as fail-closed; output `timeout` with `expected_sha`, `observed_sha`, `pipeline_id`, and status fields.
6. Do not rely on broad list data for exact-SHA CI; list pagination limitations make broad lists candidate-only.
7. Machine output keeps `expected_sha`, `observed_sha`, `pipeline_id`, `result`, `status`, and blocker fields so the parent/reviewer can bind evidence to `reviewed_sha`.

## Finish guard/authority mechanics (`finish-mr-authority-aware`)

Finish performs at most one action after fresh MCP re-reads. Approval, direct merge, and auto-merge queueing are separate actions; never combine them. The result/report must include transport evidence, such as `via=mcp` for MCP primary or `via=glab-fallback` for guarded fallback.

### Guard and authority order

1. Re-read `get_merge_request`; require current `.sha` to equal `reviewed_sha` before approval, merge, auto-merge, or fallback.
2. Re-read exact-SHA CI with `list_pipelines(sha=reviewed_sha)` / `get_pipeline`; classify with `REVIEW-FLOW.md#ci-decision-table`.
3. Verify approval/merge authority and source before the specific action; missing or contradictory source blocks the affected action.
4. Verify caller identity before the gate and re-check it immediately before mutation so token drift is caught. Apply the caller-role and merge-authority matrix; GitLab account equality is not a finish blocker for a fresh gate-eligible reviewer.
5. Builder callers always stop at handoff and never approve or merge; a builder handoff may report candidate inputs only.
6. Execute exactly one finish action: approval, direct merge, auto-merge queue, or handoff/no-action. Do not paste multiple action snippets together.
7. For fallback, run help-first for every flagged `glab` command, execute exactly one fallback action, then re-read through MCP and record `via=glab-fallback`.
8. Fetch/fast-forward the local default branch only after a merge/queue/finish action has completed or been reported as no-action; never fetch/fast-forward to justify an action before it happens.
9. Verify issue state with `get_issue` when an issue IID is known; report `closure_pending` instead of force-closing when GitLab has not closed the linked issue yet.
10. Remove a worktree only when the worktree removal safety check has passed first: verify clean status / `status --porcelain` empty and default-branch containment or equivalent merged-SHA safety before removal.

## Fallback and troubleshooting

Fall back to [`gitlab-local/SKILL.md`](../SKILL.md) and live `--help` when MCP tooling is unavailable, the documented merge robustness gap is hit, helper behavior needs diagnosis, or project-specific policy requires a variant. Fallback is blocked on stale head, stale/red/missing CI, missing authority, permission uncertainty, caller identity drift, same-session review/finish risk, or unsafe cleanup preconditions.
