# Finish authority matrix

Canonical, human-readable decision table for the role × merge-authority × action
finish gate. It is sourced from
[`start-build/SAFETY.md` non-negotiables](../../start-build/SAFETY.md#non-negotiables)
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

## Self-merge / self-approval guard

Independently of the table above, the gate blocks **any** non-`handoff` action
when `caller_user_id == mr_author_id` with `reason=self_merge`. This enforces the
no-self-merge / no-self-approval rule unconditionally: even an `authorized-parent`
or `human` caller cannot approve or merge an MR they authored. Empty or missing
`--caller-user-id` / `--mr-author-id` is blocked with `reason=invalid_user_id`.

See [`identity-and-authentication.md`](identity-and-authentication.md) for how
`caller_user_id` and `mr_author_id` are obtained and re-verified.
