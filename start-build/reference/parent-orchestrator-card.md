# Parent orchestrator mode card

Compact pointer map and checklist, not an alternate policy source. Canonical rules stay in [`parent-orchestrator.md`](parent-orchestrator.md#parent-loop), [`multiple-worktrees.md`](multiple-worktrees.md), and [`../SAFETY.md`](../SAFETY.md).

## Checklist

| Step | Pointer | Stop / verify |
|---|---|---|
| Resolve scope | `forge preflight`, `forge snapshot`, [`issue-pickup.md`](issue-pickup.md), and [`multiple-worktrees.md`](multiple-worktrees.md). | Verify issue state, ownership, dependencies, and Decoupling Contract. |
| Launch child | [`child-builder-card.md`](child-builder-card.md) and [`parent-orchestrator.md`](parent-orchestrator.md#minimal-child-builder-launch-prompt). | One issue, isolated worktree, branch, Draft change request, and handoff per child. |
| Verify handoff | `forge snapshot` and [`context-and-planning.md`](context-and-planning.md#handoff-integrity-checklist). | Treat routing claims as unverified until provider-native readback and repository evidence agree. |
| Parent gate | [`parent-owned-gate-card.md`](parent-owned-gate-card.md). | Gate Receipt binds the exact candidate before ready. |
| Review/revise | [`parent-orchestrator.md`](parent-orchestrator.md#parent-loop) and [`revision-card.md`](revision-card.md). | Fresh reviewer; every revision invalidates prior commit-bound evidence. |
| Finish | Guarded `forge act` with [`forge` common guard](skill://forge/reference/common-guard.md). | One authority-scoped action only after current-commit, CI, caller, and authority guards pass. |
| Verify | `forge post_merge_snapshot` and [`post-merge-verifier.md`](post-merge-verifier.md). | Read-only verifier; no finish, cleanup, closure, release, or operator mutation. |

## Safety and authority pointers

- Child boundary: [`child-builder.md`](child-builder.md#authority-boundary).
- CI decisions: [`REVIEW-FLOW.md`](../../start-review/REVIEW-FLOW.md#ci-decision-table).
- Gate Receipt: [`parent-owned-gate.md`](parent-owned-gate.md#gate-receipt-schema).
- Post-merge verifier: [`post-merge-verifier.md`](post-merge-verifier.md).

## Fallback to canonical docs

Fall back to canonical policy and the selected `/forge` provider reference on ambiguity, missing field, transport/help drift, authority uncertainty, SHA/CI mismatch, cross-project binding, partial review, or any mutation action. Never infer review, authority, finish, or verifier success from this card.
