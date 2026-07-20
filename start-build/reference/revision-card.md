# Revision mode card

Compact pointer map for builder revision work after review feedback or a substantive post-ready push. This card is a checklist, not an alternate policy source; canonical rules stay in [`implementation-flow.md`](implementation-flow.md#procedure), [`standalone-gate.md`](standalone-gate.md#review-loop), [`parent-orchestrator.md`](parent-orchestrator.md#parent-loop), and [`../templates/revision-packet.md`](../templates/revision-packet.md).

## Use this card when

- A reviewer or parent returns request-changes findings tied to a reviewed SHA.
- A post-ready change is needed and the reviewer must not rely on stale evidence.
- A child builder is asked to revise an existing Draft/ready MR and return to the parent.

## Checklist

| Step | Pointer | Stop / verify |
| --- | --- | --- |
| Bind review inputs | `gitlab` [`mr-pickup`](../../gitlab/SKILL.md#snippet-mr-pickup), [`sha-guard`](../../gitlab/SKILL.md#snippet-sha-guard), [`standalone-gate.md` review loop](standalone-gate.md#review-loop), [`parent-orchestrator.md` minimal revision prompt](parent-orchestrator.md#minimal-revision-prompt), and [`start-review/reference/finding-identities.md`](../../start-review/reference/finding-identities.md). | Every finding must carry its stable report locator, originating reviewed SHA, and short ID; Must Fix items must also be revision-ready (`path + line/range + concrete problem + bounded remedy direction`) or else stay blocked as `human-decision-needed`. |
| Implement fixes | [`implementation-flow.md` revision step](implementation-flow.md#procedure) and [`SAFETY.md` behavior-touching refactor rules](../SAFETY.md#behavior-touching-refactors). | Fix commits name review item IDs where applicable; behavior-touching fixes get targeted regression evidence. |
| Rerun evidence | [`context-and-planning.md` handoff checklist](context-and-planning.md#handoff-integrity-checklist) and the project's Check Gate doc (`project_profile.gate_policy_ref`). | Targeted checks cover each finding; full gate ownership follows the active mode, with parent-owned ownership from [`parent-owned-gate.md`](parent-owned-gate.md) when delegated. |
| Post revision packet | [`revision-packet.md`](../templates/revision-packet.md), [`finding-identities.md`](../../start-review/reference/finding-identities.md), and `gitlab` [`mr-note-create`](../../gitlab/SKILL.md#snippet-mr-note-create). | Repeat each exact `(Report locator, Reviewed SHA, Finding ID)` and pass `validate-finding-bindings.mjs` before publication; bare, missing, stale, ambiguous, or contradictory bindings stop. |
| Refresh MR handoff | `gitlab` [`mr-description-update`](../../gitlab/SKILL.md#snippet-mr-description-update), [`reviewer-lift-schema.md`](../templates/reviewer-lift-schema.md), and `delivery.handoff_contract` from the builder final handoff. | `Reviewed SHA`, Finding bindings, CI row, Local gate row, Changed paths, Delta since last ready push, and the returned routing contract reflect the new MR head. |
| Return control | [`child-builder.md` final handoff](child-builder.md#child-checklist) or [`standalone-gate.md` fresh reviewer rule](standalone-gate.md#review-loop). | Child mode stops for parent with the exact expected handoff; standalone mode starts a fresh reviewer session instead of reusing stale approval. |

## Safety and authority pointers

- Final SHA guard: `gitlab` [`sha-guard`](../../gitlab/SKILL.md#snippet-sha-guard) and [`ci-decision-snapshot`](../../gitlab/SKILL.md#snippet-ci-decision-snapshot).
- CI decision policy: [`start-review/REVIEW-FLOW.md` CI decision table](../../start-review/REVIEW-FLOW.md#ci-decision-table).
- Authority source verification: [`reviewer-lift-schema.md`](../templates/reviewer-lift-schema.md) and [`parent-orchestrator.md` finish by authority](parent-orchestrator.md#parent-loop).
- Child no-review/no-merge boundary: [`child-builder.md` authority boundary](child-builder.md#authority-boundary).
- Gate Receipt procedure: [`parent-owned-gate.md`](parent-owned-gate.md) and [`parent-owned-gate-card.md`](parent-owned-gate-card.md) when the parent owns the final gate.
- Post-merge verifier read-only boundary: [`post-merge-verifier.md`](post-merge-verifier.md); revision work never substitutes for verification or finish.

## Fallback to canonical docs

Fall back to the canonical docs and `gitlab/SKILL.md` transport/fallback snippets on ambiguity, missing field, transport/help drift, authority uncertainty, SHA/CI mismatch, cross-project binding, partial review, or any mutation action. The full references plus live fallback help win over this card; never treat a revision packet, parent summary, or compact handoff as independent review evidence.
