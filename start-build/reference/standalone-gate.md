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
bounded target/evidence fields from the
[minimal reviewer prompt](parent-orchestrator.md#minimal-reviewer-launch-prompt).
For both initial and revision launches, deliberately select the owner rather
than copying that parent prompt's fixed `Finish owner: parent`:

- **Standalone reviewer:** set `Finish owner: reviewer`. Replace the parent
  no-action/stop instructions with publication/readback followed by only the
  independently permitted guarded action and the two-line locator handoff.
  Relay any affirmative action-specific grant and its verifiable source as a
  claim, never as builder authority. No grant means no finish; independently
  permitted approval remains subject to its own policy and guards.
- **Intentional parent handoff:** set `Finish owner: parent` and retain that
  prompt's unconditional no-action/return contract, even with a verified grant.
  A grant never selects or changes the owner.

Resolve the canonical final-reviewer role through
[native route selection](parent-orchestrator.md#native-route-selection), including
the exposed namespace and effective project/reusable source. Invoke canonical
`start-review` and `forge` at their entries through the selected runtime:
Claude `Skill` with verified native identifiers (`skills:<name>` for the reusable
plugin), or OMP skill-load/autoload and eligible `skill://` entry resolution.
Entry access, preload metadata or a raw internal-reference read is not invocation
proof; retain the Context Firewall and task-selected/user-only eligibility.
The reviewer independently verifies current/reviewed commit, exact-candidate
local Gate Receipt, publication evidence, advisory CI attribution, authority and
the `/forge` common guard. Review blockers still apply, and the builder never
approves or finishes.

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
   provider-native readback, refresh Reviewer Lift, and start a new reviewer
   under the same [reviewer launch protocol](#reviewer-launch-protocol), with an
   explicit owner and selected-runtime entry invocation. On `reject` or
   unresolved `blocked`, stop and escalate.
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
