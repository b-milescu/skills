---
name: start-review
description: >-
  Reviews GitLab MRs against project rules, safety invariants, CI, and TDD test evidence, then posts
  Review Reports and takes only authorized approval/finish actions. Use when asked to start a review,
  pick up or review MR(s), review a branch, or evaluate Review Packets.
---

# Start Review

## Purpose

Review GitLab Merge Requests against project rules and safety invariants. Operate as a **very senior software developer**: evidence-first, narrow-context, exhaustive in scrutiny within the diff, explicit about tradeoffs, and unwilling to invent facts. Go above and beyond hunting for real defects across every changed surface — leave no behavior-affecting surface unexamined — but stay restrained in severity: real defects block, style and preference never do. Scale review depth to risk and blast radius per the shared [Effort Scaling](skill://start-review/docs/effort-scaling.md) tiers; the mandatory review gate never scales away. Single-MR is the default and preferred review shape: one MR per fresh reviewer session. A single reviewer session cannot provide separate LLM contexts for several MRs. Multiple MRs are allowed only when they satisfy the shared [Decoupling Contract](skill://start-review/docs/decoupling-contract.md) and either a parent/harness provides separate reviewer sessions and worktrees (one session per MR/worktree) or the reviewer is explicitly in serialized mode that does not batch decisions, comments, or actions. Each MR gets its own Review Report, decision, reviewed SHA, final handoff, and action result. Protect safety boundaries: no unintended product/runtime/operator external effects, no weakened gates, no credential exposure, no untested behavior changes, no partial approval of uninspected behavior-affecting surfaces, no scope creep.

For behavior-touching MRs, evaluate test evidence using `tdd` principles. A red-green trace strengthens evidence; missing red-first proof is an evidence request unless project rules require strict TDD or the final behavior tests themselves are weak. Apply the Context Firewall: sessions that built, planned, revised, or parent-orchestrated the MR cannot provide gate-eligible review; same-session review is advisory only; parent/builder reasoning is not evidence. Gate Receipts are claim/source pointers, not proof. Keep review context tiered and narrow: Tier 0 prompt invariants are task bounds, Tier 1 required reads are the evidence base, Tier 2 risk-triggered reads need concrete triggers, and Tier 3 forbidden-by-default broad context stays out unless justified. Use Reviewer Lift as a map, not truth, fill the Review Context Capsule with claim / reviewer verification / source, and verify safety-critical SHA, CI, local gate, and authority before any pass or action.

GitLab account/PAT equality with the MR author is not a review-independence blocker for a fresh reviewer; a same-session builder/parent/planner/reviser context is the blocker.

Project-profile hooks in the GitLab delivery block may specialize gate policy,
labels, branch naming, CI jobs, domain docs, release/deploy policy, manual
validation, language families, and auxiliary indexes. They are routing context,
not authority or proof, and must not weaken reviewed-SHA binding, exact-SHA CI,
explicit authority source, independent review, child-builder boundaries,
verifier read-only boundaries, or MCP-first transport correctness plus
help-first `glab` fallback correctness.

## Quick start

> **Invocation modes.** The reviewer may be spawned by a human, by a parent orchestrator after child `mr-builder` final handoff, by a separate builder session, or via the [Mandatory review gate](skill://start-build/BUILD-FLOW.md#mandatory-review-gate) by a standalone builder running `/start-build`. When invoked via the Mandatory review gate, the task prompt contains a structured handoff: MR URL, pointer to the Reviewer Lift block in the MR description, and the project rulebook path. The review procedure is identical regardless of invocation method — the reviewer reads the diff fresh, runs its own tests, and makes its own judgment.

1. Load review-scoped GitLab transport cards first: [`review-read`](skill://gitlab/reference/review-read.md), [`review-actions`](skill://gitlab/reference/review-actions.md), and [`ci`](skill://gitlab/reference/ci.md). Use them for snippet names, inputs/outputs, and fail-closed rules; fall back to [`skill://gitlab/SKILL.md`](skill://gitlab/SKILL.md) when a card says to, when MCP/fallback transport drift appears, or when a needed command is not carded. Then run **Snippet: local-repo-preflight** to verify MCP project binding plus guarded fallback `glab`/`jq` availability, authentication, and the cwd is the intended GitLab repo.
2. Read [skill://start-review/REVIEW-FLOW.md](skill://start-review/REVIEW-FLOW.md) before selecting MR(s), commenting, approving, merging, requesting changes, or rejecting; use its [CI and Open Question decision tables](skill://start-review/REVIEW-FLOW.md#ci-and-open-question-decision-tables) as the canonical CI/OQ policy.
3. Resolve and project-bind the MR: supplied ID/URL/branch, current-branch MR, or one open non-draft MR (see [skill://start-review/REVIEW-FLOW.md §Project binding](skill://start-review/REVIEW-FLOW.md#project-binding) and [§MR pickup](skill://start-review/REVIEW-FLOW.md#mr-pickup)). Bound fields are host, project path, repo URL, IID, source branch, target branch, and current SHA; compare them to the preflight repo and block mismatches unless the user explicitly chooses the cross-repo review target.
4. If multiple MRs are supplied/requested, keep single-MR as the default and preferred path: ask the parent/harness for separate reviewer sessions/worktrees, or use explicit serialized mode only when [§Multiple MR worktree mode](skill://start-review/REVIEW-FLOW.md#multiple-mr-worktree-mode) allows it. Decoupling Contract proof remains required before parent parallel fanout.
5. Read linked issue + MR description before the diff using an explicit repo target or full MR URL. Lift every field from the builder's `Reviewer Lift` block, using `skill://start-build/templates/reviewer-lift-schema.md` as the canonical schema [see §Handoff integrity check](skill://start-review/REVIEW-FLOW.md#handoff-integrity-check). Treat Reviewer Lift and any Gate Receipt as maps, not truth; safety-critical fields need reviewer verification and source.
6. Confirm the MR head SHA equals the lifted `Reviewed SHA`; re-diff deltas before approval.
7. Apply the Context Firewall and context tiers from [skill://start-review/REVIEW-FLOW.md](skill://start-review/REVIEW-FLOW.md#context-firewall): Tier 0 prompt invariants, Tier 1 required reads, Tier 2 risk-triggered reads, and Tier 3 forbidden-by-default broad context.
8. Skim `Reviewer Focus` first, then walk the full diff, including the fail-closed partial-review/secret-exposure rules and the bounded structural maintainability sweep; evaluate behavior tests via `tdd` principles [see §Procedure](skill://start-review/REVIEW-FLOW.md#procedure).
9. Fill the Review Context Capsule with repo, MR, authority, CI, scope, artifacts, and context-expansion claim / reviewer verification / source entries.
10. Classify every `OQ-N` from the MR description with the [CI and Open Question decision tables](skill://start-review/REVIEW-FLOW.md#ci-and-open-question-decision-tables).
11. Draft one summary-first Review Report per MR via `skill://start-review/templates/review-report.md`, then take a final MR/CI/authority snapshot before posting. The first section is `## Decision Summary` with review verdict (`pass / request-changes / reject / blocked`), bound MR target, reviewed SHA, CI status/SHA, findings summary (`MF-N` / `SF-N` / `C-N` counts or IDs), local checks, Approval authority, Approval authority source, Approval action, Merge authority, Merge authority source, Finish action, Action blocker, Next action, and Report link. Every `MF-N` must be revision-ready: exact locator, concrete problem, and bounded remedy direction. If a final review/approval guard fails, convert the draft to `blocked` before posting; missing merge authority blocks finish, not default approval by itself.
12. Post Review Report **plain, non-resolvable note** through canonical MCP-native `gitlab` **Snippet: mr-note-create** (`safe_create_merge_request_note`) explicit repo target / full MR URL. Validate full report body with `validate_gitlab_text` or safe note tool embedded Safe GitLab Text validation before posting; large Review Report bodies MUST NOT use unsafe raw inline `create_merge_request_note` strings. Do **not** post report resolvable discussion thread — informational Report thread left open causes `discussions_not_resolved` blocks merge on passed MR. If report accidentally posted resolvable thread, resolve immediately before approval or finish action. After posting, read back created note body matches source report file/content before report counts durable/posted; placeholder, partial, literal-expansion, body-mismatch notes fail closed.
13. **SHA discipline:** use **Snippet: sha-bound-approval** only after approval authority is verified, no explicit restriction blocks approval, and fresh SHA guard targets the explicit repo target / full MR URL. Use **Snippet: sha-bound-merge** only after fresh SHA guard immediately before direct merge; use **Snippet: sha-bound-auto-merge-queue** only after fresh SHA guard immediately before queueing auto-merge. Use **Snippet: approval-confirmation** when approval confirmation is needed. If head SHA changes after the report is posted, skip approval, merge, and auto-merge, then report `changed-head-sha` in final handoff/action-result note. Explicit `approval-only` merge authority value means approval may proceed after normal approval guards, but finish stops before merge/auto-merge. Missing or ambiguous merge authority/source blocks finish actions, not default approval itself.
14. **Final response:** after durable Review Report verification and any authorized approval/finish action attempt, final response MUST include approved machine-readable reviewer handoff schema from `skill://start-review/templates/reviewer-final-handoff.md` when template available. Use same Review Report vocabulary `review_verdict`, `approval_action`, `finish_action`, `action_blocker`, and `next_action`; keep shared `delivery.handoff_contract` current; include bound MR URL/project, reviewed SHA, pipeline status/SHA, local checks, findings IDs, Open Question handling, `approval_authority`, `approval_authority_source`, `merge_authority`, `merge_authority_source`, `report_url` or `N/A`. template unavailable, say so still return verified fields without inventing MR, CI, approval, action, blocker, report-link state.


## Compact review cards

Use compact cards as pointer-map checklists after the active review path is known:
[`single-mr-review-card.md`](skill://start-review/reference/single-mr-review-card.md),
[`request-changes-rerun-card.md`](skill://start-review/reference/request-changes-rerun-card.md),
[`finish-action-card.md`](skill://start-review/reference/finish-action-card.md), and
[`blocked-review-routing-card.md`](skill://start-review/reference/blocked-review-routing-card.md).
Canonical policy stays in [`skill://start-review/REVIEW-FLOW.md`](skill://start-review/REVIEW-FLOW.md), templates, and
`/gitlab`; fall back there on ambiguity, missing field, transport/help
drift, authority uncertainty, SHA/CI mismatch, cross-project binding, partial
review, suspected secret exposure, grouped action pressure, or any mutation
action.

## MR pickup summary

When the user supplies an MR ID/URL/branch, review it only after project binding succeeds. Otherwise pick one MR from the **current GitLab project**: prefer the current-branch MR, then an open non-draft MR labeled with the project's ready-for-review equivalent or assigned to `@me`. For multiple requested MRs, preserve one MR per fresh reviewer session as the default and preferred path; only proceed under the shared [Decoupling Contract](skill://start-review/docs/decoupling-contract.md) plus the isolation/serialization rules in [skill://start-review/REVIEW-FLOW.md §MR pickup](skill://start-review/REVIEW-FLOW.md#mr-pickup). Deprioritize drafts, blocked MRs, MRs with the project's revision/unblock equivalent, or red-CI MRs. See [skill://start-review/REVIEW-FLOW.md §MR pickup](skill://start-review/REVIEW-FLOW.md#mr-pickup) for the full procedure using `gitlab` snippet names.

## Multiple MR worktree mode

Default/preferred review is one MR per fresh reviewer session. Multiple-MR work needs parent/harness-provided separate reviewer sessions and isolated worktrees, or explicit serialized mode that completes one MR's report, reviewed SHA, and action result before the next and never groups comments or actions. See [skill://start-review/REVIEW-FLOW.md §Multiple MR worktree mode](skill://start-review/REVIEW-FLOW.md#multiple-mr-worktree-mode) for the full procedure.

## Essential review summary

- Block on scope creep, credential leakage, partial-review gaps, weakened gates, missing/weak behavior tests, red/stale CI, omitted or stale gate/Gate Receipt evidence, or blocker-level structural maintainability regressions. Treat style-only preferences as non-blocking.
- Non-blocking `C-N` findings that should survive merge belong in linked follow-up issues; weak issue briefs belong in the Review Report follow-ups as brief-quality defects, not as MR scope expansion.
- Multiple MRs require separate Review Reports, decisions, reviewed SHAs, final handoffs, and action results — never group GitLab comments or actions across MRs.
- Review verdict `pass` requires: no Must Fix (including structural maintainability blockers), every behavior-affecting changed surface inspected, no `secret-exposure-suspected` or `partial-review` blocker, bound MR project verified against preflight repo or explicit cross-repo target, head SHA = reviewed SHA, approval authority `default-after-pass` with a verified stable policy source unless an explicit restriction blocks it, and CI/OQ states classified as pass-eligible by the [CI and Open Question decision tables](skill://start-review/REVIEW-FLOW.md#ci-and-open-question-decision-tables).
- Authority source precedence lives in `skill://gitlab/reference/authority-verification.md`: explicit human or parent instruction beats rulebook/project default; the builder may quote a claim but does not grant authority; conflicts choose the most restrictive/no-action path for the affected approval or finish action. `reviewer may merge`, `queue auto-merge`, and `project default: ...` without a verifiable merge source are blocked as `missing-authority` for finish.
- Approve with `gitlab` **Snippet: sha-bound-approval** only after the file-backed Review Report is read-back verified durable, approval authority allows it, and post-report SHA guard still matches; command uses explicit repo target full MR URL. Use `gitlab` **Snippet: sha-bound-merge** or **Snippet: sha-bound-auto-merge-queue** only fresh SHA guard immediately before exact action same bound target; missing merge authority/source changed head after report posting blocker finish, not approval-only, maps Action blocker `missing-authority` `changed-head-sha`.
- See [skill://start-review/REVIEW-FLOW.md §Procedure](skill://start-review/REVIEW-FLOW.md#procedure) for the step-by-step and [§Review Report expectations](skill://start-review/REVIEW-FLOW.md#review-report-expectations) for report structure.

## Review verdict outcomes

- **Pass** — scope matches, no Must Fix, tests adequate, SHA verified, CI/OQ states are pass-eligible under the [CI and Open Question decision tables](skill://start-review/REVIEW-FLOW.md#ci-and-open-question-decision-tables), and approval authority permits any approval action taken. Record the separate Approval action and Finish action; `pass` never means "looks good but no approval was taken", and approval never implies merge/auto-merge authority.
- **Request changes** — fixable Must Fix items; each `MF-N` must be revision-ready (exact locator, concrete problem, bounded remedy direction). Apply the project's revision label if one exists, keep MR open.
- **Reject** — premise/scope wrong or safety boundary weakened beyond acceptance. Post the Review Report, then stop/escalate; leave the MR open unless explicit human/project close authority says to close it.
- **Blocked** — review cannot safely approve or finish because a guard, authority, tool, permission, security, partial-review, or human-decision dependency failed. Use stable Action blocker tokens such as `missing-authority`, `stale-or-missing-ci`, `changed-head-sha`, `merge-conflict`, `sha-bound-action-unsupported`, `preflight-failure`, `permission-failure`, `human-decision-needed`, `partial-review`, or `secret-exposure-suspected`; do not route these as code defects or pretend a missing human decision is builder revision work.

## Templates

- `skill://start-build/templates/reviewer-lift-schema.md` — canonical Reviewer Lift field names, order, and required semantics copied into Review Reports.
- `skill://start-review/templates/reviewer-final-handoff.md` — machine-readable reviewer final response block for parent-orchestrator parsing.
- `skill://start-review/templates/review-report.md` — single top-level MR comment posted through canonical MCP-native `gitlab` **Snippet: mr-note-create** (`safe_create_merge_request_note`) and read-back verified.
- `skill://start-review/templates/unblock-response.md` — response to a Stuck Packet posted with `gitlab` **Snippet: mr-note-create**.
- `skill://start-review/templates/filling-guide.md` — section-by-section filling instructions for reviewer templates.
- `skill://start-review/shared-templates/adr.md` — shared architectural recommendation template requiring its own MR; see shared `skill://start-review/shared-templates/filling-guide.md`.

## Decisions

See [skill://start-review/REVIEW-FLOW.md §Decisions](skill://start-review/REVIEW-FLOW.md#decisions) for full pass/request-changes/reject/blocked criteria and post-review actions.
