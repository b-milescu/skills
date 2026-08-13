# Finish-action card

Compact pointer map/checklist for approval and finish decisions after a durable passing Review Report. It is not an alternate policy source; canonical rules stay in [`../REVIEW-FLOW.md`](../REVIEW-FLOW.md) and the ordered [`forge` common guard](skill://forge/reference/common-guard.md).

## Checklist

| Step | Pointer | Stop / verify |
|---|---|---|
| Confirm eligibility | `forge snapshot`, [`binding and completeness`](../REVIEW-FLOW.md#binding-and-completeness), CI/Open Question tables, and approval policy. | Reviewed commit and bound CI are current; no Must Fix, `partial-review`, `secret-exposure-suspected`, or unresolved blocking question remains. |
| Verify durable report | `forge publish` readback and report template. | Final provider-native snapshot/readback matches the Review Report source and bound change request. |
| Separate authority | Approval policy, finish-authority precedence, and common guard. | Approval authority never implies finish authority; missing finish authority blocks finish only. |
| Take one action | Guarded `forge act`. | Re-run the ordered common guard immediately before exactly one authorized action; never group approval, finish, comments, or cleanup. |
| Hand off or verify | Reviewer handoff and read-only post-merge verifier. | Record provider-native action readback; post-merge verification remains separate and read-only. |

## Fallback to canonical docs

Fall back to canonical policy and the selected `/forge` provider reference on ambiguity, missing field, transport/help drift, authority uncertainty, commit/CI mismatch, cross-project binding, partial review, suspected secret exposure, grouped action pressure, or any mutation action. Never infer authority or action success from this card.
