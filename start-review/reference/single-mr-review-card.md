# Single MR review card

Compact pointer map for the default `/start-review` path: one MR, one fresh reviewer session, one Review Report. This card is a checklist, not an alternate policy source; canonical rules stay in [`../REVIEW-FLOW.md`](../REVIEW-FLOW.md), [`../SKILL.md`](../SKILL.md), the Review Report template, and the GitLab-local cards linked below.

## Use this card when

- A human, parent orchestrator, or standalone builder supplies exactly one MR URL, IID, or source branch.
- The review can stay in one fresh reviewer session and one project-bound checkout/worktree.
- You need the short path without losing the full review guards.

## Canonical anchors

- Context firewall and context tiers: [`../REVIEW-FLOW.md#context-firewall`](../REVIEW-FLOW.md#context-firewall).
- Review Context Capsule and safety-critical verification: [`../REVIEW-FLOW.md#review-context-capsule`](../REVIEW-FLOW.md#review-context-capsule).
- Fail-closed coverage for `partial-review` and `secret-exposure-suspected`: [`../REVIEW-FLOW.md#fail-closed-review-coverage`](../REVIEW-FLOW.md#fail-closed-review-coverage).
- CI policy: [`../REVIEW-FLOW.md#ci-decision-table`](../REVIEW-FLOW.md#ci-decision-table).
- Open Question policy: [`../REVIEW-FLOW.md#open-question-decision-table`](../REVIEW-FLOW.md#open-question-decision-table).
- Approval authority policy: [`../REVIEW-FLOW.md#approval-authority-policy`](../REVIEW-FLOW.md#approval-authority-policy); merge authority source precedence: [`../REVIEW-FLOW.md#merge-authority-source-precedence`](../REVIEW-FLOW.md#merge-authority-source-precedence).
- Project binding rules: [`../REVIEW-FLOW.md#project-binding`](../REVIEW-FLOW.md#project-binding).
- Child-builder boundary / builder claims are not review proof: [`../../start-build/reference/child-builder-card.md`](../../start-build/reference/child-builder-card.md) and [`../REVIEW-FLOW.md#context-firewall`](../REVIEW-FLOW.md#context-firewall).

## Checklist

| Step | Pointer | Stop / verify |
| --- | --- | --- |
| Bind repo and MR | `gitlab` [`review-read`](../../gitlab/reference/review-read.md), **Snippet: local-repo-preflight**, **Snippet: mr-pickup**, and [`Project binding`](../REVIEW-FLOW.md#project-binding). | Bound host, project path, repo URL, IID, source, target, and current SHA match the supplied MR and preflight repo; cross-project mismatch blocks unless explicitly chosen. |
| Read Tier 1 evidence | **Snippet: issue-pickup**, **Snippet: mr-pickup**, MR description, Reviewer Lift, linked issue, project rulebook, and [`Review Context Capsule`](../REVIEW-FLOW.md#review-context-capsule). | Treat parent/builder reasoning, Gate Receipts, and compact delivery fields as claims; verify safety-critical fields from Tier 1/Tier 2 sources. |
| Verify head, CI, OQs, and local gate | `gitlab` [`ci`](../../gitlab/reference/ci.md), **Snippet: ci-decision-snapshot**, [`CI decision table`](../REVIEW-FLOW.md#ci-decision-table), [`Open Question decision table`](../REVIEW-FLOW.md#open-question-decision-table), and the parent-run `skill://start-build/scripts/validate-gate-receipt.mjs` result with `--gate-receipt-note-id "<current Gate Receipt note ID>"` when local gate ownership is parent-owned. | MR head equals `Reviewed SHA`; exact-SHA CI is pass-eligible or explicitly blocked/waived; every `OQ-N` is classified; parent Gate Receipt and synchronized Reviewer Lift passed the canonical validator against that exact current note before ready-marking. |
| Review diff and evidence | `gitlab` **Snippet: artifact-capture**, [`Fail-closed review coverage`](../REVIEW-FLOW.md#fail-closed-review-coverage), [`Structural maintainability sweep`](../REVIEW-FLOW.md#structural-maintainability-sweep), and the Reviewer Focus row. | Do not partially approve a diff. `partial-review` and `secret-exposure-suspected` block approval/finish; secret values are never quoted. |
| Draft report then snapshot | [`../templates/review-report.md`](../templates/review-report.md), [`finding-identities.md`](finding-identities.md), and [`Procedure`](../REVIEW-FLOW.md#procedure). | Choose one stable report locator, bind every short finding ID to it and the exact reviewed SHA, pass `validate-finding-bindings.mjs`, then take the final MR/CI/authority snapshot; if any final guard fails, convert the report to `blocked` before posting. |
| Post act only allowed | `gitlab` [`review-actions`](../../gitlab/reference/review-actions.md), **Snippet: mr-note-create**, **Snippet: sha-guard**, **Snippet: sha-bound-approval**, **Snippet: sha-bound-merge**, **Snippet: sha-bound-auto-merge-queue**. | Validate body with `validate_gitlab_text` or safe note embedded validation, then post one top-level plain non-resolvable MCP-safe Review Report MR note for one bound MR via `safe_create_merge_request_note`; never bypass `safe_create_merge_request_note` with ad hoc unsafe inline note strings. Read back created note body matches report source before counts posted; placeholder/partial/literal-expansion/body-mismatch notes fail closed. Re-run fresh `sha-guard` immediately before approval, immediately before direct merge, and immediately before auto-merge queue. Choose one action; never group approval/merge, auto-merge, or notes. |
| Handoff | [`../templates/reviewer-final-handoff.md`](../templates/reviewer-final-handoff.md). | Final handoff exposes the same stable report locator and reviewed SHA, repeats both beside every short finding ID, and mirrors the Review Report verdict/action fields plus any post-report action result; missing report/action state stays explicit, never invented. |

## Fallback to canonical docs

Fall back to the full [`../REVIEW-FLOW.md`](../REVIEW-FLOW.md) on ambiguity, missing field, authority uncertainty, SHA/CI mismatch, cross-project binding, partial review, suspected secret exposure, or grouped action pressure, and fall back to [`../../gitlab/SKILL.md`](../../gitlab/SKILL.md) on transport/help drift. For any mutation action — posting the Review Report, approving, merging, or queueing auto-merge — read the named canonical anchors instead of the whole flow: [`#approval-authority-policy`](../REVIEW-FLOW.md#approval-authority-policy), [`#merge-authority-source-precedence`](../REVIEW-FLOW.md#merge-authority-source-precedence), [`#ci-decision-table`](../REVIEW-FLOW.md#ci-decision-table), [`#fail-closed-review-coverage`](../REVIEW-FLOW.md#fail-closed-review-coverage), [`#context-firewall`](../REVIEW-FLOW.md#context-firewall), and the [`#procedure`](../REVIEW-FLOW.md#procedure) action steps (13–19); on any ambiguity in the mutation path, fall back to the full file. The full references plus live fallback help win over this card.
