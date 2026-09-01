# GitLab Mutation Guard

The **GitLab Mutation Guard** is the single seam every GitLab workflow mutation passes through before it writes, approves, marks ready, merges, queues auto-merge, labels, or posts a note. It exists so MCP primary transport and guarded `glab` fallback share the same fail-closed ordering and the same result evidence.

Machine-readable schema: [`mutation-guard.schema.json`](mutation-guard.schema.json) / `skill://gitlab/reference/mutation-guard.schema.json`. Authority phase schema: [`authority-verification.schema.json`](authority-verification.schema.json) / `skill://gitlab/reference/authority-verification.schema.json`.

## Resource addressing

When a skill runs from a target repository, reference guard resources with `skill://gitlab/...`:

- `skill://gitlab/reference/mutation-guard.md`
- `skill://gitlab/reference/mutation-guard.schema.json`
- `skill://gitlab/reference/authority-verification.md`
- `skill://gitlab/reference/authority-verification.schema.json`
- `skill://gitlab/reference/safe-text.md`
- `skill://gitlab/reference/authority-verification.md`
- `skill://gitlab/reference/snippet-transports.md`

Target-repo policy remains repo-relative. Use `docs/agents/check-gate.md`, `docs/agents/dev-workflows.md`, `docs/agents/triage-labels.md`, and similar paths for the repository being changed; do not rewrite those target policy refs as gitlab skill resources.

## Applicability

Run this guard for every mutating GitLab snippet in [`snippet-transports.md`](snippet-transports.md), including:

- Draft MR create, MR description update, Draft MR mark-ready.
- MR/issue note creation and issue label reconciliation.
- SHA-bound approval, direct merge, and auto-merge queue.
- The authority-aware finish helper contract.

Read-only snippets such as issue/MR pickup, CI snapshots, and SHA guards feed evidence into this seam. They do not perform the mutation step.

## Ordered guard sequence

The order is load-bearing. Do not move fallback earlier to “try the CLI” before the non-transport guards have passed.

1. **Project binding.** Bind host/project/repo/default branch from the current worktree and `get_project`. Stop on wrong project, missing default branch, stale local default ref, or auth failure.
2. **Current target re-read.** Re-read MR guard-grade state/SHA with `get_merge_request_workflow_snapshot` by default. Call `get_merge_request(include_description:false)` only when the guard needs an MR field absent from the snapshot; use `get_issue`, approval state, or notes/discussions for their applicable targets. Lists are candidate data only. When description or note content is required, request it separately through the [dedicated bounded body reader](bounded-reads.md); body content is not guard evidence.
3. **Reviewed SHA.** For review, ready, approval, merge, auto-merge, or finish actions, compare current MR head to `reviewed_sha`. A mismatch is `head_changed` and blocks before fallback.
4. **Exact-SHA CI.** When CI is relevant, use exact-SHA pipeline evidence (`list_pipelines(sha=reviewed_sha)` or `get_pipeline`). Missing, red, canceled, skipped, or SHA-mismatched CI is a blocker, not fallback eligibility.
5. **Authority Verification.** Apply the canonical [Authority Verification](authority-verification.md) seam for the exact requested action. Missing, contradictory, restricted, self-context, or unverified authority blocks that action.
6. **Caller identity and context.** Resolve the authenticated caller at entry and re-check immediately before mutation. Stop on identity unavailable/changed, permission uncertainty, or same-session/self-finish risk. GitLab account equality alone is not a self-merge blocker for a fresh gate-eligible reviewer; role/context is the boundary.
7. **Safe GitLab Text.** For body-bearing mutations, run the content-byte rule from [`safe-text.md`](safe-text.md) before the write. NUL, non-whitespace C0 controls, or DEL block both MCP and fallback; diagnostics must not echo the body.
8. **Fallback eligibility.** MCP remains primary. Fallback may be considered only for a first-class MCP gap state (`mcp_unavailable`, `mcp_merge_robustness_gap`, or `mcp_pagination_gap`) after every non-transport guard above has passed and help-first evidence exists for the exact flagged command.
9. **Single mutation.** Take exactly one mutation action. Never combine approve+merge, create+ready, MR-note+issue-note, or label update+close in one guard pass. Use SHA/confirm binding whenever the transport supports it.
10. **Post-mutation MCP re-read.** Re-read through MCP after the mutation and classify the observed state before reporting success. Record `via=mcp`, `via=glab-fallback`, or `via=n/a` in the result evidence.

## Inputs

The schema names the machine fields. Human packets should carry the same facts:

| Input | Meaning |
| --- | --- |
| `mutation_kind` / `snippet_name` | The one action being guarded. |
| `project_path` / `repo_url` | Bound GitLab project and local remote evidence. |
| `target_iid_or_url` | Issue or MR target. Avoid ambiguous bare IDs across projects. |
| `source_branch` / `target_branch` | Required for MR branch-sensitive actions. |
| `reviewed_sha` | Required for review, ready, approval, merge, queue, and finish actions. |
| `ci_policy` | Whether exact-SHA CI is required, pending-allowed, waived, or not relevant. |
| `authority_value` / `authority_source` | Approval, merge, ready, note, or label authority plus provenance; approval/finish actions use the [Authority Verification](authority-verification.md) claim shape and source precedence. |
| `caller_role` / `caller_identity` | Role and token-stability evidence for the actor taking the action. |
| `safe_text_role` | Description, note, or other body role for content-byte diagnostics. |
| `mcp_gap_state` | `none`, `mcp_unavailable`, `mcp_merge_robustness_gap`, or `mcp_pagination_gap`. |
| `fallback_help_evidence` | Exact `glab ... --help` evidence when fallback is used. |
| `expected_post_state` | The state the post-mutation MCP re-read must confirm. |

## Outputs

Every guard result reports:

- `result`: `passed`, `blocked`, `handoff`, `held`, or `escalated`.
- `blocker`: one schema token, or `none`.
- `mutation_performed`: true only after the single mutation step ran.
- `transport_evidence`: `via=mcp`, `via=glab-fallback`, or `via=n/a`.
- `mcp_gap_state`: the gap that justified fallback, or `none`.
- Project, target, SHA, CI, Authority Verification, caller identity, safe-text, and post-read evidence.
- `post_mutation_reread.classification`: `verified`, `note_created`, `description_updated`, `ready_marked`, `approved`, `merged`, `auto_merge_queued`, `labels_reconciled`, `issue_updated`, `already_merged`, `stale_head`, `merge_blocked`, `description_lost`, `target_state_mismatch`, or `post_reread_unavailable`.

`via=n/a` is only for no-action handoff/held/blocked results. A mutating success reports `via=mcp` or `via=glab-fallback`.

## Blockers that forbid fallback

Fallback is forbidden when any of these are present:

- `project_binding_mismatch`
- `target_reread_unavailable`
- `head_changed` / `stale_head`
- `stale_ci`, `red_ci`, or `missing_ci`
- `missing_authority` or `authority_source_mismatch`
- `permission_uncertain`
- `identity_unavailable` or `identity_changed`
- `self_merge_risk`
- `content_byte_failure`
- `post_reread_unavailable`, `description_lost`, `target_state_mismatch`, or `merge_blocked`

These blockers stay fatal for both MCP and `glab` fallback. Fallback exists for transport gaps, not for bypassing guard failures.

## First-class MCP gap states

| Gap state | Meaning | Fallback limit |
| --- | --- | --- |
| `mcp_unavailable` | Required MCP tool/read is unavailable. | Fallback can run only after all non-transport guards pass; success still needs post-mutation MCP re-read or an escalated `post_reread_unavailable` result. |
| `mcp_merge_robustness_gap` | The documented `merge_merge_request` robustness/error-normalization gap was hit after guards passed. | Only the SHA-bound merge/auto-merge fallback named by the snippet may run. |
| `mcp_pagination_gap` | MCP list pagination cannot prove an exhaustive candidate list. | Fallback may only find candidates; a single-record re-read must decide before mutation. |

## Mutation profiles

| Profile | Snippets | Required guard phases |
| --- | --- | --- |
| Body-bearing | `draft-mr-create`, `mr-description-update`, `mr-note-create`, `issue-note-create` | Project binding, current target re-read when target exists, authority, caller/context, Safe GitLab Text, fallback eligibility, single mutation, post-mutation re-read. |
| SHA-bound finish | `sha-bound-approval`, `sha-bound-merge`, `sha-bound-auto-merge-queue`, `finish-mr-authority-aware` | Project binding, current MR re-read, reviewed SHA, exact-SHA CI when relevant, authority, caller/context, fallback eligibility, single mutation, post-mutation re-read. |
| Ready transition | `draft-mr-mark-ready` | Project binding, current MR re-read, reviewed SHA, local gate/Gate Receipt evidence, authority, caller/context, optional Safe GitLab Text, fallback eligibility, single mutation, post-mutation re-read. |
| Candidate selection | `issue-pickup`, `mr-pickup` | Project binding and single-record re-read before any later mutation trusts the selected target. |

## Finish integration

`finish-mr-authority-aware` is a specialization of the SHA-bound finish profile. The finish flow still uses [Authority Verification](authority-verification.md), the authority matrix, caller identity lifecycle, exact-SHA CI policy, and finish result schema, but those documents should point here for the shared mutation order instead of copying it.

Finish-specific result mapping:

- `head_changed` maps to stale review / no action.
- `stale_ci`, `red_ci`, and `missing_ci` map to CI-blocked handoff/held results.
- `missing_authority`, `authority_source_mismatch`, and `permission_uncertain` block the affected finish action.
- `self_merge_risk` means the role/context firewall blocks finish; it is not triggered by same GitLab account equality alone.
- `mcp_merge_robustness_gap` may justify one SHA-bound fallback merge only after every other guard passes.
- Post-mutation re-read classifies `merged`, `auto_merge_queued`, `already_merged`, `stale_head`, or `merge_blocked` before the finisher reports success or blocker.
