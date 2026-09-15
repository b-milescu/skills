---
name: start-build
description: >-
  Implements issues test-first with an early Draft change request and review
  revisions. Use for GitLab, GitHub, or Azure DevOps issue delivery.
---

# Start Build

Implement one scoped issue per branch/change request by default. Operate as a
senior evidence-first developer: go deep on the assigned behavior, keep context
narrow, preserve user work, and treat every project as safety-critical unless
its rulebook says otherwise. Multiple issues require the shared
[Decoupling Contract](skill://start-build/docs/decoupling-contract.md), isolated
worktrees, and one Review Packet/gate/handoff per change request.

## Invocation modes

- **Standalone:** builder owns the local gate and ready transition, then starts a
  fresh independent reviewer. Never self-approve or self-finish.
- **Child `mr-builder`:** build and maintain one Draft change request, then stop
  at the final handoff. When `Gate owner: parent`, record the parent-owned/not-run
  contract and candidate commit; the parent owns Gate Receipt and ready.
- **Revision (standalone or child):** reuse the existing source and change
  request; preserve the active mode's gate/finish ownership. Bind every finding
  to its stable report locator, originating reviewed commit, and finding ID;
  any push invalidates prior candidate-bound commit/CI/gate evidence.

Behavior-changing work follows `tdd`: one observable RED→GREEN slice at a time.
Docs/config/mechanical work records `TDD: N/A — <reason>` rather than fake tests.

Canonical mode docs: [child](skill://start-build/reference/child-builder.md),
[parent gate](skill://start-build/reference/parent-owned-gate.md),
[implementation flow](skill://start-build/reference/implementation-flow.md), and
[parent](skill://start-build/reference/parent-orchestrator.md).

## Procedure

1. Load the project rulebook, [SAFETY.md](skill://start-build/SAFETY.md), and
   [context-and-planning.md](skill://start-build/reference/context-and-planning.md),
   then follow the active mode reference. Child mode reads
   [child-builder.md](skill://start-build/reference/child-builder.md) and, when
   selected, [parent-owned-gate.md](skill://start-build/reference/parent-owned-gate.md).
2. Invoke `forge preflight`. It binds provider, canonical repository, default
   branch, readiness policy, caller identity, and optional bounded discovery.
   Unknown/ambiguous/profile-mismatched providers fail closed. Generic workflow
   code does not branch on provider after this point.
3. Read the supplied issue description and all current notes through `forge
   snapshot`; reconcile contradictions before planning. Re-read state/ownership
   immediately before work. Select [source lifecycle](skill://start-build/reference/implementation-flow.md#source-lifecycle):
   initialize only a new source; reuse allocated worktrees and revision heads.
4. Write a compact [Build Plan Packet](skill://start-build/templates/build-plan-packet.md):
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

Every `forge act` runs the ordered common guard: provider/repository binding,
current target re-read, reviewed-commit binding, exact-candidate Gate Receipt,
advisory CI observation, authority provenance, caller context, safe body,
provider fallback eligibility, exactly one mutation, and provider-native
post-read. A failed mandatory phase never tries another transport.

## Safety floors

[SAFETY.md](skill://start-build/SAFETY.md) is the single owner of this pair's
safety floors — read them there rather than re-deriving them here. Its
non-negotiables and done-criteria tiers hold the line on the exact-candidate
local Gate Receipt, independent review, role boundaries, and authority
provenance. Keep scope tight and prefer the smallest direct change.

## Templates

- [delivery-schema.md](skill://start-build/templates/delivery-schema.md) —
  `delivery.kind=change-delivery` neutral routing index.
- [reviewer-lift-schema.md](skill://start-build/templates/reviewer-lift-schema.md)
- [review-packet.md](skill://start-build/templates/review-packet.md)
- [builder-final-handoff.md](skill://start-build/templates/builder-final-handoff.md)

Done is mode-tiered per [SAFETY.md](skill://start-build/SAFETY.md#done-criteria).
