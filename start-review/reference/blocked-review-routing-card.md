# Blocked review routing card

Compact pointer map/checklist for fail-closed review outcomes. It is not an alternate policy source; canonical rules stay in [`../REVIEW-FLOW.md`](../REVIEW-FLOW.md) and the Review Report/handoff templates.

## Checklist

| Step | Pointer | Stop / verify |
|---|---|---|
| Bind blocker | `forge preflight`, `forge snapshot`, binding/completeness, CI/Open Question tables, and authority policy. | Record one stable blocker against the bound change request and reviewed commit. |
| Preserve context boundary | Context Firewall and Review Context Capsule. | Parent/builder reasoning and prior artifacts remain claims until verified. |
| Fail closed | [`Fail-closed review coverage`](../REVIEW-FLOW.md#fail-closed-review-coverage). | `partial-review` never approves a visible subset; `secret-exposure-suspected` uses `[REDACTED]` and security escalation. |
| Publish blocked report | `forge publish` and report template. | Exactly one blocked Review Report; final provider-native snapshot/readback records available commit, CI, authority, and publication evidence. |
| Route next action | Reviewer handoff and request-changes rerun card. | No approval or finish; route wait, fix, fresh review, or human decision without grouped actions. |

## Fallback to canonical docs

Fall back to canonical policy and the selected `/forge` provider reference on ambiguity, missing field, transport/help drift, authority uncertainty, commit/CI mismatch, cross-project binding, partial review, suspected secret exposure, grouped action pressure, or any mutation action. The ordered [`forge` common guard](skill://forge/reference/common-guard.md) and live provider reference win over this card.
