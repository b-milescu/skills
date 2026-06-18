# Request-changes rerun card

Compact pointer map for reviewing a builder revision after a prior Review Report requested changes. This card is a checklist, not an alternate policy source; canonical rules stay in [`../REVIEW-FLOW.md`](../REVIEW-FLOW.md), [`../SKILL.md`](../SKILL.md), revision packets, and the GitLab-local cards linked below.

## Use this card when

- A builder pushed a revision after `request-changes`.
- The parent asks for a fresh review round on the same MR.
- You must verify the revision without treating the earlier reviewer or builder response as proof.

## Canonical anchors

- Context firewall and context tiers: [`../REVIEW-FLOW.md#context-firewall`](../REVIEW-FLOW.md#context-firewall).
- Review Context Capsule and safety-critical verification: [`../REVIEW-FLOW.md#review-context-capsule`](../REVIEW-FLOW.md#review-context-capsule).
- Fail-closed coverage for `partial-review` and `secret-exposure-suspected`: [`../REVIEW-FLOW.md#fail-closed-review-coverage`](../REVIEW-FLOW.md#fail-closed-review-coverage).
- CI policy: [`../REVIEW-FLOW.md#ci-decision-table`](../REVIEW-FLOW.md#ci-decision-table).
- Open Question policy: [`../REVIEW-FLOW.md#open-question-decision-table`](../REVIEW-FLOW.md#open-question-decision-table).
- Approval authority policy: [`../REVIEW-FLOW.md#approval-authority-policy`](../REVIEW-FLOW.md#approval-authority-policy); merge authority source precedence: [`../REVIEW-FLOW.md#merge-authority-source-precedence`](../REVIEW-FLOW.md#merge-authority-source-precedence).
- Project binding rules: [`../REVIEW-FLOW.md#project-binding`](../REVIEW-FLOW.md#project-binding).
- Revision handoff shape: [`../../start-build/templates/revision-packet.md`](../../start-build/templates/revision-packet.md) and [`../../start-build/reference/child-builder-card.md`](../../start-build/reference/child-builder-card.md).

## Checklist

| Step | Pointer | Stop / verify |
| --- | --- | --- |
| Re-bind MR and current head | `gitlab` [`review-read`](../../gitlab/reference/review-read.md), **Snippet: local-repo-preflight**, and **Snippet: mr-pickup**. | Re-read one bound MR record; if head changed from the previous reviewed SHA, the new head is the review target only after you inspect its delta. |
| Read revision evidence | Prior Review Report, revision packet/comment, Reviewer Lift `Delta since last ready push`, and [`Review Context Capsule`](../REVIEW-FLOW.md#review-context-capsule). | Treat the builder's MF/SF/C responses as claims. Missing, stale, or ambiguous revision evidence is an evidence gap, not approval evidence. |
| Review the delta and still cover the MR | `gitlab` **Snippet: artifact-capture**, [`Fail-closed review coverage`](../REVIEW-FLOW.md#fail-closed-review-coverage), and [`Single MR checkout mode`](../REVIEW-FLOW.md#single-mr-checkout-mode) when local execution is needed. | Verify every Must Fix is addressed and no new behavior-affecting surface escapes review. If tool limits or opaque artifacts prevent full coverage, use `Action blocker: partial-review`. |
| Re-classify CI, OQs, local gate, and authority | `gitlab` [`ci`](../../gitlab/reference/ci.md), **Snippet: ci-decision-snapshot**, [`CI decision table`](../REVIEW-FLOW.md#ci-decision-table), [`Open Question decision table`](../REVIEW-FLOW.md#open-question-decision-table), [`Approval authority policy`](../REVIEW-FLOW.md#approval-authority-policy), and [`Merge authority source precedence`](../REVIEW-FLOW.md#merge-authority-source-precedence). | The pass path requires exact-SHA CI eligibility, verified approval authority source, all `OQ-N` handled, and local gate/Gate Receipt evidence bound to the reviewed SHA; finish additionally requires verified merge authority source. |
| Draft rerun Review Report then snapshot | [`../templates/review-report.md`](../templates/review-report.md) and [`Procedure`](../REVIEW-FLOW.md#procedure). | Draft one fresh Review Report for this round, then take the final MR/CI/authority snapshot before posting; convert to `blocked` if the snapshot fails. |
| Post act only allowed | `gitlab` [`review-actions`](../../gitlab/reference/review-actions.md), **Snippet: mr-note-create**, **Snippet: sha-guard**, SHA-bound action snippets. | Validate body with `validate_gitlab_text` or safe note embedded validation, then post one top-level plain non-resolvable MCP-safe Review Report MR note for the bound MR via `safe_create_merge_request_note`; never bypass `safe_create_merge_request_note` with ad hoc unsafe inline note strings. Read back created note body matches report source before counts posted; placeholder/partial/literal-expansion/body-mismatch notes fail closed. Re-run fresh `sha-guard` immediately before approval, immediately before direct merge, and immediately before auto-merge queue. Choose one action; never group approval/merge, auto-merge, or notes. |
| Handoff | [`../templates/reviewer-final-handoff.md`](../templates/reviewer-final-handoff.md). | Final handoff names the reviewed revision SHA, finding IDs resolved/remaining, action blocker, and next action. |

## Fallback to canonical docs

Fall back to the full [`../REVIEW-FLOW.md`](../REVIEW-FLOW.md), [`../../start-build/templates/revision-packet.md`](../../start-build/templates/revision-packet.md), and [`../../gitlab/SKILL.md`](../../gitlab/SKILL.md) on ambiguity, missing field, transport/help drift, authority uncertainty, SHA/CI mismatch, cross-project binding, partial review, suspected secret exposure, grouped action pressure, or any mutation action. The full references plus live fallback help win over this card.
