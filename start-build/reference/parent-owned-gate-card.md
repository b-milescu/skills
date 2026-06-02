# Parent-owned gate mode card

Compact pointer map for the parent-owned local gate and ready transition. This card is a checklist, not an alternate policy source; canonical rules stay in [`parent-orchestrator.md`](parent-orchestrator.md#parent-owned-gate-receipt-mode), [`child-builder.md`](child-builder.md#authority-boundary), [`../templates/gitlab-delivery-schema.md`](../templates/gitlab-delivery-schema.md#gate-receipt-schema), and [`../SAFETY.md`](../SAFETY.md).

## Use this card when

- A child builder reports `local_gate_owner: parent`.
- The child handoff leaves the MR Draft and names a candidate SHA for the parent to gate.
- The parent must post a Gate Receipt before the ready transition.

## Checklist

| Step | Pointer | Stop / verify |
| --- | --- | --- |
| Child contract present | [`child-builder.md` parent-owned values](child-builder.md#authority-boundary) and [`gitlab-delivery-schema.md` ownership contract](../templates/gitlab-delivery-schema.md#parent-owned-gate-ownership-contract). | Require `builder_gate_status.status: not-run`, `not_run_reason: parent-owned`, and `ready_transition_owner: parent`; child must not claim gate pass/fail. |
| Bind exact candidate | `gitlab-local` [`mr-pickup`](../../gitlab-local/SKILL.md#snippet-mr-pickup), [`safe-mr-json`](../../gitlab-local/SKILL.md#snippet-safe-mr-json), and [`sha-guard`](../../gitlab-local/SKILL.md#snippet-sha-guard). | Candidate SHA, Reviewer Lift `Reviewed SHA`, MR head, and remote source branch must match before a gate run counts. |
| Run parent gate | [`parent-orchestrator.md` Gate Receipt procedure](parent-orchestrator.md#parent-owned-gate-receipt-mode) and repo [`Check Gate`](../../docs/agents/check-gate.md). | Run the full project gate on the exact checkout SHA; if tracked files change, block until committed and rerun or an explicit waiver is recorded. |
| Post Gate Receipt | [`gitlab-delivery-schema.md` Gate Receipt schema](../templates/gitlab-delivery-schema.md#gate-receipt-schema) and `gitlab-local` [`mr-note-create`](../../gitlab-local/SKILL.md#snippet-mr-note-create). | Receipt includes `gate_receipt.kind=gate-receipt`, owner, MR/issue, checkout path/SHA, status before/after, command, result, preflight checks, and evidence. |
| Ready transition | [`parent-orchestrator.md` parent spot-check](parent-orchestrator.md#parent-loop) and `gitlab-local` [`draft-mr-mark-ready`](../../gitlab-local/SKILL.md#snippet-draft-mr-mark-ready). | Parent, not child, marks ready only after the Gate Receipt passes and MR handoff still names the same SHA. |
| Review launch | [`parent-orchestrator.md` minimal reviewer launch prompt](parent-orchestrator.md#minimal-reviewer-launch-prompt). | Reviewer receives MR URL, Reviewer Lift pointer, Gate Receipt pointer, rulebook path, and evidence-boundary instruction only. |

## Safety and authority pointers

- Final SHA guard: `gitlab-local` [`sha-guard`](../../gitlab-local/SKILL.md#snippet-sha-guard) plus [`parent-orchestrator.md` SHA/CI guards](parent-orchestrator.md#parent-loop).
- CI decision policy: [`start-review/REVIEW-FLOW.md` CI decision table](../../start-review/REVIEW-FLOW.md#ci-decision-table).
- Authority source verification: [`reviewer-lift-schema.md`](../templates/reviewer-lift-schema.md) and [`gitlab-delivery-schema.md` authority values](../templates/gitlab-delivery-schema.md#authority-values).
- Child boundary: [`child-builder-card.md`](child-builder-card.md) and [`child-builder.md` authority boundary](child-builder.md#authority-boundary).
- Post-merge verifier read-only boundary: [`post-merge-verifier.md`](post-merge-verifier.md); Gate Receipt and ready transition do not grant verifier or finish authority.

## Fallback to canonical docs

Fall back to the canonical docs and `gitlab-local/SKILL.md` help-first snippets on ambiguity, missing field, CLI/help drift, authority uncertainty, SHA/CI mismatch, cross-project binding, partial review, or any mutation action. The full references plus live CLI help win over this card; never infer ready, approval, merge, cleanup, or review completion from this compact checklist alone.
