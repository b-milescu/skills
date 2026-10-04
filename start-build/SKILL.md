---
name: start-build
description: >-
  Implements issues test-first with an early Draft change request and review
  revisions. Use for issue delivery through the invoked target's confirmed integration.
---

# Start Build

Implement one scoped issue per branch/change request by default. Operate as a
senior evidence-first developer: go deep on the assigned behavior, keep context
narrow, preserve user work, and treat every project as safety-critical unless
its rulebook says otherwise. Multiple issues require the shared
[Decoupling Contract](shared-reference/decoupling-contract.md), isolated
worktrees, and one Review Packet/gate/handoff per change request.

## Invocation modes

- **Standalone:** builder owns the local gate and ready transition, then starts a
  fresh independent reviewer. Never self-approve or self-finish.
- **Child `change-builder`:** build and maintain one Draft change request, then stop
  at the final handoff. When `Gate owner: parent`, record the parent-owned/not-run
  contract and candidate commit; the parent owns Gate Receipt and ready.
- **Revision (standalone or child):** reuse the existing source and change
  request; preserve the active mode's gate/finish ownership. Bind every finding
  to its stable report locator, originating reviewed commit, and finding ID;
  any push invalidates prior candidate-bound commit/CI/gate evidence.

Behavior-changing work follows TDD: one observable RED→GREEN slice at a time.
Docs/config/mechanical work records `TDD: N/A — <reason>` rather than fake tests.
Tests run on the project's **native test framework**: the harness its default
branch already runs through the Check Gate, CI, or a documented test command
for the changed surface's language or tool; else that language or tool's
built-in test runner, adding no dependency. When an applicable selected
specialist owns the changed surface's testing, its native-test rules, including
when to block, override this paragraph. Add cases, fixtures, fakes, and helpers where that
framework already discovers them. Committing anything it would not run (a
new runner, standalone script, harness, or test dependency) is framework
adoption and needs its own work item. When the changed surface has no native
framework, record `TDD: N/A — no native test framework` with manual dry-run
[regression evidence](SAFETY.md#behavior-touching-refactors)
and raise framework adoption as an open question.
Test at the smallest public behavior seam without coupling to internals,
whether or not an optional specialist supplies test-layer advice.

Canonical mode docs: [child](reference/child-builder.md),
[parent gate](reference/parent-owned-gate.md),
[implementation flow](reference/implementation-flow.md), and
[parent](reference/parent-orchestrator.md).

## Procedure

1. Load the project rulebook, [SAFETY.md](SAFETY.md), and
   [context-and-planning.md](reference/context-and-planning.md),
   then follow the active mode reference. Child mode reads
   [child-builder.md](reference/child-builder.md) and, when
   selected, [parent-owned-gate.md](reference/parent-owned-gate.md).
2. Invoke `forge preflight` through the target's confirmed profile/reference.
   Bind intended code/work-item/CI scopes together, canonical repository/default
   branch and operation-specific policy/identity; refresh only required systems.
   Missing/ambiguous/conflicting setup or unsupported actions block only the
   affected operation. No shared catalogue/default or silent fallback is used.
3. Read the supplied issue description and all current notes through `forge
   snapshot`; reconcile contradictions before planning. Re-read state/ownership
   immediately before work. Select [source lifecycle](reference/implementation-flow.md#source-lifecycle):
   initialize only a new source; reuse allocated worktrees and revision heads.
   Follow [Task-selected specialists](reference/context-and-planning.md#task-selected-specialists)
   before planning or edits, including standalone and revision entries.
4. Write a compact [Build Plan Packet](templates/build-plan-packet.md):
   behavior, surfaces, test plan, risks, non-goals, and loaded context. For a new
   source (including a parent allocation), push and use `forge publish` to open
   its early Draft once; for reuse/revision, update the existing change request.
   Include a Review Packet, complete Reviewer Lift, provider-native closure
   link, and quoted approval/finish provenance. Require native readback.
5. Implement vertical TDD slices. Use provider fixtures or fakes; never use live
   product/operator mutation as test evidence. Run only targeted checks during
   implementation and keep the Draft packet current.

   **Complete when:** every issue acceptance criterion is covered by a landed
   slice with a passing targeted check or marked `N/A — <why>`.
6. Before handoff, update every affected caller/test/doc/generated copy. Bind
   Reviewer Lift `Reviewed SHA`, any quoted CI observation, local gate, changed
   paths, surfaces, authorities, and delta to the current commit. Validate
   bindings and provider-specific issue closure syntax.
7. Push the final candidate and require local HEAD, remote source ref, `forge
   snapshot` current commit, Review Packet, and final handoff to agree.
8. Builder-owned mode runs the project Check Gate and uses guarded `forge act`
   for ready only when eligible. Parent-owned mode records `not-run —
   parent-owned`, leaves Draft, and hands the candidate to the parent.
9. Child mode stops. Standalone mode starts one fresh reviewer; verdict,
   approval, finish, and post-merge verification remain separate decisions.

Every `forge act` must run the
[canonical common guard](../forge/reference/common-guard.md) in its required
order at this mutation boundary. A failed mandatory phase never tries another
provider or transport; advisory CI alone does not block.

## Safety floors

[SAFETY.md](SAFETY.md) is the single owner of this pair's
safety floors — read them there rather than re-deriving them here. Its
non-negotiables and done-criteria tiers hold the line on the exact-candidate
local Gate Receipt, independent review, role boundaries, and authority
provenance. Keep scope tight and prefer the smallest direct change.

## Templates

- [delivery-schema.md](templates/delivery-schema.md) —
  `delivery.kind=change-delivery` neutral routing index.
- [reviewer-lift-schema.md](templates/reviewer-lift-schema.md)
- [review-packet.md](templates/review-packet.md)
- [builder-final-handoff.md](templates/builder-final-handoff.md)

Done is mode-tiered per [SAFETY.md](SAFETY.md#done-criteria).
