# Revision mode card

Compact pointer map for builder revision work after review feedback or a substantive post-ready push. This card is a checklist, not an alternate policy source; canonical rules stay in [`implementation-flow.md`](implementation-flow.md#procedure), [`standalone-gate.md`](standalone-gate.md#review-loop), [`parent-orchestrator.md`](parent-orchestrator.md#parent-loop), and [`../templates/revision-packet.md`](../templates/revision-packet.md).

## Use this card when

- A reviewer or parent returns request-changes findings tied to a reviewed SHA.
- A post-ready change is needed and the reviewer must not rely on stale evidence.
- A child builder is asked to revise an existing Draft/ready MR and return to the parent.

## Checklist

| Step | Pointer | Stop / verify |
| --- | --- | --- |
| Bind review inputs | `gitlab-local` [`mr-pickup`](../../gitlab-local/SKILL.md#snippet-mr-pickup), [`sha-guard`](../../gitlab-local/SKILL.md#snippet-sha-guard), and [`standalone-gate.md` review loop](standalone-gate.md#review-loop). | Findings must name stable IDs and reviewed SHA; stop on SHA/CI mismatch, partial review, or missing findings. |
| Implement fixes | [`implementation-flow.md` revision step](implementation-flow.md#procedure) and [`SAFETY.md` behavior-touching refactor rules](../SAFETY.md#behavior-touching-refactors). | Fix commits name review item IDs where applicable; behavior-touching fixes get targeted regression evidence. |
| Rerun evidence | [`context-and-planning.md` handoff checklist](context-and-planning.md#handoff-integrity-checklist) and repo [`Check Gate`](../../docs/agents/check-gate.md). | Targeted checks cover each finding; full gate ownership follows the active mode, with parent-owned not-run values when delegated. |
| Post revision packet | [`revision-packet.md`](../templates/revision-packet.md) and `gitlab-local` [`mr-note-create`](../../gitlab-local/SKILL.md#snippet-mr-note-create). | Reply to each MF/SF/C item with fix, evidence, and unresolved blocker if any. |
| Refresh MR handoff | `gitlab-local` [`mr-description-update`](../../gitlab-local/SKILL.md#snippet-mr-description-update) and [`reviewer-lift-schema.md`](../templates/reviewer-lift-schema.md). | `Reviewed SHA`, CI row, Local gate row, Changed paths, and Delta since last ready push reflect the new MR head. |
| Return control | [`child-builder.md` final handoff](child-builder.md#child-checklist) or [`standalone-gate.md` fresh reviewer rule](standalone-gate.md#review-loop). | Child mode stops for parent; standalone mode starts a fresh reviewer session instead of reusing stale approval. |

## Safety and authority pointers

- Final SHA guard: `gitlab-local` [`sha-guard`](../../gitlab-local/SKILL.md#snippet-sha-guard) and [`ci-decision-snapshot`](../../gitlab-local/SKILL.md#snippet-ci-decision-snapshot).
- CI decision policy: [`start-review/REVIEW-FLOW.md` CI decision table](../../start-review/REVIEW-FLOW.md#ci-decision-table).
- Authority source verification: [`reviewer-lift-schema.md`](../templates/reviewer-lift-schema.md) and [`parent-orchestrator.md` finish by authority](parent-orchestrator.md#parent-loop).
- Child no-review/no-merge boundary: [`child-builder.md` authority boundary](child-builder.md#authority-boundary).
- Gate Receipt procedure: [`parent-owned-gate-card.md`](parent-owned-gate-card.md) and [`gitlab-delivery-schema.md` Gate Receipt schema](../templates/gitlab-delivery-schema.md#gate-receipt-schema) when the parent owns the final gate.
- Post-merge verifier read-only boundary: [`post-merge-verifier.md`](post-merge-verifier.md) and [`post-merge-verifier/SKILL.md`](../../post-merge-verifier/SKILL.md); revision work never substitutes for verification or finish.

## Fallback to canonical docs

Fall back to the canonical docs and `gitlab-local/SKILL.md` help-first snippets on ambiguity, missing field, CLI/help drift, authority uncertainty, SHA/CI mismatch, cross-project binding, partial review, or any mutation action. The full references plus live CLI help win over this card; never treat a revision packet, parent summary, or compact handoff as independent review evidence.
