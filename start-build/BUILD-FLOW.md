# Start Build Flow

Router and compatibility anchor host for `start-build`. Detailed mode-specific flows now live under `reference/`; this file keeps stable Markdown anchors for existing links, gives one-paragraph summaries, and points each role to the smallest relevant doc. Read [SKILL.md](SKILL.md) first for the mode matrix, [SAFETY.md](SAFETY.md) for non-negotiables, and only the section/reference file that matches your role.

## Issue pickup

Issue selection detail lives in [reference/issue-pickup.md](reference/issue-pickup.md): run `gitlab-local` preflight, use `gitlab-local` **Snippet: issue-pickup** when no issue is supplied, prefer ready/unblocked one-MR work, inspect comments/linked MRs, prove the [Decoupling Contract](skill://start-build/docs/decoupling-contract.md) before multiple-issue work, and avoid casual claim/label mutation.

## Multiple issue worktree mode

Multi-issue detail lives in [reference/multiple-worktrees.md](reference/multiple-worktrees.md): prove the Decoupling Contract before parallel work, keep the original checkout coordinator-only, use one sibling worktree/branch/Draft MR/check gate/Review Packet per issue, and keep child builders from launching other builders or reviewers.

## Discovery Budget

Discovery detail lives in [reference/context-and-planning.md §Discovery Budget](reference/context-and-planning.md#discovery-budget): keep context bounded, read issue plus rulebook first, expand only from evidence triggers such as issue links, rulebook references, changed paths, imports/callers, tests, safety invariants, failing checks, or explicit user/parent prompt, and route the issue back to triage with exact unanswered questions instead of guessing.

## Build Plan Packet

Build planning detail lives in [reference/context-and-planning.md §Build Plan Packet](reference/context-and-planning.md#build-plan-packet): before the first edit, capture issue, intended behavior, affected surfaces, test plan, risk, non-goals, and loaded context sources with why each source was relevant, using [templates/build-plan-packet.md](templates/build-plan-packet.md) as the shape.

## Builder invocation modes

Mode boundaries are split across [reference/child-builder.md](reference/child-builder.md), [reference/standalone-gate.md](reference/standalone-gate.md), and [reference/parent-orchestrator.md](reference/parent-orchestrator.md): child builders stop at ready handoff, standalone builders own reviewer handoff after ready, and parents coordinate child builders/reviewers; in every mode builders quote authority instead of granting it, record `Approval authority`/source and `Merge authority source`, and cannot grant approval, merge, or auto-merge authority.

## Compact mode cards

Compact mode cards live under `reference/` as pointer maps only: [`child-builder-card.md`](reference/child-builder-card.md), [`parent-owned-gate-card.md`](reference/parent-owned-gate-card.md), [`revision-card.md`](reference/revision-card.md), and [`parent-orchestrator-card.md`](reference/parent-orchestrator-card.md). Use them for active-mode checklists after the canonical mode owner is known; parent-owned Check Gate / Gate Receipt detail lives in [`reference/parent-owned-gate.md`](reference/parent-owned-gate.md). Fall back to the full reference docs and `/gitlab-local` transport/fallback snippets on ambiguity, missing fields, transport/help drift, authority uncertainty, SHA/CI mismatch, cross-project binding, partial review, or any mutation action.

### Standalone `/start-build` mode

Standalone builders follow [reference/implementation-flow.md](reference/implementation-flow.md) through ready-marking, then own the [standalone review gate](reference/standalone-gate.md): start a fresh reviewer, drive revision rounds, post the Review Gate Summary, and never self-approve, self-merge, or take fallback finish actions.

### Child `mr-builder` mode

Child builders follow the smaller [reference/child-builder.md](reference/child-builder.md) path: implement one issue, open/update the Draft MR, keep Reviewer Lift current, and either run/own the local gate before ready or, in parent-owned gate mode, record the ownership contract from [reference/parent-owned-gate.md](reference/parent-owned-gate.md#ownership-contract) and leave the MR Draft for the parent Gate Receipt and ready transition. Behavior-touching implementation follows TDD unless impossible or explicitly N/A with rationale in the MR.

## Parent-orchestrator recipe

Parent orchestration detail lives in [reference/parent-orchestrator.md](reference/parent-orchestrator.md): resolve issues, prove decoupling, launch isolated child builders with one target issue/worktree plus exact role/mode, stop condition, expected handoff schema, forbidden actions, and minimum evidence pointers only, spot-check MR handoffs (including shared `delivery.handoff_contract` routing fields), start fresh reviewers with the same minimal-prompt discipline, then enforce SHA/CI/authority guards; the reviewer posts a durable GitLab Review Report and returns `reviewer-final-handoff.md` as a parseable parent-orchestrator parsing aid.
The minimal reviewer launch prompt keeps only the MR URL, Reviewer Lift pointer, Project rulebook path, and a do-not-treat parent/builder reasoning as evidence instruction; the full prompt shape remains in [reference/parent-orchestrator.md](reference/parent-orchestrator.md#minimal-reviewer-launch-prompt).

### Durable child outputs

Durable-output detail lives in [reference/parent-orchestrator.md §Durable child outputs](reference/parent-orchestrator.md#durable-child-outputs): parent-readable handoffs must survive temporary worktree cleanup, so prefer inline handoffs or absolute files under a caller-created run directory, while GitLab MR descriptions/comments remain canonical.

### Parent loop

The parent loop lives in [reference/parent-orchestrator.md §Parent loop](reference/parent-orchestrator.md#parent-loop): process issues serially unless decoupled, create isolated branches/worktrees only after an immediate `git fetch origin` plus default-branch SHA verification, run one builder per issue, spot-check Reviewer Lift and local-gate evidence, start one fresh reviewer per MR/SHA, handle approve/request-changes/reject/timeout/stale/interrupted outcomes with status/activity checks before replacement, and finish only according to explicit merge authority and cleanup safety.

### Post-merge verifier recipe

Post-merge verifier detail lives in [reference/post-merge-verifier.md](reference/post-merge-verifier.md): use that recipe only after independent review plus authority-aware finish reports merge or protected auto-merge completion, prefer `gitlab-local/scripts/gitlab-post-merge-snapshot.sh` for repeatable read-only snapshot behavior, and never use verification to approve, reject, merge, queue auto-merge, delete remote branches, force-close issues, or run mutating release/deploy/operator validation without human authorization.

## Check gate discovery

Check-gate discovery detail lives in [reference/context-and-planning.md §Check gate discovery](reference/context-and-planning.md#check-gate-discovery): discover the full local gate from project rulebook/contributor docs, then build scripts, then CI configuration, and state any limitation in the MR before requesting review.

## Handoff integrity checklist

Handoff checks live in [reference/context-and-planning.md §Handoff integrity checklist](reference/context-and-planning.md#handoff-integrity-checklist): Reviewer Lift rows must match [templates/reviewer-lift-schema.md](templates/reviewer-lift-schema.md), shared `delivery.kind=gitlab-delivery` blocks must follow [templates/gitlab-delivery-schema.md](templates/gitlab-delivery-schema.md) when present, `delivery.handoff_contract` must carry the required routing fields and only use `blocking_question` for specific actionable blockers, compact delivery fields remain untrusted claims/indexes until verified from Tier 1/Tier 2 evidence, `Reviewed SHA` must equal MR head at ready, Gate owner/coverage/rationale must be recorded, CI evidence must be SHA-bound before counting green, and local gate evidence must be `PASS`/`N/A` or parent-owned per [reference/parent-owned-gate.md](reference/parent-owned-gate.md).

Project-profile hooks in `templates/gitlab-delivery-schema.md` may specialize
project gate policy, labels, branch naming, CI jobs, domain docs,
release/deploy policy, manual validation, language families, and auxiliary
indexes. They must not weaken reviewed-SHA binding, exact-SHA CI, explicit
authority source, independent review, the child-builder boundary, the verifier
read-only boundary, or MCP-first transport correctness plus help-first `glab`
fallback correctness.

## Implementation flow

Implementation detail lives in [reference/implementation-flow.md](reference/implementation-flow.md): start clean from latest default branch, branch by issue ID, open an early Draft MR with `gitlab-local` **Snippet: draft-mr-create**, apply targeted tests/TDD or `TDD: N/A`, update the MR description with **Snippet: mr-description-update**, classify exact-SHA Gate coverage, and mark ready with **Snippet: draft-mr-mark-ready** only after the builder-owned ready coverage rule passes and Reviewer Lift names the current head SHA. Parent-owned gate mode leaves the MR Draft for the parent Gate Receipt / ready transition. Behavior-touching implementation follows TDD unless impossible or explicitly N/A with rationale in the MR.

## Compact packet eligibility

Compact-packet detail lives in [reference/context-and-planning.md §Compact packet eligibility](reference/context-and-planning.md#compact-packet-eligibility): use [templates/review-packet-compact.md](templates/review-packet-compact.md) for simple docs-only, tests-only with no runtime impact, typo/lint, or no-API dependency bumps, and default to the full packet when the reviewer needs a broader map.

## Stuck protocol

Stuck handling lives in [reference/stuck-protocol.md](reference/stuck-protocol.md): if blocked for more than 2 hours, keep the MR in Draft, post [templates/stuck-packet.md](templates/stuck-packet.md) through `gitlab-local` **Snippet: mr-note-create**, apply only documented unblock labels, list ranked hypotheses, and park the branch/worktree or switch only on a fresh branch/worktree.

## Mandatory review gate

Standalone gate detail lives in [reference/standalone-gate.md](reference/standalone-gate.md): standalone builders must start a fresh reviewer after ready and drive up to three rounds, while child `mr-builder` agents must not start reviewers because the parent owns the mandatory review gate; no builder self-approval, self-merge, or fallback finish action is allowed.

### Reviewer launch protocol

Reviewer launch detail lives in [reference/standalone-gate.md §Reviewer launch protocol](reference/standalone-gate.md#reviewer-launch-protocol): when the active role owns the gate, discover a reviewer through that runtime's mechanism and launch `start-review` with only MR URL, Reviewer Lift pointer, Project rulebook path, and the Context Firewall instruction that parent/builder reasoning is not evidence.

### Review loop

Review-loop detail lives in [reference/standalone-gate.md §Review loop](reference/standalone-gate.md#review-loop): approve proceeds to SHA/CI/authority-guarded finish, request-changes requires fix commits plus revision packet plus a fresh reviewer session, reject stops and escalates, and three request-changes rounds exhaust the gate.

### Timeout handling

Timeout detail lives in [reference/timeout-handling.md](reference/timeout-handling.md) and [reference/standalone-gate.md §Timeout handling](reference/standalone-gate.md#timeout-handling): missing Review Report after the wait budget is a stale-run signal, not review completion. Check observed reviewer status/activity and use the runtime's status/control/interruption mechanism when available; if status/control is unavailable or ambiguous, escalate instead of launching a duplicate reviewer. Allow a second reviewer attempt only after the first attempt is failed, stale, interrupted, or unreachable with the reason documented.

### Review Gate Summary

Review Gate Summary detail lives in [reference/standalone-gate.md §Review Gate Summary](reference/standalone-gate.md#review-gate-summary): after all rounds complete or escalate, post a concise MR comment listing each round, reviewer, decision, headline, and final Review Report link when available; timeout/stale/interrupted entries are non-completion states and do not imply review completion.

### Human bypass protocol

Human bypass detail lives in [reference/standalone-gate.md §Human bypass protocol](reference/standalone-gate.md#human-bypass-protocol), which owns the strict, non-inferable bypass rule: a closed set of exact human phrases (`skip gate` / `merge unreviewed`) plus named actor, recorded reason, `Review gate` field, and MR audit trail. Ambiguous release language does not bypass and must be clarified, and a bypass never authorizes builder self-approval or self-merge.

## Template filling guides

Template guidance lives in [reference/context-and-planning.md §Template filling guides](reference/context-and-planning.md#template-filling-guides) and [templates/filling-guide.md](templates/filling-guide.md): keep Reviewer Lift current, keep CI SHA-bound, redact secrets, use stable `OQ-N` IDs, and preserve `MF-N`/`SF-N`/`C-N` IDs in revision responses and commits.

## Success metric

The success metric lives in [reference/context-and-planning.md §Success metric](reference/context-and-planning.md#success-metric): reviewable changes that preserve the project rulebook, remain testable, and do not create hidden operational surprises.
