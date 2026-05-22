---
name: start-review
description: >-
  Review GitLab MRs against project rules, safety invariants, CI, and TDD test
  evidence. Post Review Reports, approve/request-changes/reject, merge when
  authority allows. Trigger: start a review, pick up/review MR(s), review this
  branch, evaluate Review Packets.
---

# Start Review

## Purpose

> **Abbreviation:** `PRO` = product / runtime / operator (external systems).

Review GitLab Merge Requests against project rules and safety invariants. Single-MR is the default. Multiple MRs are allowed only when clearly decoupled; each gets its own review context, worktree (when local checkout/tests are needed), Review Report, decision, and reviewed SHA. Protect safety boundaries: no unintended PRO external effects, no weakened gates, no credential exposure, no untested behavior changes, no scope creep.

For behavior-touching MRs, evaluate test evidence using `tdd` principles. A red-green trace strengthens evidence; missing red-first proof is an evidence request unless project rules require strict TDD or the final behavior tests themselves are weak.

## Quick start

> **Invocation.** The reviewer is always invoked by a human in a fresh session — never spawned automatically by the builder. When the human is following the `start-build` mandatory review gate, the session prompt usually carries a structured handoff from the builder: MR URL, pointer to the Reviewer Lift block in the MR description, and the project rulebook path. The reviewer reads the diff fresh, runs its own tests, and makes its own judgment regardless of who pasted the handoff.

1. Load `local-gitlab` and run its direct-`glab` preflight to verify `glab` is installed/authenticated and the cwd is the intended GitLab repo.
2. Read [REVIEW-FLOW.md](REVIEW-FLOW.md) before selecting MR(s), commenting, approving, merging, requesting changes, or rejecting.
3. Resolve the MR(s): supplied IDs/URLs/branches, current-branch MR, or pick from open non-draft MRs (see [REVIEW-FLOW.md §MR pickup](REVIEW-FLOW.md#mr-pickup)).
4. For multiple MRs, keep only a clearly decoupled set; use one isolated worktree per MR when local checkout/tests are needed [see §Multiple MR worktree mode](REVIEW-FLOW.md#multiple-mr-worktree-mode).
5. Read linked issue + MR description before the diff. Lift the builder's `Reviewer Lift` block into the matching Review Report fields [see §Handoff integrity check](REVIEW-FLOW.md#handoff-integrity-check).
6. Confirm the MR head SHA equals the lifted `Reviewed SHA`; re-diff deltas before approval.
7. Skim `Reviewer Focus` first, then walk the full diff; evaluate behavior tests via `tdd` principles [see §Procedure](REVIEW-FLOW.md#procedure).
8. Answer every `OQ-N` from the MR description — answer, escalate, or downgrade to evidence request.
9. Post one Review Report per MR via `templates/review-report.md` and decide independently.
10. **SHA discipline:** approve with `glab mr approve <id> --sha <reviewed-sha>`. Merge or auto-merge only when `Merge authority` allows.

## Essential tooling

Load `local-gitlab` for `glab` preflight, command syntax, flag pitfalls, and minimum invariants. Keep this skill focused on workflow, review evidence, and decision policy.

## MR pickup summary

When the user supplies MR IDs/URLs/branches, review them. Otherwise pick from the **current GitLab project**: prefer the current-branch MR, then open non-draft MRs labeled ready-for-review or assigned to `@me`. For multiple MRs, keep only a clearly decoupled set — no stacked branches, no file/schema/lock overlap, independently testable. Deprioritize drafts, blocked, needs-revision, or red-CI MRs. See [REVIEW-FLOW.md §MR pickup](REVIEW-FLOW.md#mr-pickup) for the full procedure with commands.

## Multiple MR worktree mode

One isolated worktree per MR, fetched into temp refs — never shared `FETCH_HEAD`. Review independently with separate LLM context. See [REVIEW-FLOW.md §Multiple MR worktree mode](REVIEW-FLOW.md#multiple-mr-worktree-mode) for the full procedure.

## Essential review summary

- Block on scope creep, credential leakage, weakened gates, missing/weak behavior tests, red/stale CI, or omitted gate evidence. Treat style as non-blocking.
- Multiple MRs require separate Review Reports, decisions, and reviewed SHAs — never batch.
- Approval requires: no Must Fix, all `OQ-N` answered, head SHA = reviewed SHA, CI green/waived/pending under protected auto-merge.
- Approve with `--sha <reviewed-sha>`. Merge only when `Merge authority` allows.
- See [REVIEW-FLOW.md §Procedure](REVIEW-FLOW.md#procedure) for the step-by-step and [§Review Report expectations](REVIEW-FLOW.md#review-report-expectations) for report structure.

## Decision outcomes

- **Approve** — scope matches, no Must Fix, all OQs answered, tests adequate, SHA verified, CI green/waived. Approve with `--sha`; merge or auto-merge when authority allows.
- **Request changes** — fixable Must Fix items; apply `needs-revision`, keep MR open.
- **Reject** — premise/scope wrong or safety boundary weakened beyond acceptance.

## Templates

- `templates/review-report.md` — single top-level MR comment.
- `templates/unblock-response.md` — response to a Stuck Packet.
- `templates/adr.md` — architectural recommendation requiring its own MR.

## Decisions

See [REVIEW-FLOW.md §Decisions](REVIEW-FLOW.md#decisions) for the full approve / request-changes / reject criteria and post-review actions.
