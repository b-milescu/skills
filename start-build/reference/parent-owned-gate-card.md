# Parent-owned gate mode card

Compact pointer map and checklist, not an alternate policy source. Canonical ownership, Gate Receipt schema, and verification live in [`parent-owned-gate.md`](parent-owned-gate.md).

## Checklist

| Step | Pointer | Stop / verify |
|---|---|---|
| Verify child contract | [`parent-owned-gate.md`](parent-owned-gate.md#ownership-contract) and [`child-builder.md`](child-builder.md#authority-boundary). | Child reports parent-owned/not-run and does not claim a result. |
| Bind candidate | `forge snapshot` and [`forge` common guard](skill://forge/reference/common-guard.md). | Candidate, Reviewer Lift, change-request head, and remote source name one current commit. |
| Run gate | [`parent-owned-gate.md` checklist](parent-owned-gate.md#parent-verification-checklist). | Full project gate runs on that exact checkout; tracked changes invalidate it. |
| Publish receipt | `forge publish` and [`Gate Receipt schema`](parent-owned-gate.md#gate-receipt-schema). | Provider-native publication/readback proves one complete exact-commit receipt. |
| Mark ready | Guarded `forge act` after canonical receipt and finding-binding validation. | Stop on any validation or common-guard failure. |
| Launch review | [`parent-orchestrator.md`](parent-orchestrator.md#minimal-reviewer-launch-prompt). | Independent review may launch while bound exact-commit CI is pending; the reviewer verifies CI and all claims. |

## Safety and authority pointers

- Child boundary: [`child-builder-card.md`](child-builder-card.md).
- CI decisions: [`REVIEW-FLOW.md`](../../start-review/REVIEW-FLOW.md#ci-decision-table).
- Gate Receipt: [`parent-owned-gate.md`](parent-owned-gate.md#gate-receipt-schema).
- Post-merge verifier: [`post-merge-verifier.md`](post-merge-verifier.md).

## Fallback to canonical docs

Fall back to canonical policy and the selected `/forge` provider reference on ambiguity, missing field, transport/help drift, authority uncertainty, SHA/CI mismatch, cross-project binding, partial review, or any mutation action. Never infer ready, approval, finish, or review completion from this card.
