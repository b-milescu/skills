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

Review GitLab Merge Requests against project rules and safety invariants. Operate as a **very senior software developer**: evidence-first, narrow-context, explicit about tradeoffs, and unwilling to invent facts. Single-MR is the default. Multiple MRs are allowed only when they satisfy the shared [Decoupling Contract](../docs/decoupling-contract.md); each gets its own review context, worktree (when local checkout/tests are needed), Review Report, decision, and reviewed SHA. Protect safety boundaries: no unintended product/runtime/operator external effects, no weakened gates, no credential exposure, no untested behavior changes, no scope creep.

For behavior-touching MRs, evaluate test evidence using `tdd` principles. A red-green trace strengthens evidence; missing red-first proof is an evidence request unless project rules require strict TDD or the final behavior tests themselves are weak. Keep review context as narrow as possible: MR description, Reviewer Lift, linked issue, changed paths, rulebook, and directly referenced docs/tests first; expand only when concrete evidence requires it.

## Quick start

> **Invocation modes.** The reviewer may be spawned by a human, by a parent orchestrator after child `mr-builder` final handoff, by a separate builder session, or via the [Mandatory review gate](../start-build/BUILD-FLOW.md#mandatory-review-gate) by a standalone builder running `/start-build`. When invoked via the Mandatory review gate, the task prompt contains a structured handoff: MR URL, pointer to the Reviewer Lift block in the MR description, and the project rulebook path. The review procedure is identical regardless of invocation method — the reviewer reads the diff fresh, runs its own tests, and makes its own judgment.

1. Load `gitlab-local` and run **Snippet: local-repo-preflight** to verify `glab`/`jq` are installed, authenticated, and the cwd is the intended GitLab repo.
2. Read [REVIEW-FLOW.md](REVIEW-FLOW.md) before selecting MR(s), commenting, approving, merging, requesting changes, or rejecting.
3. Resolve the MR(s): supplied IDs/URLs/branches, current-branch MR, or pick from open non-draft MRs (see [REVIEW-FLOW.md §MR pickup](REVIEW-FLOW.md#mr-pickup)).
4. For multiple MRs, keep only a set that satisfies the shared [Decoupling Contract](../docs/decoupling-contract.md); use one isolated worktree per MR when local checkout/tests are needed [see §Multiple MR worktree mode](REVIEW-FLOW.md#multiple-mr-worktree-mode).
5. Read linked issue + MR description before the diff. Lift every field from the builder's `Reviewer Lift` block, using `../start-build/templates/reviewer-lift-schema.md` as the canonical schema [see §Handoff integrity check](REVIEW-FLOW.md#handoff-integrity-check).
6. Confirm the MR head SHA equals the lifted `Reviewed SHA`; re-diff deltas before approval.
7. Skim `Reviewer Focus` first, then walk the full diff; evaluate behavior tests via `tdd` principles [see §Procedure](REVIEW-FLOW.md#procedure).
8. Answer every `OQ-N` from the MR description — answer, escalate, or downgrade to evidence request.
9. Post one summary-first Review Report per MR via `templates/review-report.md` and decide independently. The first section is `## Decision Summary` with decision, reviewed SHA, CI status/SHA, findings summary (`MF-N` / `SF-N` / `C-N` counts or IDs), local checks, and Report link.
10. **SHA discipline:** use `gitlab-local` **Snippet: sha-guard** before `gitlab-local` **Snippet: approve-merge-sha-bound**; approve with `glab mr approve <id> --sha <reviewed-sha>`. Merge or auto-merge only when `Merge authority` allows.

## MR pickup summary

When the user supplies MR IDs/URLs/branches, review them. Otherwise pick from the **current GitLab project**: prefer the current-branch MR, then open non-draft MRs labeled with the project's ready-for-review equivalent or assigned to `@me`. For multiple MRs, keep only a set that satisfies the shared [Decoupling Contract](../docs/decoupling-contract.md). Deprioritize drafts, blocked MRs, MRs with the project's revision/unblock equivalent, or red-CI MRs. See [REVIEW-FLOW.md §MR pickup](REVIEW-FLOW.md#mr-pickup) for the full procedure using `gitlab-local` snippet names.

## Multiple MR worktree mode

One isolated worktree per MR, fetched into temp refs — never shared `FETCH_HEAD`. Review independently with separate LLM context. See [REVIEW-FLOW.md §Multiple MR worktree mode](REVIEW-FLOW.md#multiple-mr-worktree-mode) for the full procedure.

## Essential review summary

- Block on scope creep, credential leakage, weakened gates, missing/weak behavior tests, red/stale CI, or omitted gate evidence. Treat style as non-blocking.
- Multiple MRs require separate Review Reports, decisions, and reviewed SHAs — never batch.
- Approval requires: no Must Fix, all `OQ-N` answered, head SHA = reviewed SHA, CI green/waived/pending under protected auto-merge.
- Approve with `gitlab-local` **Snippet: approve-merge-sha-bound** and `--sha <reviewed-sha>`. Merge only when `Merge authority` allows.
- See [REVIEW-FLOW.md §Procedure](REVIEW-FLOW.md#procedure) for the step-by-step and [§Review Report expectations](REVIEW-FLOW.md#review-report-expectations) for report structure.

## Decision outcomes

- **Approve** — scope matches, no Must Fix, all OQs answered, tests adequate, SHA verified, CI green/waived. Use `gitlab-local` **Snippet: approve-merge-sha-bound**; merge or auto-merge when authority allows.
- **Request changes** — fixable Must Fix items; apply the project's revision label if one exists, keep MR open.
- **Reject** — premise/scope wrong or safety boundary weakened beyond acceptance.

## Templates

- `../start-build/templates/reviewer-lift-schema.md` — canonical Reviewer Lift field names, order, and required semantics copied into Review Reports.
- `templates/reviewer-final-handoff.md` — machine-readable reviewer final response block for parent-orchestrator parsing.
- `templates/review-report.md` — single top-level MR comment.
- `templates/unblock-response.md` — response to a Stuck Packet.
- `templates/filling-guide.md` — section-by-section filling instructions for reviewer templates.
- `templates/adr.md` — architectural recommendation requiring its own MR; see shared `../templates/filling-guide.md`.

## Decisions

See [REVIEW-FLOW.md §Decisions](REVIEW-FLOW.md#decisions) for the full approve / request-changes / reject criteria and post-review actions.
