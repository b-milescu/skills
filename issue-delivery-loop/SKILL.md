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

1. Preflight (`skill://gitlab/SKILL.md`) and read the ready queue.
2. For parallel fan-out only: prove the [Decoupling Contract](skill://issue-delivery-loop/docs/decoupling-contract.md) before any parallel work (decoupling proof before parallel work). Serial WIP-1 batches skip this step.
3. Classify each target issue/MR as `trivial`, `moderate`, or `high-risk` using [Model-tier routing](#model-tier-routing).
4. Run the parent loop per [`skill://start-build/reference/parent-orchestrator.md`](skill://start-build/reference/parent-orchestrator.md), using [`skill://start-build/reference/parent-owned-gate.md`](skill://start-build/reference/parent-owned-gate.md) for parent-owned Gate Receipt mode, delegating builds to [`skill://start-build/reference/child-builder.md`](skill://start-build/reference/child-builder.md) and review to [`skill://start-review/REVIEW-FLOW.md`](skill://start-review/REVIEW-FLOW.md).
5. On `pass` (with recorded approval action), finish by authority (SHA/CI/authority guards in the canonical flows).
6. Hand merged work to the `skill://start-build/reference/post-merge-verifier.md` recipe.
7. Report the per-batch metrics listed in the Operating contract.
8. (Optional) Hand the per-batch metrics to `/retro` to turn friction evidence into routed follow-up issues.

## Use when

- process a queue carrying the target repo's AFK-ready Triage Role label
- batch delivery
- issue-to-MR loop

## Model-tier routing

Skill-only routing applies only to flows launched through this parent delivery loop. Manual direct agent selection is outside this enforcement surface; selected agent frontmatter owns the model/effort pin.

Before launching any child builder, classify each target issue/MR:

- `trivial` requires all criteria to be true: docs/prose/templates/labels/inventory/checklist or other mechanical no-runtime work; no runtime behavior; no security/auth/permissions/billing; no schema/migration/persistence; no deploy/runtime/CI semantic change; no concurrency/state-machine/locking impact; no broad architecture/cross-file coupling; clear acceptance criteria.
- `high-risk` applies when any trigger is present: auth/security/crypto/secrets; migrations/schema/data-loss; deploy/runtime/infra/CI semantics; concurrency/locking/state machines/queues; billing/permissions/access control; large diff (`>=20` files or `>=1000` diff lines); unclear acceptance criteria.
- `moderate` is the default when work is neither `trivial` nor `high-risk`.

The exact per-tier builder route names live in one canonical table, owned by [`skill://start-build/reference/parent-orchestrator.md`](skill://start-build/reference/parent-orchestrator.md) — the launch seam this loop dispatches through. This loop classifies the tier; do not restate the route-name rows here.

Independent-review floors hold regardless of route: the optional OMP scout produces non-gate observations only and cannot satisfy the mandatory independent review gate; the final reviewer is runtime-specific — `mr-reviewer-opus48-xhigh` on Claude Code or `mr-reviewer-gpt55-xhigh` on OMP. The GPT reviewer/scout routes pin `openai-codex/*` models that exist only on OMP, so Claude Code never selects them and uses `mr-reviewer-opus48-xhigh` as its primary final-review route. On OMP, provider-failure fallback to the Opus xhigh reviewer requires an explicit parent/operator decision token after the `mr-reviewer-gpt55-xhigh` route is unavailable, and is never a cost downgrade or weaker-effort substitute.

## Operating contract

- Default WIP: 1 active delivery loop, serial by default.
- Run the parent loop per `skill://start-build/reference/parent-orchestrator.md` — proving the decoupling proof before parallel work, completing the full parent spot-check field list, following `skill://start-build/reference/parent-owned-gate.md` when parent-owned Gate Receipt mode is active, honoring the minimal child/reviewer/revision launch prompts, driving the decision loop, and finishing only behind the SHA/CI/authority guards; the three-round limit defers to `skill://start-build/reference/standalone-gate.md`.
- Delegate implementation to child `mr-builder` sessions via the exact routed builder agent from [Model-tier routing](#model-tier-routing), with `skill://start-build/reference/child-builder.md` as the child-mode procedure source (stable router: `skill://start-build/BUILD-FLOW.md`).
- Delegate independent review to fresh final-reviewer sessions via `skill://start-review/REVIEW-FLOW.md`: `mr-reviewer-opus48-xhigh` on Claude Code or `mr-reviewer-gpt55-xhigh` on OMP. Optional `mr-review-scout-gpt54-low` output is OMP-only and non-gate, and on OMP the `mr-reviewer-opus48-xhigh` route is provider-failure fallback only with an explicit parent/operator decision token.
- Preserve builder/reviewer authority boundaries from those canonical flows; do not restate command bodies.
- Child/reviewer prompts pass one target issue/MR, exact role/mode, stop condition, expected handoff schema, forbidden actions, and minimum evidence pointers only. Do not restate broad parent reasoning unless a specific risk requires narrow extra context.
- Event-driven waiting: you are notified when a child build/review completes — do not poll, re-read, or re-invoke children mid-run; act on their returned handoffs. Read `delivery.handoff_contract` first for routing, but still verify compact claims from Tier 1/Tier 2 evidence before acting. Parent-owned gate handoffs route through `skill://start-build/reference/parent-owned-gate.md`. Canonical: `skill://start-build/reference/timeout-handling.md`.
- Scale ceremony to risk and blast radius (`skill://issue-delivery-loop/docs/effort-scaling.md`): trivial/docs/mechanical issues take the compact path with light verification; behavior/safety changes take the full path with adversarial verification. The mandatory independent review gate never scales away, and when merge authority is granted up front the approving reviewer finishes in-session rather than spawning a separate finisher.
- Durable child outputs: prefer inline handoffs; if file output is required, use a caller-created absolute run directory outside any `omp-worktree-*`; GitLab MR descriptions/comments remain canonical.
- Project-profile hooks are coordinator inputs, not safety overrides. They may
  specialize gate policy, labels, branch naming, CI jobs, domain docs,
  release/deploy policy, manual validation, language families, and auxiliary
  indexes, but they must not weaken reviewed-SHA binding, exact-SHA CI, explicit
  authority source, independent review, child-builder boundaries, verifier
  read-only boundaries, or MCP-first transport correctness plus help-first
  `glab` fallback correctness.
- Auxiliary project-index updates default to the parent/coordinator checkout unless the project profile explicitly assigns them elsewhere. Child worktrees treat index reports as read-only unless assigned and must not copy index artifacts between worktrees.
- Metrics to report per batch (names match `retro/templates/retro-report.md`; use `N/A — <why>` when a metric was not observable):
  - **Issues attempted** — count of issues picked up this batch; evidence: GitLab issue list.
  - **MRs opened** — Draft or ready MRs created; evidence: MR list for this batch.
  - **MRs merged** — MRs successfully merged; evidence: MR merge events.
  - **MRs queued (auto-merge)** — MRs queued for merge-when-pipeline-succeeds; evidence: auto-merge queue actions.
  - **MRs blocked** — MRs ending this batch in a blocked state; evidence: builder/reviewer handoff `blocked` fields.
  - **Review rounds (total / max per MR)** — total reviewer sessions across all MRs plus the single-MR maximum; evidence: reviewer handoff chain.
  - **CI failures** — pipeline runs that ended in a failed state during this batch; evidence: CI snapshots in Review Packets / handoffs.
  - **Brief defects** — issue briefs that omitted critical context, acceptance criteria, test strategy, or non-goals, causing avoidable discovery or rework; defined by the brief-quality-defects criteria in [the reviewer filling guide §Follow-ups for Other Tasks](skill://start-review/templates/filling-guide.md) and [the review report template](skill://start-review/templates/review-report.md); evidence: reviewer "Follow-ups for Other Tasks" sections noting brief-quality gaps.
  - **Follow-up issues created** — GitLab issues filed during this batch to capture out-of-scope work; evidence: issue creation events.
- After merge or protected auto-merge, hand off read-only validation to the `skill://start-build/reference/post-merge-verifier.md` recipe.
- Canonical sources: `skill://gitlab/SKILL.md`, `skill://start-build/BUILD-FLOW.md`, `skill://start-build/reference/parent-orchestrator.md`, `skill://start-build/reference/parent-owned-gate.md`, `skill://start-build/reference/child-builder.md`, `skill://start-build/reference/post-merge-verifier.md`, `skill://start-build/templates/reviewer-lift-schema.md`, `skill://start-build/templates/review-packet.md`, `skill://start-review/REVIEW-FLOW.md`, `skill://start-review/templates/review-report.md`.

## Batch teardown

After all MRs in the batch are merged, queued, or blocked, sweep the following before closing the batch. Report any unresolved items as blockers using the existing blocker vocabulary.

- [ ] Run-worktrees removed: follow the cleanup-order rules in [parent-orchestrator §Fresh default and cleanup order](skill://start-build/reference/parent-orchestrator.md) — fetch origin, fast-forward local default, then remove each clean worktree. Retain any unclean worktree and report `cleanup_pending`.
- [ ] `refs/tmp/review/*` cleared: follow the [reviewer temp-ref removal rules](skill://start-review/REVIEW-FLOW.md) — delete each temp ref only after its review worktree is removed and no other review uses it (`git update-ref -d refs/tmp/review/mr-<iid>`).
- [ ] Local source branches handled per project policy: delete only when the policy and default-branch safety check permit (see §Fresh default and cleanup order above).
- [ ] Check Gate green on a fresh default branch: `git fetch origin && git checkout <default_branch> && git merge --ff-only origin/<default_branch> && npm run check`.

## Handoff

Use this skill as coordinator-only guidance. Keep live GitLab transport syntax and fallback conditions in `/gitlab`, durable child-output details in `start-build`, and workflow detail in `start-build` / `start-review`.
