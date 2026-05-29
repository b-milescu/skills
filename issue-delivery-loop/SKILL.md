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

## Use when

- process ready-for-agent queue
- batch delivery
- issue-to-MR loop

## Operating contract

- Default WIP: 1 active delivery loop, serial by default.
- Parallel work only after proving `../docs/decoupling-contract.md` for every item.
- Delegate implementation to child `mr-builder` sessions via `../start-build/reference/child-builder.md` (stable router: `../start-build/BUILD-FLOW.md`).
- Delegate independent review to fresh `mr-reviewer` sessions via `../start-review/REVIEW-FLOW.md`.
- Preserve builder/reviewer authority boundaries from those canonical flows; do not restate command bodies.
- Parent spot-check before review/finish: MR URL/IID, source/target branch, current SHA, Reviewer Lift, CI, changed paths, local gate, open questions, merge authority.
- Durable child outputs: prefer inline handoffs; if file output is required, use a caller-created absolute run directory outside any `pi-worktree-*`; GitLab MR descriptions/comments remain canonical.
- Revision loop: up to 3 review rounds per MR; on request-changes, push fixes, update MR/Reviewer Lift, and start a fresh reviewer; on reject or round-limit exhaustion, escalate.
- Metrics to report per batch: issues attempted, MRs opened, merged, queued, blocked, review rounds, CI failures, brief defects, follow-up issues created.
- After merge or protected auto-merge, hand off read-only validation to `../post-merge-verifier/SKILL.md`.
- Canonical sources: `../gitlab-local/SKILL.md`, `../start-build/BUILD-FLOW.md`, `../start-build/reference/parent-orchestrator.md`, `../start-build/reference/child-builder.md`, `../start-build/templates/reviewer-lift-schema.md`, `../start-build/templates/review-packet.md`, `../start-review/REVIEW-FLOW.md`, `../start-review/templates/review-report.md`, `../post-merge-verifier/SKILL.md`.

## Handoff

Use this skill as coordinator-only guidance. Keep live GitLab command syntax in `/gitlab-local`, durable child-output details in `start-build`, and workflow detail in `start-build` / `start-review`.
