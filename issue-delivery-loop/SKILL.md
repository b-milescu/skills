---
name: issue-delivery-loop
description: >-
  Parent coordinator for bounded GitLab, GitHub, or Azure DevOps issue delivery.
  Automatically fans out provably decoupled ready items and routes builders/reviewers.
---

# Issue Delivery Loop

Coordinate a bounded ready-issue batch. Invoke `forge preflight` once, then use
the selected provider for every snapshot, publication, action, and post-merge
read. Generic callers do not branch on provider afterward.

Default: fan out every provably decoupled subset.

1. Bind provider/repository/default branch/readiness profile through `forge`.
   Read the bounded ready queue and default-branch CI health. Unknown red health
   is surfaced before fan-out; a recorded known-red baseline may proceed.
   Ready selection respects dependency ordering.
2. For a multi-item ready batch, evaluate the shared
   [Decoupling Contract](skill://issue-delivery-loop/docs/decoupling-contract.md)
   per pair before the first child launch.
   Automatically launch every provably decoupled subset in parallel. Use one child
   per item and one issue/worktree/branch/Draft change request/Review Packet per
   child. Coupled members serialize only within their coupled cluster in dependency order.
   Never serialize otherwise decoupled items. Use WIP-1 only when decoupling proof fails or is unknown, or the caller explicitly bounds WIP.
   Preserve coordinator checkout isolation;
   children must not copy auxiliary-index artifacts between worktrees.
3. Resolve the retained internal routes from the current dialect directory:
   one default `mr-builder` and one fresh `mr-reviewer-final`. Route
   basenames/model pins do not name a provider; distinct routes preserve
   child/reviewer/verifier boundaries.
4. Run the canonical parent loop from
   [parent-orchestrator.md](skill://start-build/reference/parent-orchestrator.md).
   One issue/worktree/branch/Draft change request/Review Packet per child. Pass
   explicit `Gate owner`; runtime notices never become scope stop instructions.
5. Event-driven waiting only. Read `delivery.handoff_contract` first, then verify
   its compact claims, including commit-bound CI, from provider-native Tier 1 or
   repository Tier 2 evidence while preserving reviewed-commit binding.
   Keep explicit authority provenance bound. Parent-owned candidates route
   through the parent-owned Gate Receipt contract before ready.
6. Launch independent review in parallel with CI as soon as the exact candidate
   gate contract allows; do not block-watch CI before reviewer launch. A
   failed/canceled bound CI run blocks pass/finish, never queues.
7. On reviewer pass, keep verdict, approval, and finish separate. The default
   permitted finish is `queue auto-merge`; the parent owns it when
   `Finish owner: parent`. Every mutation uses one `forge act` and provider-native post-read.
8. Treat `auto-merge queued` as pending. It does not count as **MRs merged** and
   cannot satisfy clean delivery or batch completion. Return to the event-driven
   boundary without polling CI. Provider merge-event evidence advances the
   existing handoff to phase: `post-merge-verify`,
   expected_next_actor: `verifier`, and
   expected_next_action: `post-merge-verify`; require a checked read-only
   `post_merge_snapshot.kind=post-merge-snapshot` from
   `forge post_merge_snapshot`.
9. Teardown only after every change is verified merged or blocked. Fetch and
    fast-forward default first; remove only clean worktrees/refs/branches whose
    provider result-commit and default-branch safety checks pass. Otherwise
    report `cleanup_pending`. This preserves #380 coordinator-isolation and
    cleanup ordering.

## Metrics

Report provider-qualified evidence for issues attempted, change requests opened,
merged, queued, and blocked; total/max review rounds; CI failures; brief defects;
and follow-up issues created. Use `N/A — <why>` when unobservable. Queue counts
as queued, never merged.

**`other` tokens used** — per enum field (`action_blocker` / `blocker_token` /
`not_run_reason`), the number of final handoffs (builder and reviewer) in the
batch whose field carries `other`, over the total number of final handoffs. Use
`N/A — <why>` when handoffs are unobservable.

A *brief defect* is a defect in the issue as written — a wrong baseline
observation, a stale premise, or an unsatisfiable acceptance criterion —
discovered during delivery. Count it separately from the other three root-cause
classes in the same split: a *builder defect* (the issue was sound but the work
missed it), an *evidence gap* (a claim landed without the proof it required), and
*reviewer scope creep* (the review demanded more than the issue asked). This is
the four-way root-cause split named in
[the retro signal catalogue](skill://retro/reference/signal-catalogue.md); the
definition lives here so a coordinator can count it at batch close without
loading the `retro` skill.

## Floors

Project-profile hooks may specialize labels, branches, CI jobs, docs, gate,
release/deploy, manual validation, language, or auxiliary indexes. They never
weaken the
[safety-floor litany](<../docs/effort-scaling.md#hard-floors-never-scaled-away>).
No live mutation bodies or provider commands are copied here; `forge` owns
transport selection and the provider reference owns native mechanics.

Use only the exact paths in this delivery session's session-owned worktree ledger
and follow the cleanup-order rules in
[parent-orchestrator §Fresh default and cleanup order](skill://start-build/reference/parent-orchestrator.md).
Repository-wide worktree discovery may verify a recorded path but never expands
owned cleanup scope. Retain every dirty, unknown, unmerged, or
containment-unverified entry and report `cleanup_pending` with the exact
residual session-owned worktree path.
