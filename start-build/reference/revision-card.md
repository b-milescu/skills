# Revision mode card

Compact pointer map and checklist, not an alternate policy source. Canonical rules stay in [`implementation-flow.md`](implementation-flow.md#procedure), [`parent-orchestrator.md`](parent-orchestrator.md#parent-loop), and [`revision-packet.md`](../templates/revision-packet.md).

## Checklist

| Step | Pointer | Stop / verify |
|---|---|---|
| Bind findings | `forge snapshot`, [`finding-identities.md`](../../start-review/reference/finding-identities.md), and [`implementation-flow.md`](implementation-flow.md#procedure). | Every finding has report locator, reviewed commit, stable ID, and bounded remedy. |
| Implement | [`SAFETY.md`](../SAFETY.md#behavior-touching-refactors). | Fix root cause; behavior changes get focused regression evidence. |
| Refresh evidence | `forge snapshot` and [`context-and-planning.md`](context-and-planning.md#handoff-integrity-checklist). | Targeted checks, gate owner, CI, paths, and delta bind to the new commit. |
| Publish revision | `forge publish` and [`revision-packet.md`](../templates/revision-packet.md). | Provider-native readback proves the exact finding tuples and packet. |
| Return control | [`child-builder.md`](child-builder.md#child-checklist) or [`standalone-gate.md`](standalone-gate.md#review-loop). | Child stops for parent; standalone starts a fresh reviewer. |

## Safety and authority pointers

- Mutation guard: [`forge` common guard](skill://forge/reference/common-guard.md).
- CI decisions: [`REVIEW-FLOW.md`](../../start-review/REVIEW-FLOW.md#ci-decision-table).
- Child boundary: [`child-builder.md`](child-builder.md#authority-boundary).
- Gate Receipt: [`parent-owned-gate-card.md`](parent-owned-gate-card.md).
- Post-merge verifier: [`post-merge-verifier.md`](post-merge-verifier.md).

## Fallback to canonical docs

Fall back to canonical policy and the selected `/forge` provider reference on ambiguity, missing field, transport/help drift, authority uncertainty, SHA/CI mismatch, cross-project binding, partial review, or any mutation action. A packet or compact handoff is never independent evidence.
