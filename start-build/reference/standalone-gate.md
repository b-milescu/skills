# Standalone review gate

Detailed mandatory review gate for standalone `/start-build` sessions. Child
builder sessions return to their parent and do not own this gate.

## Mandatory review gate

The standalone builder starts a fresh independent reviewer through the runtime's
reviewer-launch mechanism. If none exists, stop instead of self-reviewing.
Independence comes from session/context separation, not provider identity. The
builder never self-approves or self-finishes.

## Note-deliverable review path


Analysis-only work items whose sole deliverable is a provider-published note use
the same independent-review floor against that artifact. Any repository change
uses the normal change-request path. Publish the Review Gate Summary with
`forge publish` and require provider-native readback.

## Reviewer launch protocol

After the change request is ready, start the routed final reviewer with the
minimal prompt from
[parent-orchestrator](parent-orchestrator.md#minimal-reviewer-launch-prompt):
Change request locator, Reviewer Lift pointer, project rulebook path, Context
Firewall, stop condition, finish owner, and any sourced authority grant.
Resolve the canonical final-reviewer role through
[native route selection](parent-orchestrator.md#native-route-selection), including
the exposed namespace and effective project/reusable source.
Invoke `start-review` and `forge` through the Skill tool. The reviewer independently
verifies current/reviewed commit, exact-candidate local Gate Receipt, publication
evidence, advisory CI attribution, and the `/forge` common guard.

## Timeout handling

Follow [timeout handling](timeout-handling.md) for missing or stale reviewer
completion. No fixed wall-clock value alone authorizes replacement; do not poll,
duplicate, or replace an active reviewer.

## Review loop

1. Start a fresh reviewer session.
2. Wait for one provider-published Review Report; missing output is not review
   completion and follows [timeout handling](timeout-handling.md).
3. On `pass`, keep verdict separate from approval and finish actions. On
   `request-changes`, push bounded fixes, publish one Revision Packet with
   provider-native readback, refresh Reviewer Lift, and start a new reviewer. On
   `reject` or unresolved `blocked`, stop and escalate.
4. Limit the loop to three rounds unless a human explicitly authorizes another
   bounded revision and fresh review. Record authorization provenance.

## Review Gate Summary

Publish a summary table with round, reviewer, outcome
(`pass / request-changes / reject / blocked / timeout / stale / interrupted`),
headline, stable Review Report locator, and current reviewed commit.
`timeout / stale / interrupted are non-completion states`.

## Human bypass protocol

The only accepted bypass phrases are `"skip gate"` and `"merge unreviewed"`.
Record the named human, reason, and provider-published audit locator, then set
Reviewer Lift `Review gate` to `bypassed (human override)`.
Ambiguous release language such as `ship it`, `looks fine`, or `lgtm`
does not bypass and must be clarified. A bypass never authorizes builder
self-approval or self-finish.
