# CI and finish guard transport card

This card owns the CI/finish specializations for `ci-watch-sha-pinned` and `finish-mr-authority-aware`. The shared ordered mutation seam lives in the **GitLab Mutation Guard**:

- Human contract: `skill://gitlab/reference/mutation-guard.md`
- Machine schema: `skill://gitlab/reference/mutation-guard.schema.json`

Use this card for CI/finish-specific inputs and result vocabulary only. Do not copy the full mutation sequence here; apply the Mutation Guard order first, then the specialization below.

Verdict classification policy lives in [`start-review/REVIEW-FLOW.md#ci-decision-table`](../../start-review/REVIEW-FLOW.md#ci-decision-table). Non-negotiable builder/self-finish floors live in [`start-build/SAFETY.md`](../../start-build/SAFETY.md). Authority claim shape, source precedence, conflict/restriction handling, action routing, and no-self context live in [`authority-verification.md`](authority-verification.md); the role × merge-authority finish sub-decision lives in [`authority-matrix.md`](authority-matrix.md).

## CI verdict mechanics (`ci-watch-sha-pinned`)

`ci-watch-sha-pinned` is read-only evidence for the Mutation Guard `exact_sha_ci_guard` phase. It does not mutate GitLab.

- Re-read the MR head with a fresh MCP re-read (`get_merge_request`) on every poll; fallback `glab mr view` is only a documented fallback when MCP read is unavailable and help-first evidence exists.
- Look up CI for `reviewed_sha` with `list_pipelines(sha=reviewed_sha)` or `get_pipeline`; MR `.pipeline` is supporting evidence only when its SHA matches.
- `list_merge_requests` / fallback `glab mr list` remains candidate data, not decision-grade data for the watched MR.
- Do not use `glab ci status --mr` or any `list_pipelines_for_mr` / `pipelines_for_merge_request` form that lacks an exact SHA.
- If observed MR head differs from `reviewed_sha`, report changed-head / `stale_ci` style evidence and require a new review before any mutation guard can pass.
- Red, failed, canceled, skipped, stale, missing, and timeout states never pass. Machine output keeps `expected_sha`, `observed_sha`, `pipeline_id`, `result`, `status`, and blocker fields so the parent/reviewer can bind evidence to `reviewed_sha`.
- Whether a job that is *absent* from an exact-SHA success pipeline blocks (missing required job) or is approvable (a `rules:`-omitted not-applicable job in the target repo's conditional required-job set) is classified by the canonical [CI decision table](../../start-review/REVIEW-FLOW.md#ci-decision-table); this card does not restate that matrix and stays fail-closed for any absence not declared not-applicable by the target repo.

## Finish specialization (`finish-mr-authority-aware`)

Approval, direct merge, and auto-merge queueing are separate Mutation Guard actions. Finish performs at most one action after the guard passes; builder callers always stop at handoff.

Map finish inputs to Mutation Guard fields as follows:

| Mutation Guard field | Finish source |
| --- | --- |
| `mutation_kind` | `sha-bound-approval`, `sha-bound-merge`, `sha-bound-auto-merge-queue`, or `finish-mr-authority-aware` |
| `reviewed_sha` | SHA from Reviewer Lift / Review Report, guarded with `.sha == reviewed_sha` and transport `--sha` / MCP `sha` where supported |
| `ci_policy` | exact-SHA green CI for merge; protected pending/running policy only for queue auto-merge when allowed |
| `authority_value` / `authority_source` | Review Packet / Review Report / parent or human finish-authority source, verified through [Authority Verification](authority-verification.md) before action |
| `caller_role` / `caller_identity` | caller role plus entry and pre-mutation `get_current_user()` token-stability evidence; same-session no-self classification comes from [Authority Verification](authority-verification.md) |
| `mcp_gap_state` | `none` normally; `mcp_merge_robustness_gap` only for the documented merge fallback; `mcp_unavailable` only when the required MCP action/read is unavailable |
| `post_mutation_reread` | `get_merge_request` / approval state / issue state after mutation; classify `merged`, `auto_merge_queued`, `already_merged`, `stale_head`, `merge_blocked`, or related schema token |

Fallback remains blocked on the Mutation Guard blockers: changed/stale head, stale/red/missing CI, missing authority/source, permission uncertainty, identity drift, same-session/self-finish risk, content-byte failure when text is involved, or unavailable post-mutation re-read. A guarded fallback result records `via=glab-fallback`; MCP primary records `via=mcp`; no-action handoff records `via=n/a`.

Local default-branch fetch/fast-forward and source/worktree cleanup happen only after the finish action is complete or reported as no-action. Worktree removal still requires a clean `status --porcelain` / safety-check precondition. Issue closure checks report `closure_pending` instead of force-closing.
