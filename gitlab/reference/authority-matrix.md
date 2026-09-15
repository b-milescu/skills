# Finish authority matrix

Role × merge-authority × action decision table enforced by MCP `finish_merge_request`; a sub-decision of [`authority-verification.md`](authority-verification.md), which owns claim shape, precedence, routing, and caller-context no-self checks. See [`identity-and-authentication.md`](identity-and-authentication.md) for identity capture and context classification.

Builders never self-approve or self-merge ([`SAFETY.md`](../../start-build/SAFETY.md#non-negotiables)); `confirm:true` and `sha=` bind intent and head, not role authority.

## Decision table

Each cell lists all allowed actions. Anything absent is blocked with `reason=authority`.

| Role \ Merge authority | approval-only | reviewer may merge | queue auto-merge | human release |
| --- | --- | --- | --- | --- |
| `builder` | handoff | handoff | handoff | handoff |
| `reviewer` | approve, handoff | merge, approve, handoff | queue-auto-merge, handoff | handoff |
| `authorized-parent` | approve, handoff | merge, approve, handoff | queue-auto-merge, handoff | handoff |
| `human` | approve, handoff | merge, approve, handoff | queue-auto-merge, handoff | handoff |

`handoff` is always allowed. `human release` reserves the release outside this gate. `queue auto-merge` does not grant direct merge. `Finish owner: parent` overrides reviewer mutation cells to `handoff`; parent/authorized-parent/human paths still require the same authority source, independent review, SHA, CI, and Mutation Guard checks.
