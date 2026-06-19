# Child builder mode card

Compact pointer map for child `mr-builder` sessions. This card is a checklist, not an alternate policy source; canonical rules stay in [`child-builder.md`](child-builder.md), [`../SAFETY.md`](../SAFETY.md), [`../SKILL.md`](../SKILL.md), and the templates linked below.

## Use this card when

- A parent orchestrator assigns exactly one GitLab issue to a child builder.
- The builder must open or update one Draft MR and return a final handoff.
- Parent-owned gate mode may be active and the child must leave the ready transition to the parent.

## Checklist

| Step | Pointer | Stop / verify |
| --- | --- | --- |
| Bind repo and issue | `gitlab` [`local-repo-preflight`](../../gitlab/SKILL.md#snippet-local-repo-preflight), [`issue-pickup`](../../gitlab/SKILL.md#snippet-issue-pickup), and [`child-builder.md` checklist](child-builder.md#child-checklist). | Re-read issue state and assignee immediately before branch/MR work; stop on cross-project binding or changed ownership. |
| Start clean | [`implementation-flow.md` start-clean sequence](implementation-flow.md#procedure). | Empty status, latest default branch, branch name references the issue. |
| Draft handoff | `gitlab` [`draft-mr-create`](../../gitlab/SKILL.md#snippet-draft-mr-create) with `Closes #<issue>` and a Review Packet. | Draft only; do not mark ready during early or implementation pushes. |
| Build and evidence | [`SAFETY.md` TDD/safety rules](../SAFETY.md#non-negotiables), [`context-and-planning.md` handoff checklist](context-and-planning.md#handoff-integrity-checklist). | Behavior changes need TDD; docs/config/mechanical work records `TDD: N/A` with rationale. |
| Reviewer Lift | [`reviewer-lift-schema.md`](../templates/reviewer-lift-schema.md) and `gitlab` [`mr-description-update`](../../gitlab/SKILL.md#snippet-mr-description-update). | Every row stays current; authority is a quoted claim with a verifiable source. |
| Final SHA guard | `gitlab` [`mr-pickup`](../../gitlab/SKILL.md#snippet-mr-pickup), [`sha-guard`](../../gitlab/SKILL.md#snippet-sha-guard), and [`child-builder.md` final push rule](child-builder.md#child-checklist). | Final handoff `head_sha`, `reviewed_sha`, and candidate SHA name the current MR head. |
| Return handoff | [`builder-final-handoff.md`](../templates/builder-final-handoff.md). | Child builder stops after handoff; parent owns review, approval, finish, cleanup, and post-merge verification. |

## Safety and authority pointers

- Child no-review/no-merge boundary: [`child-builder.md` authority boundary](child-builder.md#authority-boundary) and [`standalone-gate.md` mandatory review gate](standalone-gate.md#mandatory-review-gate).
- Parent-owned Gate Receipt contract: [`parent-owned-gate.md`](parent-owned-gate.md) and [`parent-owned-gate-card.md`](parent-owned-gate-card.md).
- CI decision policy: [`start-review/REVIEW-FLOW.md` CI decision table](../../start-review/REVIEW-FLOW.md#ci-decision-table).
- Authority source verification: [`reviewer-lift-schema.md`](../templates/reviewer-lift-schema.md) and [`context-and-planning.md` handoff checklist](context-and-planning.md#handoff-integrity-checklist).
- Post-merge verifier read-only boundary: [`post-merge-verifier.md`](post-merge-verifier.md); child builders never perform verifier, cleanup, or finish mutations.

## Fallback to canonical docs

Fall back to the canonical docs and `gitlab/SKILL.md` transport/fallback snippets on ambiguity, missing field, transport/help drift, authority uncertainty, SHA/CI mismatch, cross-project binding, partial review, or any mutation action beyond the child builder's assigned Draft MR update path. The full references plus live fallback help win over this card.
