# GitLab Mutation Guard

The **GitLab Mutation Guard** is the single fail-closed seam every mutating GitLab snippet in [`snippet-transports.md`](snippet-transports.md) passes through before it writes, approves, marks ready, merges, queues auto-merge, labels, or posts a note; read-only snippets only feed it evidence. MCP and guarded `glab` fallback share its ordering and evidence.

Machine schemas own the guard's input/output fields, mutation profiles, and finish mapping: [`mutation-guard.schema.json`](mutation-guard.schema.json), [`authority-verification.schema.json`](authority-verification.schema.json).

## Ordered guard sequence

The order is load-bearing. Do not move fallback earlier to “try the CLI” before the non-transport guards have passed.

1. **Project binding.** Bind host/project/repo/default branch from the current worktree and `get_project`. Stop on wrong project, missing default branch, stale local default ref, or auth failure.
2. **Current target re-read.** Re-read MR guard-grade state/SHA with `get_merge_request_workflow_snapshot` by default. Call `get_merge_request(include_description:false)` only when the guard needs an MR field absent from the snapshot; use `get_issue`, approval state, or notes/discussions for their applicable targets. Lists are candidate data only. When description or note content is required, request it separately through the [dedicated bounded body reader](bounded-reads.md); body content is not guard evidence.
3. **Reviewed SHA.** For review, ready, approval, merge, auto-merge, or finish actions, compare current MR head to `reviewed_sha`. A mismatch is `head_changed` and blocks before fallback.
4. **Advisory CI observation.** Read exact-SHA pipeline evidence when available (`list_pipelines(sha=reviewed_sha)` or `get_pipeline`). Attribute a status only when its SHA matches `reviewed_sha` or the provider-proven integration candidate. Missing, red, canceled, skipped, stale, or mismatched CI is recorded and never blocks the workflow action.
5. **Exact-candidate Gate Receipt.** Approval and finish require the durable passing local Gate Receipt bound to `reviewed_sha`.
6. **Authority Verification.** Apply the canonical [Authority Verification](authority-verification.md) seam for the exact requested action. Missing, contradictory, restricted, self-context, or unverified authority blocks that action.
7. **Caller identity and context.** Resolve the authenticated caller at entry and re-check immediately before mutation. Stop on identity unavailable/changed, permission uncertainty, or same-session/self-finish risk. GitLab account equality alone is not a self-merge blocker for a fresh gate-eligible reviewer; role/context is the boundary.
8. **Safe GitLab Text.** For body-bearing mutations, run the content-byte rule from [`safe-text.md`](safe-text.md) before the write. NUL, non-whitespace C0 controls, or DEL block both MCP and fallback; diagnostics must not echo the body.
9. **Fallback eligibility.** MCP remains primary. Fallback may be considered only for a first-class MCP gap state (`mcp_unavailable`, `mcp_merge_robustness_gap`, or `mcp_pagination_gap`) after every non-transport guard above has passed and help-first evidence exists for the exact flagged command.
10. **Single mutation.** Take exactly one mutation action. Never combine approve+merge, create+ready, MR-note+issue-note, or label update+close in one guard pass. Use SHA/confirm binding whenever the transport supports it.
11. **Post-mutation MCP re-read.** Re-read through MCP after the mutation and classify the observed state before reporting success. Record `via=mcp`, `via=glab-fallback`, or `via=n/a` in the result evidence.

`via=n/a` is only for no-action handoff/held/blocked results. A mutating success reports `via=mcp` or `via=glab-fallback`.

## Blockers that forbid fallback

Fallback is forbidden when any of these are present:

- `project_binding_mismatch`
- `target_reread_unavailable`
- `head_changed` / `stale_head`
- `stale_or_missing_gate_receipt`
- `missing_authority` or `authority_source_mismatch`
- `permission_uncertain`
- `identity_unavailable` or `identity_changed`
- `self_merge_risk`
- `content_byte_failure`
- `post_reread_unavailable`, `description_lost`, `target_state_mismatch`, or `merge_blocked`

These blockers stay fatal for both MCP and `glab` fallback. Fallback exists for transport gaps, not for bypassing guard failures.

## First-class MCP gap states

- `mcp_unavailable` — required MCP tool/read unavailable; success still needs post-mutation MCP re-read or an escalated `post_reread_unavailable`.
- `mcp_merge_robustness_gap` — documented `merge_merge_request` robustness/normalization gap; only the snippet's named SHA-bound merge/auto-merge fallback may run.
- `mcp_pagination_gap` — list pagination cannot prove an exhaustive candidate list. An incomplete first page alone is not permission: follow [Selected list traversal](bounded-reads.md#selected-list-traversal) for cursor-first recovery, keep candidate sets explicitly partial, and let a single-record re-read decide before mutation.
