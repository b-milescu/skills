# Blocked review routing card

Compact pointer map for fail-closed review outcomes. This card is a checklist, not an alternate policy source; canonical rules stay in [`../REVIEW-FLOW.md`](../REVIEW-FLOW.md), [`../SKILL.md`](../SKILL.md), the Review Report template, and the GitLab-local cards linked below.

## Use this card when

- A guard/tool/authority/security state prevents safe approval or finish without deciding that the code is fixable or invalid.
- The review must post a blocked Review Report and route next action cleanly.
- You need stable `Action blocker` and `Next action` values for a parent coordinator.

## Canonical anchors

- Context firewall and context tiers: [`../REVIEW-FLOW.md#context-firewall`](../REVIEW-FLOW.md#context-firewall).
- Review Context Capsule and safety-critical verification: [`../REVIEW-FLOW.md#review-context-capsule`](../REVIEW-FLOW.md#review-context-capsule).
- Fail-closed coverage for `partial-review` and `secret-exposure-suspected`: [`../REVIEW-FLOW.md#fail-closed-review-coverage`](../REVIEW-FLOW.md#fail-closed-review-coverage).
- CI policy: [`../REVIEW-FLOW.md#ci-decision-table`](../REVIEW-FLOW.md#ci-decision-table).
- Open Question policy: [`../REVIEW-FLOW.md#open-question-decision-table`](../REVIEW-FLOW.md#open-question-decision-table).
- Approval authority policy: [`../REVIEW-FLOW.md#approval-authority-policy`](../REVIEW-FLOW.md#approval-authority-policy); merge authority source precedence: [`../REVIEW-FLOW.md#merge-authority-source-precedence`](../REVIEW-FLOW.md#merge-authority-source-precedence).
- Project binding rules: [`../REVIEW-FLOW.md#project-binding`](../REVIEW-FLOW.md#project-binding).
- Parent/builder boundary for rerouting: [`../../start-build/reference/child-builder-card.md`](../../start-build/reference/child-builder-card.md) and [`../templates/reviewer-final-handoff.md`](../templates/reviewer-final-handoff.md).

## Checklist

| Step | Pointer | Stop / verify |
| --- | --- | --- |
| Identify blocker class | [`Decisions`](../REVIEW-FLOW.md#decisions), [`Fail-closed review coverage`](../REVIEW-FLOW.md#fail-closed-review-coverage), [`CI decision table`](../REVIEW-FLOW.md#ci-decision-table), and [`Open Question decision table`](../REVIEW-FLOW.md#open-question-decision-table). | Use one stable blocker token: `missing-authority`, `stale-or-missing-ci`, `changed-head-sha`, `sha-bound-action-unsupported`, `preflight-failure`, `permission-failure`, `human-decision-needed`, `partial-review`, `secret-exposure-suspected`, or `other`. |
| Preserve evidence boundary | [`Context Firewall`](../REVIEW-FLOW.md#context-firewall) and [`Review Context Capsule`](../REVIEW-FLOW.md#review-context-capsule). | Parent/builder reasoning, Gate Receipts, compact delivery fields, and prior reports remain claims unless verified from Tier 1/Tier 2 evidence. |
| Fail closed on partial review | [`Fail-closed review coverage`](../REVIEW-FLOW.md#fail-closed-review-coverage). | If every behavior-affecting changed surface cannot be inspected, do not approve the visible subset; use `Action blocker: partial-review` or request a split/evidence fix when builder action can resolve it. |
| Fail closed on suspected secret exposure | [`Fail-closed review coverage`](../REVIEW-FLOW.md#fail-closed-review-coverage) and [`../templates/review-report.md`](../templates/review-report.md). | Do not quote secret or credential values. Redact with `[REDACTED]` plus safe path/artifact locator and use `Action blocker: secret-exposure-suspected`. |
| Snapshot before posting | `gitlab-local` [`review-read`](../../gitlab-local/reference/review-read.md), [`ci`](../../gitlab-local/reference/ci.md), **Snippet: mr-pickup**, and **Snippet: ci-decision-snapshot**. | Even blocked reports need a final MR/CI/authority snapshot before posting when tooling permits; if the snapshot itself fails, record the exact preflight/project/CI/authority blocker. |
| Post blocked report | `gitlab-local` [`review-actions`](../../gitlab-local/reference/review-actions.md) and **Snippet: mr-note-create**. | Post one blocked Review Report to the bound MR; no approval, direct merge, auto-merge queue, close-equivalent action, grouped action, or hidden finish action follows a blocked verdict. Never group blocked reports or action notes across MRs. |
| If state changes before any later action | **Snippet: sha-guard**, [`request-changes-rerun-card.md`](request-changes-rerun-card.md), and [`finish-action-card.md`](finish-action-card.md). | Any future approval, direct merge, or auto-merge queue needs a fresh review/pass path and a fresh `sha-guard` immediately before that exact action. |
| Handoff | [`../templates/reviewer-final-handoff.md`](../templates/reviewer-final-handoff.md). | Final handoff repeats `review_verdict: blocked`, the blocker token, bound MR/project, reviewed/current SHA if known, and next action. |

## Routing hints

| Blocker | Typical next action |
| --- | --- |
| `missing-authority` | `human-escalation` or parent-provided authority source. |
| `stale-or-missing-ci` | `wait-ci` or builder/parent fixes CI evidence. |
| `changed-head-sha` | `rerun-review` on the current head. |
| `partial-review` | `fix-blocker`, split MR, add provenance/evidence, or rerun with enough context. |
| `secret-exposure-suspected` | `human-escalation` for security handling; remove, rotate/revoke, and purge per project policy without copying the secret. |
| `preflight-failure`, `permission-failure`, `sha-bound-action-unsupported`, or `other` | `fix-blocker` or parent/human tooling decision. |

## Fallback to canonical docs

Fall back to the full [`../REVIEW-FLOW.md`](../REVIEW-FLOW.md) and [`../../gitlab-local/SKILL.md`](../../gitlab-local/SKILL.md) on ambiguity, missing field, CLI/help drift, authority uncertainty, SHA/CI mismatch, cross-project binding, partial review, suspected secret exposure, grouped action pressure, security uncertainty, or any mutation action. The full references plus live CLI help win over this card.
