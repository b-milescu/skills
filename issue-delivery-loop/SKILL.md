---
name: issue-delivery-loop
description: >-
  Parent coordinator for batch GitLab issue delivery. Use when asked to process
  ready issues, run an issue-to-MR loop, or manage a bounded delivery batch.
  Requires Decoupling Contract before parallel builder/reviewer fan-out;
  delegates implementation/review to start-build/start-review.
---

# Issue Delivery Loop

Coordinate ready-issue batches without duplicating canonical build/review procedures.

## Start here

Act immediately — this skill drives the batch, it is not passive reference. Follow the Operating contract below; this ramp just orders the first actions:

1. Preflight (`skill://gitlab/SKILL.md`) and read the ready queue.
2. For parallel fan-out only: prove the [Decoupling Contract](skill://issue-delivery-loop/docs/decoupling-contract.md) before any parallel work (decoupling proof before parallel work). Serial WIP-1 batches skip this step.
3. Classify target issue/MR `trivial`, `moderate`, or `high-risk` using [Tier routing](#tier-routing).
4. Run the parent loop per [`skill://start-build/reference/parent-orchestrator.md`](skill://start-build/reference/parent-orchestrator.md), using [`skill://start-build/reference/parent-owned-gate.md`](skill://start-build/reference/parent-owned-gate.md) for parent-owned Gate Receipt mode, delegating builds to [`skill://start-build/reference/child-builder.md`](skill://start-build/reference/child-builder.md) and review to [`skill://start-review/REVIEW-FLOW.md`](skill://start-review/REVIEW-FLOW.md). Launch review as soon as the build handoff lands, in parallel with CI, for every tier — do not block-watch the pipeline to green before launching the reviewer (the merge floor is enforced by the queued auto-merge finish, not by a foreground CI watch); see [`parent-orchestrator.md` Reviewer launch timing](skill://start-build/reference/parent-orchestrator.md).
5. On `pass` (with recorded approval action), finish by authority. The default finish is approve SHA-bound then **queue auto-merge** (merge-when-pipeline-succeeds), so GitLab completes the merge the instant the reviewed-SHA pipeline passes; the exact-SHA CI floor and fail-closed guard (a `failed`/`canceled` reviewed-SHA pipeline blocks, never queues) stay intact per the canonical flows.
6. Hand merged work to the `skill://start-build/reference/post-merge-verifier.md` recipe.
7. Report the per-batch metrics listed in the Operating contract.
8. (Optional) Hand the per-batch metrics to `/retro` to turn friction evidence into routed follow-up issues.

## Use when

- process a queue carrying the target repo's AFK-ready Triage Role label
- batch delivery
- issue-to-MR loop

## Tier routing

Skill-only tier routing applies only to flows launched through the parent delivery loop. Manual direct agent selection outside enforcement surface; skill docs choose exact route basenames. Model pins live in frontmatter; provider effort pins live too.

Before launching any child builder, classify each target issue/MR:

- `trivial` requires all criteria to be true: docs/prose/templates/labels/inventory/checklist or other mechanical no-runtime work; no runtime behavior; no security/auth/permissions/billing; no schema/migration/persistence; no deploy/runtime/CI semantic change; no concurrency/state-machine/locking impact; no broad architecture/cross-file coupling; no broad multi-file or shared-harness test refactor; clear acceptance criteria.
- `high-risk` applies when any trigger is present: auth/security/crypto/secrets; migrations/schema/data-loss; deploy/runtime/infra/CI semantics; concurrency/locking/state machines/queues; billing/permissions/access control; large diff (`>=20` files or `>=1000` diff lines); unclear acceptance criteria.
- `moderate` is the default when work is neither `trivial` nor `high-risk`.

Test surface alone does not lower the tier: route by blast radius, not by runtime-vs-test surface. A broad test-only refactor — many touched test files (objective signal: `>=10` test files) or a shared test-harness / cross-file test-coupling change — is **not** `trivial` even though it is test-only and runs no runtime code; route it at least `moderate` so a large semantic test refactor takes the higher-effort build/review path instead of bouncing through avoidable review rounds. (A broad test refactor that also trips a `high-risk` trigger above — for example `>=20` touched files — still routes `high-risk`.)

The exact per-tier model-free route basenames live in one canonical table, owned by [`skill://start-build/reference/parent-orchestrator.md`](skill://start-build/reference/parent-orchestrator.md) — launch seams resolve those basenames from the current dialect directory (`agents/claude/<route>.md` or `agents/omp/<route>.md`). This loop classifies tier; do not restate route-name rows here. Route basenames are distinct from role/mode labels such as `child mr-builder` and `mr-reviewer`.

Independent-review floors hold regardless route: mandatory independent final-reviewer route `mr-reviewer-final`, resolved from the current dialect directory. There is no review scout, no generic fallback reviewer, no shim, and no cross-runtime substitute; missing route remains route-unavailable blocker.

## Operating contract

- Default WIP: 1 active delivery loop, serial by default.
- Run the parent loop per `skill://start-build/reference/parent-orchestrator.md` — proving the decoupling proof before parallel work, completing the full parent spot-check field list, following `skill://start-build/reference/parent-owned-gate.md` when parent-owned Gate Receipt mode is active, honoring the minimal child/reviewer/revision launch prompts, driving the decision loop, and finishing only behind the SHA/CI/authority guards; the three-round limit defers to `skill://start-build/reference/standalone-gate.md`.
- Delegate implementation to child `mr-builder` sessions via exact routed builder agent from [Tier routing](#tier-routing), with `skill://start-build/reference/child-builder.md` as the child-mode procedure source (router: `skill://start-build/SKILL.md` mode matrix).
- Delegate independent review fresh final-reviewer sessions via `skill://start-review/REVIEW-FLOW.md`: route `mr-reviewer-final`, resolved from the current dialect directory.
- Preserve builder/reviewer authority boundaries from those canonical flows; do not restate command bodies.
- Child/reviewer prompts pass one target issue/MR, exact role/mode, stop condition, expected handoff schema, forbidden actions, minimum evidence pointers only. Child stop conditions must say runtime budget/token/runtime notices are runtime state rather than task-scope changes, so a notice alone never becomes a human stop instruction. Do not restate broad parent reasoning unless specific risk requires narrow extra context.
- Select gate ownership per batch pass and pass it explicitly in each child-builder prompt's `Gate owner` field (`builder` = builder-owned gate, `parent` = parent-owned gate), per [minimal child-builder launch prompt](skill://start-build/reference/parent-orchestrator.md). Setting it once keeps identically-shaped issues on one gate mode instead of child inferring mode from finish-authority prose; if omitted, documented default is builder-owned (`builder`). Per-mode semantics stay owned by `skill://start-build/reference/parent-owned-gate.md`.
- Event-driven waiting: you are notified when child build/review completes — do not poll, re-read, or re-invoke children mid-run; act on returned handoffs. Read `delivery.handoff_contract` first for routing, but still verify compact claims from Tier 1/Tier 2 evidence before acting. When a child yields early because of a runtime/tool/budget notice, resume the same child/worktree when runtime recovered and state still safe; otherwise mark a runtime/tool blocker or relaunch same assigned scope without recasting the issue as product/workflow-scope blocked. Parent-owned gate handoffs route through `skill://start-build/reference/parent-owned-gate.md`. Canonical timeout handling remains `skill://start-build/reference/timeout-handling.md`.
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
- Canonical sources: `skill://gitlab/SKILL.md`, `skill://start-build/SKILL.md`, `skill://start-build/reference/parent-orchestrator.md`, `skill://start-build/reference/parent-owned-gate.md`, `skill://start-build/reference/child-builder.md`, `skill://start-build/reference/post-merge-verifier.md`, `skill://start-build/templates/reviewer-lift-schema.md`, `skill://start-build/templates/review-packet.md`, `skill://start-review/REVIEW-FLOW.md`, `skill://start-review/templates/review-report.md`.

## Batch teardown

After all MRs in the batch are merged, queued, or blocked, sweep the following before closing the batch. Report any unresolved items as blockers using the existing blocker vocabulary.

- [ ] Run-worktrees removed: follow the cleanup-order rules in [parent-orchestrator §Fresh default and cleanup order](skill://start-build/reference/parent-orchestrator.md) — fetch origin, fast-forward local default, then remove each clean worktree. Retain any unclean worktree and report `cleanup_pending`.
- [ ] `refs/tmp/review/*` cleared: follow the [reviewer temp-ref removal rules](skill://start-review/REVIEW-FLOW.md) — delete each temp ref only after its review worktree is removed and no other review uses it (`git update-ref -d refs/tmp/review/mr-<iid>`).
- [ ] Local source branches handled per project policy: delete only when policy + default-branch safety checks permit (see §Fresh default cleanup order above).
- [ ] Remote source branches gone after merge: for each merged MR, confirm the finish path removed the real remote source branch (`git ls-remote origin <source_branch>` returns nothing). If the branch still exists remotely, delete it only when the merged-SHA containment / default-branch safety check in [parent-orchestrator §Fresh default cleanup order](skill://start-build/reference/parent-orchestrator.md) passes; otherwise report `cleanup_pending`.
- [ ] Stale local `origin/*` tracking refs pruned or absent: after the real remote source-branch checks above, run the `git remote prune --dry-run origin` equivalent stale-ref check. Cleanup is complete only when that result is empty. If stale refs remain, report `cleanup_pending` with the stale refs listed instead of treating branch cleanup as done.
- [ ] Check Gate green on fresh default branch: `git fetch origin && git checkout <default_branch> && git merge --ff-only origin/<default_branch>` then run the target repo's Check Gate per `project_profile.gate_policy_ref` (see `docs/agents/check-gate.md` in the target repo).

## Handoff

Use this skill as coordinator-only guidance. Keep live GitLab transport syntax and fallback conditions in `/gitlab`, durable child-output details in `start-build`, and workflow detail in `start-build` / `start-review`.
