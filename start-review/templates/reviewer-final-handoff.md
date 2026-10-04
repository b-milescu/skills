# Reviewer Final Handoff

After publishing and reading back the durable Review Report, emit only the two
locator lines below in the final response, without a fence or additional fields.
Values are claims/indexes until the next actor verifies provider-native evidence.

Authority Verification uses the [`forge` common guard](../../forge/reference/common-guard.md) and native mechanics from the invoked target's confirmed integration reference.

Change-request locator: `<provider-native change-request locator>`
Durable note id: `<Review Report note id>`

Record verdict and action evidence in the [Review Report](review-report.md#decision-summary),
not the final. Select tokens, including `partial-review`, from the used
[workflow tokens](../reference/handoff-tokens.schema.json); native outcome mapping is target-owned, not a final payload schema.

When the launch prompt says `Finish owner: parent`, the reviewer records only
the verdict/evidence and approval `not-approved`, finish `none`, next actor
`parent` in the durable report; it never approves or finishes.
Never combine verdict, approval, and finish.
For `secret-exposure-suspected`, describe the blocker without secret values and
use `[REDACTED]`; never copy the sensitive payload into the handoff.
