# Parent-owned gate mode card

Compact pointer map for the parent-owned local gate and ready transition. This card is a checklist, not an alternate policy source; the canonical ownership fields, Gate Receipt schema, parent verification checklist, and evidence-ready tokens live in [`parent-owned-gate.md`](parent-owned-gate.md).

## Use this card when

- A child builder reports `local_gate_owner: parent`.
- The child handoff leaves the MR Draft and names a candidate SHA for the parent to gate.
- The parent must post a Gate Receipt before the ready transition.

## Checklist

| Step | Pointer | Stop / verify |
| --- | --- | --- |
| Child contract present | [`parent-owned-gate.md` ownership contract](parent-owned-gate.md#ownership-contract) and [`child-builder.md` authority boundary](child-builder.md#authority-boundary). | Require the canonical parent-owned contract; child must not claim gate pass/fail. |
| Bind exact candidate | `gitlab-local` [`mr-pickup`](../../gitlab-local/SKILL.md#snippet-mr-pickup), [`safe-mr-json`](../../gitlab-local/SKILL.md#snippet-safe-mr-json), and [`sha-guard`](../../gitlab-local/SKILL.md#snippet-sha-guard). | Candidate SHA, Reviewer Lift `Reviewed SHA`, MR head, and remote source branch must match before a gate run counts. |
| Run parent gate | [`parent-owned-gate.md` parent verification checklist](parent-owned-gate.md#parent-verification-checklist) and repo [`Check Gate`](../../docs/agents/check-gate.md). | Run the full project gate on the exact checkout SHA; if tracked files change, block until committed and rerun or an explicit waiver is recorded. |
| Post Gate Receipt | [`parent-owned-gate.md` Gate Receipt schema](parent-owned-gate.md#gate-receipt-schema) and `gitlab-local` [`mr-note-create`](../../gitlab-local/SKILL.md#snippet-mr-note-create). | Receipt includes `gate_receipt.kind=gate-receipt` and every required field from the canonical seam. |
| Ready transition | [`parent-owned-gate.md` ready-transition checklist](parent-owned-gate.md#parent-verification-checklist) and `gitlab-local` [`draft-mr-mark-ready`](../../gitlab-local/SKILL.md#snippet-draft-mr-mark-ready). | Parent, not child, marks ready only after the Gate Receipt passes and MR handoff still names the same SHA. |
| Review launch | [`parent-orchestrator.md` minimal reviewer launch prompt](parent-orchestrator.md#minimal-reviewer-launch-prompt). | Reviewer receives MR URL, Reviewer Lift pointer, Gate Receipt pointer, rulebook path, and evidence-boundary instruction only. |

## Safety and authority pointers

- Final SHA guard: `gitlab-local` [`sha-guard`](../../gitlab-local/SKILL.md#snippet-sha-guard) plus [`parent-orchestrator.md` SHA/CI guards](parent-orchestrator.md#parent-loop).
- CI decision policy: [`start-review/REVIEW-FLOW.md` CI decision table](../../start-review/REVIEW-FLOW.md#ci-decision-table).
- Authority source verification: [`reviewer-lift-schema.md`](../templates/reviewer-lift-schema.md) and [`gitlab-delivery-schema.md` authority values](../templates/gitlab-delivery-schema.md#authority-values); parent-owned gate evidence stays in [`parent-owned-gate.md`](parent-owned-gate.md).
- Child boundary: [`child-builder-card.md`](child-builder-card.md) and [`child-builder.md` authority boundary](child-builder.md#authority-boundary).
- Post-merge verifier read-only boundary: [`post-merge-verifier.md`](post-merge-verifier.md); Gate Receipt and ready transition do not grant verifier or finish authority.

## Fallback to canonical docs

Fall back to the canonical docs and `gitlab-local/SKILL.md` transport/fallback snippets on ambiguity, missing field, transport/help drift, authority uncertainty, SHA/CI mismatch, cross-project binding, partial review, or any mutation action. The full references plus live fallback help win over this card; never infer ready, approval, merge, cleanup, or review completion from this compact checklist alone.
