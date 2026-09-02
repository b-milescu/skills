# Reviewer Final Handoff

Emit after publishing and reading back the durable Review Report. Values are
claims/indexes until the next actor verifies provider-native evidence.

Authority Verification claims use `skill://forge/reference/common-guard.md` for GitLab and the selected provider equivalent elsewhere.

Change-request locator: `<provider-native change-request locator>`
Durable note id: `<Review Report note id>`

Canonical action_blocker values: skill://start-review/reference/handoff-tokens.schema.json
  action_blocker: "none / missing-authority / changed-head-sha / merge-conflict / sha-bound-action-unsupported / preflight-failure / permission-failure / human-decision-needed / partial-review / secret-exposure-suspected / other"
  review_verdict: "pass | request-changes | reject | blocked"

When the launch prompt says `Finish owner: parent`, the reviewer publishes only
the verdict/evidence and returns approval `not-approved`, finish `none`, next
actor `parent`; it never approves or finishes.
The internal route remains `mr-reviewer-final`; the public record is a bound
change request and reviewed commit. Never combine verdict, approval, and finish.
For `secret-exposure-suspected`, describe the blocker without secret values and
use `[REDACTED]`; never copy the sensitive payload into the handoff.
