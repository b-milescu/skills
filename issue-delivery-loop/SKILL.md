---
name: issue-delivery-loop
description: >-
  Parent coordinator for bounded GitLab, GitHub, or Azure DevOps issue delivery:
  fans out decoupled ready items and routes builders/reviewers.
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
   Leave specialist selection to the build/review entries under
   [Task-selected specialists](skill://start-build/reference/context-and-planning.md#task-selected-specialists).
   Fresh-reviewer prompts prescribe neither specialist names nor internal-reference hints.
4. Run the canonical parent loop from
   [parent-orchestrator.md](skill://start-build/reference/parent-orchestrator.md).
   Pass explicit `Gate owner`; runtime notices never become scope stop instructions.
5. Event-driven waiting only. Follow
   [wait cadence](skill://start-build/reference/parent-orchestrator.md#wait-cadence).
   Reviewer replacement cites
   [reviewer launch timing](skill://start-build/reference/parent-orchestrator.md#reviewer-launch-timing)
   rather than restating its published-report precondition.
   Consume builder/reviewer two-line native locator handoffs, then apply
   [stage-correct verification](skill://start-build/reference/parent-owned-gate.md#stage-correct-handoff-verification)
   at the applicable stage. Other compact delivery indexes retain
   `handoff_contract`, but finals need no delivery block.
6. Launch independent review as soon as the exact-candidate gate contract
   allows. Provider CI may run in parallel; no CI status changes verdict,
   approval, or finish eligibility.
7. On reviewer pass, keep verdict, approval, and finish separate. The default
   permitted finish is `queue auto-merge`; the parent owns it when
   `Finish owner: parent`. Every mutation uses one `forge act` and provider-native post-read.
   Immediately before that finish, use fresh `forge snapshot` evidence to re-read
   the allocated work item and require it to remain open. Verify that the current
   change request, source branch, and work-item relationship match the parent's
   recorded allocation in its session-owned worktree ledger, using the project
   profile's branch policy and the selected provider's native relationship/closure
   checks. Missing or contradictory evidence blocks finish; do not rediscover the
   allocated item by parsing the branch or selecting another open linked item.
   A `pass` whose Review
   Report lists surviving `SF` findings gets one filed follow-up issue per finding,
   referenced from the finish note, before the merge is queued. Before writing
   that follow-up's acceptance criteria, re-derive the finding's load-bearing
   measurement on the current default branch and write the criteria against that
   measurement rather than the report's prose. That is one measurement, not a
   re-review: keep the original verdict; do not re-read the diff or launch a
   second reviewer. If the re-derivation contradicts the finding, the follow-up
   records the contradiction instead of inheriting it.
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
batch whose field carries `other`, over the total number of final handoffs.
Resolve field values from verified durable Review Report / Review Packet
evidence or a supported compact delivery index, matched to that handoff and
its candidate; compact-index claims require native evidence verification.
Count repeated handoffs separately, not unique changes or evidence artifacts;
multiple sources for one handoff do not add counts. Locator-only finals locate
evidence: their absent enum fields never imply zero. For each field, use
`N/A — <why>` when handoffs or matching field evidence are genuinely unavailable,
unverified, or incomplete; do not shrink the denominator to observable values.
No handoffs also yields `N/A`, not `0/0`.

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
