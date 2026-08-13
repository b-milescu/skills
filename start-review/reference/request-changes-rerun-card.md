# Request-changes rerun card

Compact pointer map/checklist for a fresh review after builder revision. It is not an alternate policy source; canonical rules stay in [`../REVIEW-FLOW.md`](../REVIEW-FLOW.md), finding identities, and the revision packet.

## Checklist

| Step | Pointer | Stop / verify |
|---|---|---|
| Rebind | `forge preflight`, `forge snapshot`, and [`binding and completeness`](../REVIEW-FLOW.md#binding-and-completeness). | Current change request, reviewed commit, bound CI, and isolated checkout agree. |
| Verify revision evidence | Prior Review Report, revision packet, finding identities, and Reviewer Lift delta. | Every claimed fix binds report locator, originating reviewed commit, finding ID, and current delta; claims are not proof. |
| Review full current change | [`Fail-closed review coverage`](../REVIEW-FLOW.md#fail-closed-review-coverage), Context Firewall, CI/Open Question tables, and checkout mode. | Verify every Must Fix plus new behavior surfaces; `partial-review` or `secret-exposure-suspected` blocks. |
| Publish rerun report | `forge publish` and report template. | Exactly one new Review Report; provider-native readback matches source. |
| Act or hand off | `forge snapshot`, guarded `forge act`, and reviewer handoff. | Recheck reviewed commit, bound CI, approval authority, and separate finish authority; take exactly one authorized action. |

## Fallback to canonical docs

Fall back to canonical policy, the revision packet, and the selected `/forge` provider reference on ambiguity, missing field, transport/help drift, authority uncertainty, commit/CI mismatch, cross-project binding, partial review, suspected secret exposure, grouped action pressure, or any mutation action. The ordered [`forge` common guard](skill://forge/reference/common-guard.md) wins over this card.
