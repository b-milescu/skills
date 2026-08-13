# Single change request review card

Compact pointer map/checklist for one change request per fresh reviewer. It is not an alternate policy source; canonical rules stay in [`../REVIEW-FLOW.md`](../REVIEW-FLOW.md) and [`../SKILL.md`](../SKILL.md).

## Checklist

| Step | Pointer | Stop / verify |
|---|---|---|
| Bind | `forge preflight`, `forge snapshot`, and [`binding and completeness`](../REVIEW-FLOW.md#binding-and-completeness). | Repository, change request, reviewed commit, and bound CI agree; cross-project mismatch blocks. |
| Bound context | [`Context Firewall`](../REVIEW-FLOW.md#context-firewall) and [`Review Context Capsule`](../REVIEW-FLOW.md#review-context-capsule). | Claims are not proof; broad context stays forbidden by default. |
| Cover change | [`Fail-closed review coverage`](../REVIEW-FLOW.md#fail-closed-review-coverage), CI/Open Question tables, and structural sweep. | `partial-review` and `secret-exposure-suspected` block approval and finish. |
| Publish report | `forge publish`, report template, and finding identities. | Exactly one durable Review Report; provider-native readback matches source before any action. |
| Act or hand off | Guarded `forge act`, [`publication and actions`](../REVIEW-FLOW.md#publication-and-actions), and reviewer handoff. | Re-snapshot reviewed commit, bound CI, approval authority, and separate finish authority; take exactly one authorized action. |

## Fallback to canonical docs

Fall back to canonical policy and the selected `/forge` provider reference on ambiguity, missing field, transport/help drift, authority uncertainty, commit/CI mismatch, cross-project binding, partial review, suspected secret exposure, grouped action pressure, or any mutation action. The ordered [`forge` common guard](skill://forge/reference/common-guard.md) and live provider reference win over this card.
