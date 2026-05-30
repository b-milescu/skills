---
name: issue-delivery-loop
description: >-
  Parent coordinator skill for batch GitLab issue delivery. Use when asked to
  process ready issues, run an issue-to-MR loop, or manage a bounded delivery
  batch. Triggers: batch delivery, ready-issue processing, and issue-to-MR
  coordination. Requires Decoupling Contract before parallel builder/reviewer
  fan-out and delegates implementation/review to start-build/start-review.
---

# Issue Delivery Loop

Coordinate ready-issue batches without duplicating canonical build/review procedures.

## Start here

Act immediately — this skill drives the batch, it is not passive reference. Follow the Operating contract below; this ramp just orders the first actions:

1. Preflight (`../gitlab-local/SKILL.md`) and read the ready queue.
2. Prove the [Decoupling Contract](../docs/decoupling-contract.md) before any parallel work.
3. Run the parent loop per [`../start-build/reference/parent-orchestrator.md`](../start-build/reference/parent-orchestrator.md), delegating builds to [`../start-build/reference/child-builder.md`](../start-build/reference/child-builder.md) and review to [`../start-review/REVIEW-FLOW.md`](../start-review/REVIEW-FLOW.md).
4. On approve, finish by authority (SHA/CI/authority guards in the canonical flows).
5. Hand merged work to [`/post-merge-verifier`](../post-merge-verifier/SKILL.md).
6. Report the per-batch metrics listed in the Operating contract.

## Use when

- process ready-for-agent queue
- batch delivery
- issue-to-MR loop

## Operating contract

- Default WIP: 1 active delivery loop, serial by default.
- Run the parent loop per `../start-build/reference/parent-orchestrator.md` — proving the decoupling proof before parallel work, completing the full parent spot-check field list, driving the decision loop, and finishing only behind the SHA/CI/authority guards; the three-round limit defers to `../start-build/reference/standalone-gate.md`.
- Delegate implementation to child `mr-builder` sessions via `../start-build/reference/child-builder.md` (stable router: `../start-build/BUILD-FLOW.md`).
- Delegate independent review to fresh `mr-reviewer` sessions via `../start-review/REVIEW-FLOW.md`.
- Preserve builder/reviewer authority boundaries from those canonical flows; do not restate command bodies.
- Event-driven waiting: you are notified when a child build/review completes — do not poll, re-read, or re-invoke children mid-run; act on their returned handoffs. Canonical: `../start-build/reference/timeout-handling.md`.
- Scale ceremony to risk and blast radius (`../docs/effort-scaling.md`): trivial/docs/mechanical issues take the compact path with light verification; behavior/safety changes take the full path with adversarial verification. The mandatory independent review gate never scales away, and when merge authority is granted up front the approving reviewer finishes in-session rather than spawning a separate finisher.
- Durable child outputs: prefer inline handoffs; if file output is required, use a caller-created absolute run directory outside any `pi-worktree-*`; GitLab MR descriptions/comments remain canonical.
- Metrics to report per batch: issues attempted, MRs opened, merged, queued, blocked, review rounds, CI failures, brief defects, follow-up issues created.
- After merge or protected auto-merge, hand off read-only validation to `../post-merge-verifier/SKILL.md`.
- Canonical sources: `../gitlab-local/SKILL.md`, `../start-build/BUILD-FLOW.md`, `../start-build/reference/parent-orchestrator.md`, `../start-build/reference/child-builder.md`, `../start-build/templates/reviewer-lift-schema.md`, `../start-build/templates/review-packet.md`, `../start-review/REVIEW-FLOW.md`, `../start-review/templates/review-report.md`, `../post-merge-verifier/SKILL.md`.

## Handoff

Use this skill as coordinator-only guidance. Keep live GitLab command syntax in `/gitlab-local`, durable child-output details in `start-build`, and workflow detail in `start-build` / `start-review`.
