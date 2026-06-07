# Finish authority matrix

Canonical, human-readable decision table for the role × merge-authority × action
finish gate. It is the finish-action sub-decision inside
[`authority-verification.md`](authority-verification.md), which owns the broader
approval/merge authority claim shape, source precedence, conflict/restricted
results, action routing, and no-self relationship to caller context. This table is
sourced from [`start-build/SAFETY.md` non-negotiables](../../start-build/SAFETY.md#non-negotiables)
(no builder self-approval or self-merge; finish actions belong only to an
authorized reviewer, parent, or human after independent review) and it mirrors,
case-for-case, the inline finish authority switch in
[`scripts/gitlab-finish-mr.sh`](../scripts/gitlab-finish-mr.sh).

The deterministic gate [`scripts/gitlab-finish-authority.sh`](../scripts/gitlab-finish-authority.sh)
enforces this table. The gate is pure-local and makes no network call: it decides
role authority only. MCP / `glab` `confirm:true` and `sha=` enforce intent and
head-binding, **not** role authority. The matrix-match regression test in
[`tests/gitlab-finish-authority.sh`](../../tests/gitlab-finish-authority.sh)
parses this table and asserts the gate agrees with it cell-for-cell.

This matrix feeds the canonical [Authority Verification](authority-verification.md) phase of the [GitLab Mutation Guard](mutation-guard.md); it does not own approval authority defaults, source precedence, project binding, SHA/CI, fallback eligibility, or post-mutation re-read ordering.

## Actions

The gate evaluates one requested `--action`:

- `handoff` — stop and hand off; take no approve/merge/queue action.
- `approve` — approve the MR (SHA-bound), no merge.
- `merge` — direct merge.
- `queue-auto-merge` — queue protected auto-merge.

## Decision table

Each cell lists every action the gate **allows** for that
role × merge-authority pair. Any action not listed in a cell is blocked for that
pair with `reason=authority`. The `builder` row allows only `handoff` in every
column, regardless of merge authority.

| Role \ Merge authority | approval-only | reviewer may merge | queue auto-merge | human release |
| --- | --- | --- | --- | --- |
| `builder` | handoff | handoff | handoff | handoff |
| `reviewer` | approve, handoff | merge, approve, handoff | queue-auto-merge, handoff | handoff |
| `authorized-parent` | approve, handoff | merge, approve, handoff | queue-auto-merge, handoff | handoff |
| `human` | approve, handoff | merge, approve, handoff | queue-auto-merge, handoff | handoff |

Notes:

- `builder:*` is always `handoff`: a builder may prepare/report inputs but never
  approves, merges, or queues auto-merge for its own MR.
- `*:approval-only` permits `approve` (and `handoff`) but never `merge` or
  `queue-auto-merge`.
- `*:human release` is `handoff` only: the finish action is reserved for a human
  release step outside this gate.
- `reviewer may merge` permits `merge`; it also permits `approve` (approval is a
  weaker action than merge) and `handoff`.
- `queue auto-merge` permits `queue-auto-merge` (and `handoff`); it does not by
  itself grant a direct `merge`.
- `handoff` is always allowed for any role × authority pair: stopping is never
  blocked by authority.

## Identity and context guard

The gate still requires non-empty `--caller-user-id` and `--mr-author-id` with
`reason=invalid_user_id` on missing values, but GitLab account equality is not an
authority blocker by itself. Review independence is a session/context boundary:
a fresh gate-eligible reviewer may approve or merge even when the authenticated
GitLab account is the same account that opened the MR. Builder self-approval and
self-merge remain impossible because the `builder` role is `handoff` only, and a
same-session builder/parent/planner/reviser review is advisory-only under the
Context Firewall.

See [`identity-and-authentication.md`](identity-and-authentication.md) and
[`authority-verification.md`](authority-verification.md)
for how `caller_user_id`, `mr_author_id`, and same-session context are obtained,
re-verified, and classified for audit/token-stability and no-self checks.
