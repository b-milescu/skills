# Finish-action card

Compact pointer map for approval and finish decisions after a Review Report has been drafted or posted. This card is a checklist, not an alternate policy source; canonical rules stay in [`../REVIEW-FLOW.md`](../REVIEW-FLOW.md), [`../SKILL.md`](../SKILL.md), and the GitLab-local action cards/helpers linked below.

## Use this card when

- A Review Report is ready to post with `pass`, or has already been posted for the current reviewed SHA.
- Explicit authority may allow approval, direct merge, auto-merge queueing, approval-only stop, or human-release stop.
- You need to keep approval and finish side effects separate, SHA-bound, and one action at a time.

## Canonical anchors

- Context firewall and context tiers: [`../REVIEW-FLOW.md#context-firewall`](../REVIEW-FLOW.md#context-firewall).
- Review Context Capsule and safety-critical verification: [`../REVIEW-FLOW.md#review-context-capsule`](../REVIEW-FLOW.md#review-context-capsule).
- Fail-closed coverage for `partial-review` and `secret-exposure-suspected`: [`../REVIEW-FLOW.md#fail-closed-review-coverage`](../REVIEW-FLOW.md#fail-closed-review-coverage).
- CI policy: [`../REVIEW-FLOW.md#ci-decision-table`](../REVIEW-FLOW.md#ci-decision-table).
- Open Question policy: [`../REVIEW-FLOW.md#open-question-decision-table`](../REVIEW-FLOW.md#open-question-decision-table).
- Authority source precedence: [`../REVIEW-FLOW.md#authority-source-precedence`](../REVIEW-FLOW.md#authority-source-precedence).
- Project binding rules: [`../REVIEW-FLOW.md#project-binding`](../REVIEW-FLOW.md#project-binding).
- Finish helper and post-merge boundary: [`../../gitlab-local/reference/ci-finish-guards.md`](../../gitlab-local/reference/ci-finish-guards.md) and [`../../start-build/reference/post-merge-verifier.md`](../../start-build/reference/post-merge-verifier.md).

## Checklist

| Step | Pointer | Stop / verify |
| --- | --- | --- |
| Verify report eligibility | [`Procedure`](../REVIEW-FLOW.md#procedure), [`Decisions`](../REVIEW-FLOW.md#decisions), and [`../templates/review-report.md`](../templates/review-report.md). | `pass` requires no Must Fix, no `partial-review`, no `secret-exposure-suspected`, pass-eligible CI/OQ state, project binding, reviewed SHA equality, and verified authority source. |
| Take final snapshot before posting | `gitlab-local` [`review-read`](../../gitlab-local/reference/review-read.md), [`ci`](../../gitlab-local/reference/ci.md), **Snippet: mr-pickup**, and **Snippet: ci-decision-snapshot**. | Final MR/CI/authority snapshot happens before posting the Review Report; stale/missing/red CI, changed head, missing authority, or project mismatch converts the report to `blocked`. |
| Post exactly one report | `gitlab-local` [`review-actions`](../../gitlab-local/reference/review-actions.md) and **Snippet: mr-note-create**. | One top-level Review Report per MR; no grouped Review Reports or action-result notes across MRs. |
| Approval action, if authorized | [`Authority source precedence`](../REVIEW-FLOW.md#authority-source-precedence), **Snippet: sha-guard**, **Snippet: sha-bound-approval**, and **Snippet: approval-confirmation** when needed. | After posting, re-run a fresh `sha-guard` immediately before approval. If the SHA changed or authority/source is missing, skip approval and route `changed-head-sha` or `missing-authority`. |
| Direct merge, if authorized | [`CI decision table`](../REVIEW-FLOW.md#ci-decision-table), **Snippet: sha-guard**, **Snippet: sha-bound-merge**, and **Snippet: finish-mr-authority-aware** when the helper fits. | Re-run a fresh `sha-guard` immediately before direct merge; direct merge needs exact-SHA green/waived CI and direct-merge authority. |
| Auto-merge queue, if authorized | [`CI decision table`](../REVIEW-FLOW.md#ci-decision-table), **Snippet: sha-guard**, **Snippet: sha-bound-auto-merge-queue**, **Snippet: auto-merge-api-fallback**, and **Snippet: finish-mr-authority-aware** when the helper fits. | Re-run a fresh `sha-guard` immediately before auto-merge queue; queue only with verified `queue auto-merge` authority and protected-merge policy confidence. |
| Keep actions separate | `gitlab-local` [`review-actions`](../../gitlab-local/reference/review-actions.md) and [`Multiple MR worktree mode`](../REVIEW-FLOW.md#multiple-mr-worktree-mode). | Approval, direct merge, auto-merge queueing, approval confirmation, and finish helper calls are separate decisions. Choose one action per authorization point; never group approval/merge, auto-merge, comments, or finish actions across MRs. |
| Handoff or read-only verification | [`../templates/reviewer-final-handoff.md`](../templates/reviewer-final-handoff.md) and [`../../start-build/reference/post-merge-verifier.md`](../../start-build/reference/post-merge-verifier.md). | Reviewer/authorized parent records action result. Post-merge verification is read-only and belongs to its own role. |

## Fallback to canonical docs

Fall back to the full [`../REVIEW-FLOW.md`](../REVIEW-FLOW.md), [`../../gitlab-local/SKILL.md`](../../gitlab-local/SKILL.md), and [`../../gitlab-local/reference/ci-finish-guards.md`](../../gitlab-local/reference/ci-finish-guards.md) on ambiguity, missing field, CLI/help drift, authority uncertainty, SHA/CI mismatch, cross-project binding, partial review, suspected secret exposure, grouped action pressure, permission failure, helper/API drift, or any mutation action. The full references plus live CLI help win over this card.
