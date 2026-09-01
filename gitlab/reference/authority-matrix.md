# Finish authority matrix

Canonical role × merge-authority × action decision table enforced by MCP `finish_merge_request`. It is the finish-action sub-decision within [`authority-verification.md`](authority-verification.md), which owns claim shape, source precedence, conflicts/restrictions, routing, and caller-context no-self checks.

The table derives from [`start-build/SAFETY.md` non-negotiables](../../start-build/SAFETY.md#non-negotiables): builders never self-approve or self-merge, and finish belongs only to an authorized reviewer, parent, or human after independent review. MCP/`glab` `confirm:true` and `sha=` bind intent and head, not role authority.

This matrix feeds the Authority Verification phase of the [GitLab Mutation Guard](mutation-guard.md). It does not own approval defaults, source precedence, project/SHA/CI guards, fallback eligibility, or post-read ordering.

## Actions

- `handoff` — stop and take no approve/merge/queue action.
- `approve` — SHA-bound approval without merge.
- `merge` — direct merge.
- `queue-auto-merge` — queue protected auto-merge.

## Decision table

Each cell lists all allowed actions. Anything absent is blocked with `reason=authority`.

| Role \ Merge authority | approval-only | reviewer may merge | queue auto-merge | human release |
| --- | --- | --- | --- | --- |
| `builder` | handoff | handoff | handoff | handoff |
| `reviewer` | approve, handoff | merge, approve, handoff | queue-auto-merge, handoff | handoff |
| `authorized-parent` | approve, handoff | merge, approve, handoff | queue-auto-merge, handoff | handoff |
| `human` | approve, handoff | merge, approve, handoff | queue-auto-merge, handoff | handoff |

`handoff` is always allowed. `human release` reserves the release outside this gate. `queue auto-merge` does not grant direct merge. `Finish owner: parent` overrides reviewer mutation cells to `handoff`; parent/authorized-parent/human paths still require the same authority source, independent review, SHA, CI, and Mutation Guard checks.

## Identity and context guard

Caller and MR-author ids must be non-empty; missing values yield `identity_unavailable`. Account equality alone is not an authority blocker: a fresh gate-eligible reviewer may share the MR author's GitLab account. The Context Firewall makes same-session builder/parent/planner/reviser review advisory-only, and the builder row makes self-approval/self-merge impossible.

See [`identity-and-authentication.md`](identity-and-authentication.md) and [`authority-verification.md`](authority-verification.md) for identity capture, token-stability checks, and context classification.
