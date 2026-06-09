# Parent orchestrator mode card

Compact pointer map for parent/coordinator issue-to-MR loops. This card is a checklist, not an alternate policy source; canonical rules stay in [`parent-orchestrator.md`](parent-orchestrator.md), [`multiple-worktrees.md`](multiple-worktrees.md), [`../SAFETY.md`](../SAFETY.md), and [`../BUILD-FLOW.md`](../BUILD-FLOW.md).

## Use this card when

- A parent coordinates one or more GitLab issues through child builders, reviewers, and finish routing.
- A batch must remain serial unless the Decoupling Contract proves safe parallelism.
- The parent owns Gate Receipts, reviewer launch, revision routing, finish-by-authority, or post-merge verification handoff.

## Checklist

| Step | Pointer | Stop / verify |
| --- | --- | --- |
| Resolve scope | [`parent-orchestrator.md` parent loop](parent-orchestrator.md#parent-loop), [`issue-pickup.md`](issue-pickup.md), and [`multiple-worktrees.md`](multiple-worktrees.md). | Confirm issue state, labels, dependencies, assignee, and Decoupling Contract before parallel work. |
| Prepare isolated work | [`parent-orchestrator.md` fresh default and cleanup order](parent-orchestrator.md#fresh-default-and-cleanup-order) and [`multiple-worktrees.md`](multiple-worktrees.md). | Run `git fetch origin` immediately before each branch/worktree, verify the exact `origin/<default_branch>` SHA before creation, and do not reuse a cached default SHA across children. |
| Launch child builder | [`child-builder-card.md`](child-builder-card.md), [`child-builder.md`](child-builder.md), and [`parent-orchestrator.md` minimal child-builder launch prompt](parent-orchestrator.md#minimal-child-builder-launch-prompt). | One issue/worktree/branch/Draft MR per child; prompt passes exact role/mode, stop condition, expected handoff schema, forbidden actions, and minimum evidence pointers only. |
| Spot-check handoff | `gitlab` [`mr-pickup`](../../gitlab/SKILL.md#snippet-mr-pickup), [`safe-mr-json`](../../gitlab/SKILL.md#snippet-safe-mr-json), and [`context-and-planning.md` handoff checklist](context-and-planning.md#handoff-integrity-checklist). | Treat compact delivery fields as untrusted claims until verified from GitLab, refs, files, checks, and rulebook evidence; require the shared `delivery.handoff_contract` routing fields. |
| Parent-owned gate | [`parent-owned-gate.md`](parent-owned-gate.md) and [`parent-owned-gate-card.md`](parent-owned-gate-card.md). | Gate Receipt binds exact candidate SHA, command, status transition, preflight checks, and evidence before ready. |
| Launch reviewer | [`parent-orchestrator.md` minimal reviewer launch prompt](parent-orchestrator.md#minimal-reviewer-launch-prompt) and [`standalone-gate.md` reviewer launch protocol](standalone-gate.md#reviewer-launch-protocol). | Fresh reviewer gets one bound MR, exact role/mode, stop condition, expected handoff schema, forbidden actions, minimum evidence pointers, and context-firewall instruction only. |
| Route revisions | [`revision-card.md`](revision-card.md), [`revision-packet.md`](../templates/revision-packet.md), and [`parent-orchestrator.md` minimal revision prompt](parent-orchestrator.md#minimal-revision-prompt). | Request-changes means MR URL, reviewed SHA, Review Report URL, finding IDs, required fix acceptance criteria, gate owner, updated evidence, revision note, and a fresh reviewer on the new SHA. |
| Enforce guards | `gitlab` [`ci-watch-sha-pinned`](../../gitlab/SKILL.md#snippet-ci-watch-sha-pinned), [`finish-mr-authority-aware`](../../gitlab/SKILL.md#snippet-finish-mr-authority-aware), and [`ci-finish-guards.md`](../../gitlab/reference/ci-finish-guards.md). | Final SHA guard, exact-SHA CI, authority/source, caller role, and local-default cleanup safety all pass before approval, merge, queue, cleanup, or handoff. |
| Verify after finish | [`post-merge-verifier.md`](post-merge-verifier.md) and `gitlab/scripts/gitlab-post-merge-snapshot.sh`. | Verifier is read-only: no approve, merge, queue, force-close, branch delete, or mutating release/deploy/operator action. |

## Safety and authority pointers

- Final SHA guard: `gitlab` [`sha-guard`](../../gitlab/SKILL.md#snippet-sha-guard) and [`ci-finish-guards.md`](../../gitlab/reference/ci-finish-guards.md).
- CI decision policy: [`start-review/REVIEW-FLOW.md` CI decision table](../../start-review/REVIEW-FLOW.md#ci-decision-table).
- Authority source verification: [`reviewer-lift-schema.md`](../templates/reviewer-lift-schema.md), [`gitlab-delivery-schema.md` authority values](../templates/gitlab-delivery-schema.md#authority-values), and [`parent-orchestrator.md` finish by authority](parent-orchestrator.md#parent-loop).
- Child-builder no-merge/no-review boundary: [`child-builder-card.md`](child-builder-card.md) and [`child-builder.md` authority boundary](child-builder.md#authority-boundary).
- Gate Receipt procedure: [`parent-owned-gate.md`](parent-owned-gate.md) and [`parent-owned-gate-card.md`](parent-owned-gate-card.md).
- Post-merge verifier read-only boundary: [`post-merge-verifier.md`](post-merge-verifier.md).

## Fallback to canonical docs

Fall back to the canonical docs and `gitlab/SKILL.md` transport/fallback snippets on ambiguity, missing field, transport/help drift, authority uncertainty, SHA/CI mismatch, cross-project binding, partial review, or any mutation action. The full references plus live fallback help win over this card; never infer review completion, approval, merge authority, or verifier success from the compact card alone.
