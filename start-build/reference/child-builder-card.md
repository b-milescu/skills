# Child builder mode card

Compact pointer map and checklist, not an alternate policy source. Canonical rules stay in [`child-builder.md`](child-builder.md), [`../SAFETY.md`](../SAFETY.md), and [`../SKILL.md`](../SKILL.md).

## Checklist

| Step | Pointer | Stop / verify |
|---|---|---|
| Bind scope | `forge preflight`, `forge snapshot`, and [`child-builder.md` checklist](child-builder.md#child-checklist). | Re-read provider, repository, issue, and ownership; stop on ambiguity, cross-project binding, or changed ownership. |
| Start clean | [`implementation-flow.md`](implementation-flow.md#procedure). | Clean isolated worktree at the current default commit. |
| Publish Draft | `forge publish`. | One Draft change request with provider-native closure evidence and current Review Packet; do not mark ready early. |
| Build evidence | [`SAFETY.md`](../SAFETY.md#non-negotiables) and [`context-and-planning.md`](context-and-planning.md#handoff-integrity-checklist). | TDD or explicit `TDD: N/A`; keep Reviewer Lift and authority provenance current. |
| Bind final commit | `forge snapshot` and [`forge` common guard](skill://forge/reference/common-guard.md). | Local head, remote source, change-request head, Review Packet, and handoff agree. |
| Return handoff | [`builder-final-handoff.md`](../templates/builder-final-handoff.md). | Child stops; parent owns independent review, approval, finish, cleanup, and read-only post-merge verification. |

## Safety and authority pointers

- Child boundary: [`child-builder.md`](child-builder.md#authority-boundary).
- Gate Receipt: [`parent-owned-gate.md`](parent-owned-gate.md#gate-receipt-schema).
- CI decisions: [`REVIEW-FLOW.md`](../../start-review/REVIEW-FLOW.md#ci-decision-table).
- Post-merge verifier: [`post-merge-verifier.md`](post-merge-verifier.md).

## Fallback to canonical docs

Fall back to canonical policy and the selected `/forge` provider reference on ambiguity, missing field, transport/help drift, authority uncertainty, SHA/CI mismatch, cross-project binding, partial review, or any mutation action. Live provider help and canonical policy win over this card.
