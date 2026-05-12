---
name: start-review
description: Reviews one or more GitLab Merge Requests against project rules, issue scope, diff, CI, TDD-style behavior-test evidence, safety invariants, credentials, locks, gates, and migrations. It can pick up multiple decoupled MRs using isolated git worktrees, then posts structured Review Reports, approves/request-changes/rejects, and merges or auto-merges approved MRs when merge authority allows. Use when the user asks to start a review, pick up/review MR(s), review this branch, review the next MR(s), or evaluate Review Packets.
---

# Start Review

## Purpose

Review GitLab Merge Requests against project rules and safety invariants. Single-MR is the default. Multiple MRs are allowed only when clearly decoupled; each gets its own review context, worktree (when local checkout/tests are needed), Review Report, decision, and reviewed SHA. Protect safety boundaries: no unintended product/runtime/operator external effects, no weakened gates, no credential exposure, no untested behavior changes, no scope creep.

This skill is language- and domain-agnostic; domain-specific safety terms below are examples to map onto the host project's equivalent surfaces. **Load the host project's rulebook first** (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, architecture docs, ADRs). Project rules override this skill where stricter. Reviews live in **GitLab**: read description and diff, leave inline comments where useful, post one structured Review Report comment per MR, and use GitLab's approve/request-changes/merge controls.

For behavior-touching MRs, evaluate test evidence using `tdd` principles. A red-green trace strengthens evidence; missing red-first proof is an evidence request unless project rules require strict TDD or the final behavior tests themselves are weak.

## Quick start

1. Run `gl-preflight` to verify `glab` is installed/authenticated and the cwd is the intended GitLab repo.
2. Read [REVIEW-CHECKLIST.md](REVIEW-CHECKLIST.md) before reviewing any diff.
3. Read [REVIEW-FLOW.md](REVIEW-FLOW.md) before selecting MR(s), commenting, approving, merging, requesting changes, or rejecting.
4. Resolve the MR(s): supplied IDs/URLs/branches, current-branch MR, or pick from open non-draft MRs in the current project (or a decoupled set).
5. For multiple MRs, keep only a clearly decoupled set; use one isolated worktree per MR when local checkout/tests are needed.
6. Read linked issue + MR description before the diff. Lift the builder's `Reviewer Lift` values (Reviewed SHA, CI pipeline, Local gate, RED/GREEN, Changed paths, Touched safety surfaces, Decoupling proof, Reviewer Focus, Open Questions, Merge authority, Delta since last ready push) into the corresponding Review Report fields rather than re-deriving them.
7. Confirm branch/commits match the lifted `Reviewed SHA`. Skim `Reviewer Focus` first to seed your read, then walk the diff with the description as a map; evaluate behavior tests via `tdd` principles; run targeted code only when needed.
8. Answer each `OQ-N` from the MR description in your report — answer, escalate, or downgrade to evidence request. Unanswered OQs are not allowed.
9. **SHA discipline.** Re-read MR metadata immediately before approving. If the head `sha` differs from the SHA you reviewed, re-diff the new commits before approving — never approve a SHA you haven't read. Same GitLab username/PAT as the builder is not a blocker; review independence comes from session/context separation.
10. Post one Review Report per MR via `templates/review-report.md` and decide approve / request-changes / reject independently. If approving, run `glab mr approve <id> --sha <reviewed-sha>`. Merge or queue auto-merge for that reviewed SHA only when the MR's `Merge authority` and project rules allow it.

## Essential tooling

Use the host project's issue-tracker guide as the single source of truth for `glab`, `gl-*` wrappers, command snippets, and flag pitfalls (in this repo, `docs/agents/issue-tracker.md`, loaded through the project rulebook). Keep this skill focused on workflow, review evidence, and decision policy.

Minimum invariants still apply everywhere: `glab` must be installed/authenticated, `gl-preflight` must pass before GitLab operations, wrappers should be preferred for composite/file-based MR actions, and secrets must never be pasted into report comments, screenshots, or `Code I Ran` output. If a project has no issue-tracker guide, verify syntax with `glab <subcommand> --help` and stop on auth/repo ambiguity.

## MR pickup summary

When the user supplies MR IDs/URLs/branches, review them if suitable. Otherwise pick from the **current GitLab project**:

- Prefer the current-branch MR when the user says "this branch".
- Prefer open non-draft MRs labeled ready-for-review, assigned/requested to `@me`, targeting main/default, with linked issues and passing or pending CI.
- For multiple, select only a clearly decoupled set: no stacked branches, no dependency/order relation, no expected file/schema/lock/deploy/lockfile overlap, independently testable.
- Deprioritize drafts, blocked MRs, needs-revision/needs-unblock/WIP MRs, and red-CI MRs unless failure triage was requested.
- Inspect candidates and summarize ID, title, author, labels, CI state, linked issue, suitability, coupling risk.
- If one MR/set is clearly best, announce and proceed. If several are plausible or coupled, ask the user to choose.

See [REVIEW-FLOW.md](REVIEW-FLOW.md) for the full pickup and review workflow.

## Essential review summary

- Read linked issue + MR description before the diff.
- Block on scope creep, live product/runtime/operator external mutation evidence, credential leakage, weakened gates, broken sequencing/locks, missing/weak behavior tests, red/stale CI, or omitted CI/local gate evidence without explanation.
- Apply `tdd` principles to test quality (see intro for the missing-red-first rule).
- Treat style as non-blocking unless it creates concrete hazard or waste.
- Multiple MR review requires separate Review Reports, decisions, and reviewed SHAs; never batch approvals into one report.
- Approval is allowed when no Must Fix remains, all `OQ-N` are answered/escalated, the head SHA equals the reviewed SHA, and CI/checks are green, explicitly waived, or pending under the CI-pending auto-merge policy (builder local gate PASS, pipeline belongs to the reviewed SHA when exposed, and GitLab merge checks enforce green CI before merge).
- If approving, approve with `--sha <reviewed-sha>`. Merge immediately or queue auto-merge only when `Merge authority` allows it; otherwise stop after approval and report that merge is approval-only/human-release. Report the exact GitLab blocker if approval or merge fails.

See [REVIEW-CHECKLIST.md](REVIEW-CHECKLIST.md) for must-fix checks, review depth, categories, tests, and common failure modes.

## Templates

- `templates/review-report.md` — single top-level MR comment.
- `templates/unblock-response.md` — response to a Stuck Packet.
- `templates/adr.md` — architectural recommendation requiring its own MR.

## Decisions

- **Approve** — no Must Fix remains, evidence adequate, CI green/waived or safely pending under protected auto-merge policy, deployable. Approve with `glab mr approve <id> --sha <reviewed-sha>`; merge or queue auto-merge only when `Merge authority` allows it.
- **Request changes** — fixable Must Fix items; apply `needs-revision` and keep MR open.
- **Reject** — premise/architecture/scope is wrong or a safety boundary is weakened beyond what the user/project accepts.
